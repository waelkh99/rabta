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
    required this.customerAvatarUrl,
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

  /// Meta's own URL, which expires after about 30 days. Stored rather than
  /// copied: the interface draws a monogram when it is missing or broken, so a
  /// dead link costs nothing.
  final String? customerAvatarUrl;

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
        customerAvatarUrl: customerAvatarUrl,
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
        customerAvatarUrl: row['customer_avatar_url'] as String?,
        preview: row['last_message_preview'] as String?,
        lastMessageType: row['last_message_type'] as String?,
        lastMessageAt: _time(row['last_message_at']),
        lastInboundAt: _time(row['last_inbound_at']),
        windowExpiresAt: _time(row['window_expires_at']),
        unreadCount: (row['unread_count'] as int?) ?? 0,
      );
}

/// One connected Meta account: a Facebook Page, or an Instagram account
/// reached through one.
class Account {
  Account({
    required this.id,
    required this.platform,
    required this.name,
    required this.status,
  });

  final String id;
  final String platform;
  final String? name;

  /// `active`, `needs_reconnect` when the token expired and messages have
  /// silently stopped, or `disconnected` when the seller turned it off.
  final String status;

  bool get receiving => status == 'active';

  factory Account.fromRow(Map<String, dynamic> row) => Account(
        id: row['id'] as String,
        platform: row['platform'] as String,
        name: row['name'] as String?,
        status: (row['status'] as String?) ?? 'active',
      );
}

/// A connection step that did not work, as the code the function returned.
class ConnectFailed implements Exception {
  const ConnectFailed(this.reason);

  final String reason;

  @override
  String toString() => 'ConnectFailed($reason)';
}

/// An invitation that was not created, and why.
class InviteFailed implements Exception {
  const InviteFailed(this.reason);

  final String reason;

  @override
  String toString() => 'InviteFailed($reason)';
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
    required this.mid,
    required this.text,
    required this.attachments,
    required this.inbound,
    required this.sentAt,
  });

  final String id;

  /// Meta's own id for the message. The one identity our database, Meta's
  /// echo and a reply we just sent all agree on, so it is what decides whether
  /// two copies are the same message.
  final String mid;

  final String? text;
  final List<dynamic> attachments;
  final bool inbound;
  final DateTime sentAt;

  factory Message.fromRow(Map<String, dynamic> row) => Message(
        id: row['id'] as String,
        mid: row['mid'] as String,
        text: row['text'] as String?,
        attachments: (row['attachments'] as List<dynamic>?) ?? const [],
        inbound: row['direction'] == 'inbound',
        sentAt: DateTime.parse(row['sent_at'] as String).toUtc(),
      );
}

/// The thread as it should be shown: what the database holds, plus anything
/// sent from here that has not come back yet.
///
/// A reply is shown the moment Meta accepts it, and the same reply arrives
/// again moments later as Meta's echo through the webhook. Both are the same
/// message and `mid` is what says so — the id our database, Meta's echo and the
/// send both agree on. The stored row wins, because it is the real one.
///
/// Sorted by time rather than appended, because a message Meta delivered late
/// belongs where it was sent, not at the end.
///
/// Pure, so the rule that stops a reply appearing twice can be tested without
/// a database or a widget tree.
List<Message> mergeMessages(List<Message> stored, List<Message> pending) {
  final known = {for (final m in stored) m.mid};

  return [
    ...stored,
    ...pending.where((m) => !known.contains(m.mid)),
  ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
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
          'id, customer_name, customer_avatar_url, last_message_preview, '
          'last_message_type, last_message_at, last_inbound_at, '
          'window_expires_at, unread_count, connected_accounts!inner(platform)',
        )
        .order('last_message_at', ascending: false);

    return inboxOrder(rows.map(Conversation.fromRow).toList());
  }

  /// Creates an account for someone, and gives back the link that lets them
  /// set their own password.
  ///
  /// Whether the caller may do this is decided on the server, from their user
  /// record rather than from their token. Nothing here is a permission check —
  /// the client only decides whether to draw the button.
  Future<String> invite(String email) async {
    try {
      final response = await _db.functions.invoke(
        'admin-invite',
        body: {'email': email.trim()},
      );

      final link = (response.data as Map?)?['link'] as String?;
      if (link == null) throw const InviteFailed('failed');

      return link;
    } on FunctionException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;

      throw InviteFailed(reason is String ? reason : 'unreachable');
    } on InviteFailed {
      rethrow;
    } catch (_) {
      throw const InviteFailed('unreachable');
    }
  }

  /// The seller's connected accounts, including ones no longer receiving.
  ///
  /// A disconnected account is still shown, because its conversations are
  /// still here and being able to reconnect it is the point.
  Future<List<Account>> accounts() async {
    final rows = await _db
        .from('connected_accounts')
        .select('id, platform, name, status')
        .order('connected_at', ascending: true);

    return rows.map(Account.fromRow).toList();
  }

  /// Where to send the browser to approve a connection.
  ///
  /// The workspace is not passed. It comes from the seller's own token on the
  /// far side, because a workspace named in the request would let anyone start
  /// a connection into an inbox they do not own.
  Future<String> connectUrl() async {
    try {
      final response = await _db.functions.invoke(
        'meta-oauth/start',
        method: HttpMethod.get,
        queryParameters: {'return': Uri.base.origin},
      );

      final url = (response.data as Map?)?['url'] as String?;
      if (url == null) throw const ConnectFailed('failed');

      return url;
    } on FunctionException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;

      throw ConnectFailed(reason is String ? reason : 'unreachable');
    } on ConnectFailed {
      rethrow;
    } catch (_) {
      throw const ConnectFailed('unreachable');
    }
  }

  /// Stops an account receiving, without losing its conversations.
  Future<void> disconnect(String accountId) async {
    try {
      await _db.functions.invoke(
        'meta-oauth/disconnect',
        body: {'account': accountId},
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;

      throw ConnectFailed(reason is String ? reason : 'unreachable');
    } catch (_) {
      throw const ConnectFailed('unreachable');
    }
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
        mid: mid,
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
        .select('id, mid, text, attachments, direction, sent_at')
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true);

    return rows.map(Message.fromRow).toList();
  }
}
