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
    this.aiState,
    this.aiEscalationReason,
    this.aiEscalationCode,
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

  /// What the assistant last did here: `answered`, `escalated`, or null when it
  /// has not touched this conversation — or when the seller has since replied,
  /// which is what clears all three of these.
  final String? aiState;

  /// Why it stepped back, in words. Written by the assistant itself when
  /// [aiEscalationCode] is `assistant`, and shown to the seller as written.
  /// Null on every other kind of escalation, where the interface supplies the
  /// wording in the seller's own language instead.
  final String? aiEscalationReason;

  /// Which kind of escalation it was. A short token, not a sentence — see the
  /// column comment in `20260921000001_ai_visible.sql`. An unfamiliar value is
  /// read as a general hand-over rather than as an error.
  final String? aiEscalationCode;

  bool get answeredByAssistant => aiState == 'answered';

  /// The assistant looked at this and could not finish it, so a customer is
  /// still waiting on a person.
  bool get escalated => aiState == 'escalated';

  /// A conversation is waiting on the seller exactly when the newest message in
  /// it is the customer's — that is, when `last_message_at` has not moved past
  /// `last_inbound_at`. Both columns are maintained by the database trigger, so
  /// this needs no extra state and cannot drift.
  ///
  /// The comparison is `isAfter`, not `isBefore`. A seller's reply advances
  /// `last_message_at` beyond `last_inbound_at`, and getting this backwards
  /// leaves every answered conversation sitting in the waiting group.
  /// An escalation counts as waiting whatever the messages say. This is not a
  /// refinement — it is the whole point. When the assistant hands a
  /// conversation back it usually tells the customer so, and that line is an
  /// outbound message, which moves `last_message_at` past `last_inbound_at`
  /// and files the conversation under "Answered". A customer the assistant
  /// explicitly could not help would then sit in the group the seller has
  /// stopped reading.
  bool get awaitingReply =>
      lastInboundAt != null &&
      (escalated ||
          (lastMessageAt != null && !lastMessageAt!.isAfter(lastInboundAt!)));

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
        // The seller replying is what takes the assistant's mark off, and the
        // database trigger does exactly this on the row. Repeated here so the
        // conversation leaves the waiting group the instant the reply is
        // accepted, rather than on the next reload.
        aiState: null,
        aiEscalationReason: null,
        aiEscalationCode: null,
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
        aiState: row['ai_state'] as String?,
        aiEscalationReason: row['ai_escalation_reason'] as String?,
        aiEscalationCode: row['ai_escalation_code'] as String?,
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

/// One thing the seller sells.
///
/// Deliberately small. This exists so the assistant can answer "how much is
/// it" and "do you have it", not so the seller can run their stock from here —
/// no variants, no SKUs, no quantities, no pictures.
class Product {
  const Product({
    this.id,
    required this.name,
    this.price,
    this.description,
    this.inStock = true,
  });

  /// Null for a product that has been typed in but not saved yet.
  final String? id;
  final String name;
  final double? price;
  final String? description;
  final bool inStock;

  Product copyWith({
    String? name,
    double? price,
    String? description,
    bool? inStock,
    bool clearPrice = false,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        price: clearPrice ? null : (price ?? this.price),
        description: description ?? this.description,
        inStock: inStock ?? this.inStock,
      );

  factory Product.fromRow(Map<String, dynamic> row) => Product(
        id: row['id'] as String?,
        name: (row['name'] as String?) ?? '',
        // numeric comes back as a string often enough that parsing both is
        // cheaper than finding out in production.
        price: switch (row['price']) {
          final num value => value.toDouble(),
          final String value => double.tryParse(value),
          _ => null,
        },
        description: row['description'] as String?,
        inStock: row['in_stock'] as bool? ?? true,
      );
}

/// The shop itself: everything a customer asks about that is not a product.
///
/// A catalog answers "how much is the red dress". Half of what a customer
/// actually asks is delivery, hours and where you are, and without these the
/// assistant hands most of a normal conversation back to the seller.
class Shop {
  const Shop({
    this.currency = 'د.ا',
    this.deliveryNote,
    this.locations,
    this.hours,
    this.about,
    this.assistantEnabled = false,
  });

  /// Written as the seller writes it and repeated back the same way. Not a
  /// code: nobody says "JOD" to a customer.
  final String currency;

  /// The delivery rules a list of zones cannot hold — free over a certain
  /// amount, same day inside the city.
  final String? deliveryNote;

  /// Where the shop is. Multi-line, because a shop with two branches has two.
  final String? locations;

  final String? hours;

  /// Whatever else the seller thinks the assistant should know. Also the
  /// escape hatch when it keeps getting something wrong.
  final String? about;

  final bool assistantEnabled;

  Shop copyWith({
    String? currency,
    String? deliveryNote,
    String? locations,
    String? hours,
    String? about,
    bool? assistantEnabled,
  }) =>
      Shop(
        currency: currency ?? this.currency,
        deliveryNote: deliveryNote ?? this.deliveryNote,
        locations: locations ?? this.locations,
        hours: hours ?? this.hours,
        about: about ?? this.about,
        assistantEnabled: assistantEnabled ?? this.assistantEnabled,
      );

  factory Shop.fromRow(Map<String, dynamic> row) => Shop(
        currency: (row['currency'] as String?)?.trim().isNotEmpty == true
            ? (row['currency'] as String).trim()
            : 'د.ا',
        deliveryNote: row['delivery_note'] as String?,
        locations: row['locations'] as String?,
        hours: row['hours'] as String?,
        about: row['about'] as String?,
        assistantEnabled: row['assistant_enabled'] as bool? ?? false,
      );
}

/// Somewhere the shop delivers to, and what it charges.
///
/// A zone with no fee is meaningful: the shop covers that place but the price
/// depends. Better than implying it is free.
class DeliveryZone {
  const DeliveryZone({this.id, required this.name, this.fee});

  final String? id;
  final String name;
  final double? fee;

  factory DeliveryZone.fromRow(Map<String, dynamic> row) => DeliveryZone(
        id: row['id'] as String?,
        name: (row['name'] as String?) ?? '',
        fee: switch (row['fee']) {
          final num value => value.toDouble(),
          final String value => double.tryParse(value),
          _ => null,
        },
      );
}

/// The byte order mark Excel needs at the front of a UTF-8 file.
///
/// Without it Excel reads the file in the system codepage and every Arabic
/// product name arrives as mojibake, which reads to a seller as the
/// application being broken rather than Excel guessing wrong.
const catalogBom = '﻿';

/// The column order the template hands out, and the order it is read back in
/// when a file has no usable header.
const catalogColumns = ['name', 'price', 'description', 'in_stock'];

/// A spreadsheet the seller can fill in, with one example row to show the
/// shape. Arabic, because that is the language this product is for.
String catalogTemplateCsv() => '$catalogBom${catalogColumns.join(',')}\n'
    'فستان أحمر,25.500,قطن، مقاسات S M L,yes\n';

/// Products read out of a spreadsheet the seller filled in.
///
/// Forgiving on purpose: a seller exporting from Excel or Google Sheets has no
/// idea what a delimiter is, and a file that imports nothing with no
/// explanation is worse than one that imports what it understood. Rows with no
/// name are skipped, because a price with nothing attached to it is not a
/// product.
List<Product> parseCatalogCsv(String content) {
  final cleaned = content.replaceFirst(catalogBom, '');
  final rows = _csvRows(cleaned, _delimiterOf(cleaned));
  if (rows.isEmpty) return const [];

  // A header if it names any column we know; otherwise the file starts with
  // data and we fall back to the template's own order.
  final first = rows.first.map((cell) => cell.trim().toLowerCase()).toList();
  final hasHeader = first.any(catalogColumns.contains);
  final header = hasHeader ? first : catalogColumns;
  final body = hasHeader ? rows.skip(1) : rows;

  final products = <Product>[];

  for (final row in body) {
    String? cell(String column) {
      final index = header.indexOf(column);
      if (index < 0 || index >= row.length) return null;

      final value = row[index].trim();
      return value.isEmpty ? null : value;
    }

    final name = cell('name');
    if (name == null) continue;

    products.add(Product(
      name: name,
      price: _price(cell('price')),
      description: cell('description'),
      inStock: _inStock(cell('in_stock')),
    ));
  }

  return products;
}

/// A price as the seller reads it back: grouped, in Western numerals, and in
/// their own currency.
///
/// Three decimal places when there are any, because the Jordanian dinar
/// divides into 1000 fils and 12.750 is an ordinary price. Rounding it to
/// 12.75 would be the application quietly changing a number the seller typed.
String formatPrice(double price, [String currency = '']) {
  final whole = price == price.roundToDouble()
      ? price.round().toString()
      : price.toStringAsFixed(3);

  final parts = whole.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }

  final number = parts.length > 1 ? '$grouped.${parts[1]}' : grouped.toString();
  return currency.trim().isEmpty ? number : '$number ${currency.trim()}';
}

/// A price as a seller would type it: with a thousands separator, a currency
/// word beside it, or Arabic-Indic digits.
double? parsePrice(String? raw) => _price(raw);

double? _price(String? raw) {
  if (raw == null) return null;

  final western = raw.replaceAllMapped(
    RegExp(r'[٠-٩۰-۹]'),
    (match) {
      final code = match.group(0)!.codeUnitAt(0);
      final base = code >= 0x06F0 ? 0x06F0 : 0x0660;
      return '${code - base}';
    },
  );

  // The first number in the cell, rather than everything that is not a digit
  // stripped away. "د.ا" — the dinar — contains a dot, so stripping around it
  // left "30.750." and parsed as nothing at all.
  //
  // Commas go first: they are a thousands separator here, while the dot is a
  // decimal point. 1,250 is one thousand two hundred and fifty; 1.250 is one
  // and a quarter dinars.
  final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(western.replaceAll(',', ''));
  return match == null ? null : double.tryParse(match.group(0)!);
}

/// Anything that plainly means no. Everything else, including an empty cell,
/// means the seller has it — a product they bothered to list is for sale until
/// they say otherwise.
bool _inStock(String? raw) {
  if (raw == null) return true;

  const no = ['no', 'false', '0', 'out', 'out of stock', 'لا', 'نفد', 'غير متوفر'];
  return !no.contains(raw.trim().toLowerCase());
}

/// Whether this is a spreadsheet's own clipboard format or a saved file.
///
/// Copying cells out of Excel or Google Sheets puts tab-separated text on the
/// clipboard, not commas. Sellers paste straight from their sheet, so reading
/// only commas would turn every pasted row into one long product name.
///
/// Decided from the first line, which is where the columns are.
String _delimiterOf(String content) {
  final firstLine = content.split('\n').first;
  return firstLine.contains('\t') ? '\t' : ',';
}

/// A reader that survives quoted fields.
///
/// Sellers write commas inside descriptions constantly — "قطن، مقاسات S M L" —
/// so splitting on every comma would quietly shift half the columns along by
/// one and put a size into the price.
List<List<String>> _csvRows(String content, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;

  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < content.length; i++) {
    final char = content[i];

    if (quoted) {
      if (char != '"') {
        cell.write(char);
      } else if (i + 1 < content.length && content[i + 1] == '"') {
        // A doubled quote inside a quoted field is one literal quote.
        cell.write('"');
        i++;
      } else {
        quoted = false;
      }
      continue;
    }

    if (char == delimiter) {
      endCell();
      continue;
    }

    switch (char) {
      case '"':
        quoted = true;
      case '\n':
        endRow();
      case '\r':
        break;
      default:
        cell.write(char);
    }
  }

  if (cell.isNotEmpty || row.isNotEmpty) endRow();

  return rows;
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
    this.byAssistant = false,
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

  /// Written by the assistant rather than by the seller.
  ///
  /// Only ever true on an outbound message. The column carries a value on
  /// inbound rows too, where it means nothing.
  final bool byAssistant;

  factory Message.fromRow(Map<String, dynamic> row) => Message(
        id: row['id'] as String,
        mid: row['mid'] as String,
        text: row['text'] as String?,
        attachments: (row['attachments'] as List<dynamic>?) ?? const [],
        inbound: row['direction'] == 'inbound',
        sentAt: DateTime.parse(row['sent_at'] as String).toUtc(),
        byAssistant:
            row['direction'] != 'inbound' && row['origin'] == 'ai',
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
          'window_expires_at, unread_count, ai_state, ai_escalation_reason, '
          'ai_escalation_code, connected_accounts!inner(platform)',
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

  /// The seller's catalog, in the order the assistant reads it.
  ///
  /// Sorted the same way on the server, so the text the model sees is
  /// byte-identical between calls and its cached copy keeps being reused.
  Future<List<Product>> products() async {
    final rows = await _db
        .from('products')
        .select('id, name, price, description, in_stock')
        .order('name', ascending: true);

    return rows.map(Product.fromRow).toList();
  }

  /// Adds a product, or updates the one already saved.
  ///
  /// No workspace is named. Row level security fills it in from the seller's
  /// own token, the same as every other write in this file.
  Future<void> saveProduct(Product product) async {
    final values = {
      'name': product.name.trim(),
      'price': product.price,
      'description': product.description?.trim(),
      'in_stock': product.inStock,
    };

    if (product.id == null) {
      final workspace = await _workspaceId();
      await _db.from('products').insert({...values, 'workspace_id': workspace});
    } else {
      await _db.from('products').update(values).eq('id', product.id!);
    }
  }

  Future<void> deleteProduct(String id) async {
    await _db.from('products').delete().eq('id', id);
  }

  /// Saves a whole spreadsheet at once.
  ///
  /// Adds to the catalog rather than replacing it. Replacing would be one
  /// mis-click away from deleting everything the seller has, and re-importing
  /// a corrected file is a smaller annoyance than that.
  Future<int> importProducts(List<Product> products) async {
    if (products.isEmpty) return 0;

    final workspace = await _workspaceId();

    await _db.from('products').insert([
      for (final product in products)
        {
          'workspace_id': workspace,
          'name': product.name.trim(),
          'price': product.price,
          'description': product.description?.trim(),
          'in_stock': product.inStock,
        },
    ]);

    return products.length;
  }

  /// The shop's own facts, and whether the assistant answers.
  ///
  /// No row means it has never been set up, which is the state every workspace
  /// starts in and the way round we want it to fail — the defaults have the
  /// assistant switched off.
  Future<Shop> shop() async {
    final row = await _db
        .from('shop')
        .select(
          'currency, delivery_note, locations, hours, about, '
          'assistant_enabled',
        )
        .maybeSingle();

    return row == null ? const Shop() : Shop.fromRow(row);
  }

  /// Changes one or more fields of the shop, leaving the rest alone.
  ///
  /// Only what changed is sent. Writing the whole row back from whatever the
  /// screen last loaded meant two quick edits raced: the second carried a
  /// stale copy of the first and quietly undid it. It also makes clearing a
  /// field possible, which a copy-and-replace cannot express — an absent value
  /// and a value set to nothing look the same from the outside.
  Future<void> updateShop(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;

    final workspace = await _workspaceId();

    await _db.from('shop').upsert({
      'workspace_id': workspace,
      ...changes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// An empty box means "not set", which is null rather than an empty string.
  static String? textOrNull(String? value) => _orNull(value);

  /// Where the shop delivers, in the order the assistant reads it.
  Future<List<DeliveryZone>> deliveryZones() async {
    final rows = await _db
        .from('delivery_zones')
        .select('id, name, fee')
        .order('name', ascending: true);

    return rows.map(DeliveryZone.fromRow).toList();
  }

  Future<void> saveDeliveryZone(DeliveryZone zone) async {
    final values = {'name': zone.name.trim(), 'fee': zone.fee};

    if (zone.id == null) {
      final workspace = await _workspaceId();
      await _db.from('delivery_zones').insert({...values, 'workspace_id': workspace});
    } else {
      await _db.from('delivery_zones').update(values).eq('id', zone.id!);
    }
  }

  Future<void> deleteDeliveryZone(String id) async {
    await _db.from('delivery_zones').delete().eq('id', id);
  }

  /// An empty box means "not set", not an empty string.
  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The seller's own workspace.
  ///
  /// Needed only for inserts, which have to name the workspace the row belongs
  /// to. Reads never do: row level security already scopes them.
  Future<String> _workspaceId() async {
    final row = await _db.from('workspaces').select('id').limit(1).single();
    return row['id'] as String;
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
        .select('id, mid, text, attachments, direction, sent_at, origin')
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true);

    return rows.map(Message.fromRow).toList();
  }
}
