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

  Future<List<Message>> messages(String conversationId) async {
    final rows = await _db
        .from('messages')
        .select('id, text, attachments, direction, sent_at')
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true);

    return rows.map(Message.fromRow).toList();
  }
}
