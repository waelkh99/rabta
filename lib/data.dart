// Reading the inbox.
//
// Every query here runs as the signed-in seller, so row level security is what
// scopes it to their workspace rather than a filter written by hand. That is
// deliberate: a forgotten `.eq('workspace_id', ...)` would otherwise be a
// silent leak of another seller's customers.

import 'package:supabase_flutter/supabase_flutter.dart';

class Conversation {
  Conversation({
    required this.id,
    required this.platform,
    required this.customerName,
    required this.preview,
    required this.lastMessageType,
    required this.lastMessageAt,
    required this.lastInboundAt,
    required this.windowExpiresAt,
    required this.unreadCount,
  });

  final String id;
  final String platform;
  final String? customerName;
  final String? preview;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final DateTime? lastInboundAt;
  final DateTime? windowExpiresAt;
  final int unreadCount;

  /// A conversation is waiting on the seller exactly when the newest message in
  /// it is the customer's — that is, when `last_message_at` has not moved past
  /// `last_inbound_at`. Both columns are maintained by the database trigger, so
  /// this needs no extra state and cannot drift.
  ///
  /// The comparison is `isAfter`, not `isBefore`. A seller's reply advances
  /// `last_message_at` beyond `last_inbound_at`, and getting this backwards
  /// leaves every answered conversation sitting in the waiting group.
  bool get awaitingReply =>
      lastInboundAt != null &&
      lastMessageAt != null &&
      !lastMessageAt!.isAfter(lastInboundAt!);

  /// This conversation as it stands once the seller's reply has gone.
  ///
  /// The same four changes the database trigger makes: the last message is now
  /// ours, the preview is what we wrote, and nothing is unread. The reply
  /// window is deliberately untouched — it runs from the customer's message and
  /// answering does not extend it, which is the rule Meta actually enforces.
  ///
  /// Done here rather than by reloading the list so that the conversation
  /// leaves the waiting group the instant the reply is accepted, with no
  /// round trip and no spinner across an inbox the seller is reading.
  Conversation afterReply(Message reply) => Conversation(
        id: id,
        platform: platform,
        customerName: customerName,
        preview: reply.text,
        lastMessageType: 'text',
        lastMessageAt: reply.sentAt,
        lastInboundAt: lastInboundAt,
        windowExpiresAt: windowExpiresAt,
        unreadCount: 0,
      );

  static DateTime? _time(dynamic value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  factory Conversation.fromRow(Map<String, dynamic> row) => Conversation(
        id: row['id'] as String,
        platform: (row['connected_accounts']?['platform'] as String?) ?? 'messenger',
        customerName: row['customer_name'] as String?,
        preview: row['last_message_preview'] as String?,
        lastMessageType: row['last_message_type'] as String?,
        lastMessageAt: _time(row['last_message_at']),
        lastInboundAt: _time(row['last_inbound_at']),
        windowExpiresAt: _time(row['window_expires_at']),
        unreadCount: (row['unread_count'] as int?) ?? 0,
      );
}

/// A reply that was not sent, and why — as the code the function returned.
///
/// The reason stays a code all the way to the widget that shows it, so the
/// sentence the seller reads comes out of the localisation files like every
/// other sentence in the product.
class SendRefused implements Exception {
  const SendRefused(this.reason);

  final String reason;

  @override
  String toString() => 'SendRefused($reason)';
}

class Message {
  Message({
    required this.id,
    required this.text,
    required this.attachments,
    required this.inbound,
    required this.sentAt,
  });

  final String id;
  final String? text;
  final List<dynamic> attachments;
  final bool inbound;
  final DateTime sentAt;

  factory Message.fromRow(Map<String, dynamic> row) => Message(
        id: row['id'] as String,
        text: row['text'] as String?,
        attachments: (row['attachments'] as List<dynamic>?) ?? const [],
        inbound: row['direction'] == 'inbound',
        sentAt: DateTime.parse(row['sent_at'] as String).toUtc(),
      );
}

/// Two groups, not one order: conversations still awaiting a reply come first
/// with the longest wait at the top, then everything already answered, newest
/// first.
///
/// Sorting newest-first throughout is last-in-first-out, and a LIFO queue
/// starves its oldest item. Against a hard 24 hour reply window, starvation is
/// not slow service — it is a customer who can never be answered again.
///
/// Pure, so the ordering can be tested without a database.
List<Conversation> inboxOrder(List<Conversation> all) {
  final waiting = all.where((c) => c.awaitingReply).toList()
    ..sort((a, b) => a.lastInboundAt!.compareTo(b.lastInboundAt!));

  final answered = all.where((c) => !c.awaitingReply).toList()
    ..sort((a, b) {
      final left = a.lastMessageAt, right = b.lastMessageAt;
      if (left == null || right == null) return 0;
      return right.compareTo(left);
    });

  return [...waiting, ...answered];
}

/// Whether the list should show its two group labels.
///
/// Only when there is something on both sides of the divider. A label with
/// nothing under it reads as a section that failed to load, and when the seller
/// has answered everyone the empty waiting group is the useful thing to see —
/// not a heading apologising for itself.
bool showGroupLabels({required int waiting, required int total}) =>
    waiting > 0 && waiting < total;

class Inbox {
  Inbox(this._db);

  final SupabaseClient _db;

  /// Two groups, not one order: conversations still awaiting a reply come
  /// first with the longest wait at the top, then everything already answered,
  /// newest first. Sorting newest-first throughout is last-in-first-out, and a
  /// LIFO queue starves its oldest item — which, against a hard 24 hour reply
  /// window, means a customer who can never be answered again.
  ///
  /// ponytail: grouped in Dart rather than in SQL. One round trip and no view
  /// to maintain, and the ordering is the same either way. Move it into a
  /// database view once a seller has enough conversations for the transfer to
  /// cost more than the sort.
  Future<List<Conversation>> conversations() async {
    final rows = await _db
        .from('conversations')
        .select(
          'id, customer_name, last_message_preview, last_message_type, '
          'last_message_at, last_inbound_at, window_expires_at, unread_count, '
          'connected_accounts!inner(platform)',
        )
        .order('last_message_at', ascending: false);

    return inboxOrder(rows.map(Conversation.fromRow).toList());
  }

  int waitingCount(List<Conversation> all) =>
      all.where((c) => c.awaitingReply).length;

  /// Sends a reply, and gives back the message to show for it.
  ///
  /// The reply goes through the `send-message` function rather than straight
  /// into the table, because the access token it needs is one no client may
  /// read — and because a message has to reach Meta before it is worth showing
  /// as sent.
  ///
  /// ponytail: the returned message is built here rather than read back. The
  /// row it stands for exists, and reopening the conversation loads the real
  /// one; what is local is the id and a `sentAt` a fraction of a second early.
  /// Read it back if anything ever depends on either.
  Future<Message> send(String conversationId, String text) async {
    try {
      final response = await _db.functions.invoke(
        'send-message',
        body: {'conversation': conversationId, 'text': text},
      );

      final mid = (response.data as Map?)?['mid'] as String?;
      if (mid == null) throw const SendRefused('rejected');

      return Message(
        id: mid,
        text: text,
        attachments: const [],
        inbound: false,
        sentAt: DateTime.now().toUtc(),
      );
    } on FunctionException catch (error) {
      // The function answers with a code and never a sentence, so that the
      // language is chosen here and not on the server.
      //
      // No code means this did not come from our function at all — it was
      // blocked, or the platform answered for it. That is not Meta refusing the
      // reply, and saying so would send the seller off rewriting a message that
      // was never the problem. This is exactly what a missing CORS header
      // looked like the first time this ran in a browser.
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;

      throw SendRefused(reason is String ? reason : 'unreachable');
    } on SendRefused {
      rethrow;
    } catch (_) {
      // No answer at all — offline, or the function unreachable. Reported as
      // such rather than as a refusal by Meta, because the two want different
      // things from the seller.
      throw const SendRefused('unreachable');
    }
  }

  Future<List<Message>> messages(String conversationId) async {
    final rows = await _db
        .from('messages')
        .select('id, text, attachments, direction, sent_at')
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true);

    return rows.map(Message.fromRow).toList();
  }
}
