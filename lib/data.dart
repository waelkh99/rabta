// Reading the inbox.
//
// Every query here runs as the signed-in seller, so row level security is what
// scopes it to their workspace rather than a filter written by hand. That is
// deliberate: a forgotten `.eq('workspace_id', ...)` would otherwise be a
// silent leak of another seller's customers.

import 'dart:math';
import 'dart:typed_data';

import 'package:excel/excel.dart';
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
    this.aiPaused = false,
    this.outcome,
    this.outcomeReason,
    this.outcomeBy,
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

  /// The seller said "I'll handle this one": the assistant stays out of this
  /// conversation until they switch it back, whatever the shop setting is.
  final bool aiPaused;

  /// How the conversation ended: `ordered`, `not_bought`, `just_asking`, or
  /// `undecided` — and null before anyone has said. The database decides
  /// between the seller's correction and the assistant's reading; see
  /// 20260925000001_outcomes.sql.
  final String? outcome;

  /// Why a customer did not buy, as a code the interface names.
  final String? outcomeReason;

  /// `ai` or `seller`: whose label this is.
  final String? outcomeBy;

  /// The label worth drawing, or null. `undecided` is drawn as nothing.
  String? get shownOutcome =>
      outcome == null || outcome == 'undecided' ? null : outcome;

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
        aiPaused: aiPaused,
        outcome: outcome,
        outcomeReason: outcomeReason,
        outcomeBy: outcomeBy,
      );

  /// The same conversation with only these changed. What opening it (nothing
  /// unread) and the pause switch need, without a reload.
  Conversation copyWith({
    int? unreadCount,
    bool? aiPaused,
    String? outcome,
    String? outcomeReason,
    String? outcomeBy,
    bool clearReason = false,
  }) =>
      Conversation(
        id: id,
        platform: platform,
        customerName: customerName,
        customerAvatarUrl: customerAvatarUrl,
        preview: preview,
        lastMessageType: lastMessageType,
        lastMessageAt: lastMessageAt,
        lastInboundAt: lastInboundAt,
        windowExpiresAt: windowExpiresAt,
        unreadCount: unreadCount ?? this.unreadCount,
        aiState: aiState,
        aiEscalationReason: aiEscalationReason,
        aiEscalationCode: aiEscalationCode,
        aiPaused: aiPaused ?? this.aiPaused,
        outcome: outcome ?? this.outcome,
        outcomeReason: clearReason ? null : (outcomeReason ?? this.outcomeReason),
        outcomeBy: outcomeBy ?? this.outcomeBy,
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
        aiPaused: (row['ai_paused'] as bool?) ?? false,
        outcome: row['outcome'] as String?,
        outcomeReason: row['outcome_reason'] as String?,
        outcomeBy: row['outcome_by'] as String?,
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
/// This exists so the assistant can answer "how much is it", "do you have it"
/// and "can I see it", not so the seller can run their stock from here — no
/// variants, no SKUs, no quantities. Sizes and colours go in [description], in
/// the seller's own words: the product owner asked for the least typing for
/// the seller, even if the assistant has to work harder to read it.
class Product {
  const Product({
    this.id,
    required this.name,
    this.price,
    this.description,
    this.inStock = true,
    this.categoryId,
    this.category,
    this.photos = const [],
    this.code,
  });

  /// Null for a product that has been typed in but not saved yet.
  final String? id;

  /// The seller's own code for it — "FS-101". Optional, unique in the shop,
  /// and what a second import of a sheet matches on. Names are not matched:
  /// a shop writes one product in Arabic in one place and English in another.
  final String? code;

  final String name;
  final double? price;
  final String? description;
  final bool inStock;

  final String? categoryId;

  /// The category's name, read alongside the product. On a product read out of
  /// a spreadsheet it is the only one of the two that is set: the id is found,
  /// or the category made, when it is saved.
  final String? category;

  /// Storage paths in the product-photos bucket. The first is the cover, and
  /// the one the assistant sends.
  final List<String> photos;

  Product copyWith({
    String? name,
    double? price,
    String? description,
    bool? inStock,
    bool clearPrice = false,
    List<String>? photos,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        price: clearPrice ? null : (price ?? this.price),
        description: description ?? this.description,
        inStock: inStock ?? this.inStock,
        categoryId: categoryId,
        category: category,
        photos: photos ?? this.photos,
        code: code,
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
        categoryId: row['category_id'] as String?,
        code: row['code'] as String?,
        category: (row['categories'] as Map<String, dynamic>?)?['name'] as String?,
        photos: [
          for (final path in (row['photos'] as List<dynamic>?) ?? const []) path as String,
        ],
      );
}

/// A group of products, so an offer can name all of them at once.
class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;

  factory Category.fromRow(Map<String, dynamic> row) =>
      Category(id: row['id'] as String, name: row['name'] as String);
}

enum OfferKind {
  /// خصم 20%
  percent,

  /// 5 دنانير خصم
  amount,

  /// اشتري 2 والثالثة مجاناً. Has no price of its own — the assistant states
  /// the rule and never adds up a basket.
  buyGet,

  /// Written by the seller in their own words, and read by the assistant as
  /// written. For everything the three above do not cover.
  text;

  String get stored => this == buyGet ? 'buy_get' : name;

  static OfferKind of(String? value) => switch (value) {
        'amount' => amount,
        'buy_get' => buyGet,
        'text' => text,
        _ => percent,
      };
}

/// A sale the seller is running, or has run, or will.
///
/// No categories and no products named means the whole shop. Dates are
/// inclusive and read in Amman; either end may be open.
class Offer {
  const Offer({
    this.id,
    this.name,
    required this.kind,
    this.value,
    this.buy,
    this.get,
    this.categoryIds = const [],
    this.productIds = const [],
    this.startsOn,
    this.endsOn,
    this.enabled = true,
    this.description,
  });

  final String? id;
  final String? name;
  final OfferKind kind;

  /// The seller's own words, for an offer of kind [OfferKind.text].
  final String? description;

  /// The percentage, or the amount off. Null for buy X get Y.
  final double? value;
  final int? buy;
  final int? get;
  final List<String> categoryIds;
  final List<String> productIds;

  /// `YYYY-MM-DD`, compared as text, the same way the server does.
  final String? startsOn;
  final String? endsOn;
  final bool enabled;

  bool get wholeShop => categoryIds.isEmpty && productIds.isEmpty;

  bool covers(Product product) =>
      wholeShop ||
      (product.id != null && productIds.contains(product.id)) ||
      (product.categoryId != null && categoryIds.contains(product.categoryId));

  OfferState stateOn(String today) {
    if (!enabled) return OfferState.off;
    if (startsOn != null && today.compareTo(startsOn!) < 0) return OfferState.scheduled;
    if (endsOn != null && today.compareTo(endsOn!) > 0) return OfferState.ended;
    return OfferState.running;
  }

  Offer copyWith({bool? enabled}) => Offer(
        id: id,
        name: name,
        kind: kind,
        value: value,
        buy: buy,
        get: get,
        categoryIds: categoryIds,
        productIds: productIds,
        startsOn: startsOn,
        endsOn: endsOn,
        enabled: enabled ?? this.enabled,
        description: description,
      );

  factory Offer.fromRow(Map<String, dynamic> row) => Offer(
        id: row['id'] as String?,
        name: row['name'] as String?,
        kind: OfferKind.of(row['kind'] as String?),
        value: switch (row['value']) {
          final num value => value.toDouble(),
          final String value => double.tryParse(value),
          _ => null,
        },
        buy: (row['buy'] as num?)?.toInt(),
        get: (row['get'] as num?)?.toInt(),
        categoryIds: [for (final id in (row['category_ids'] as List?) ?? const []) id as String],
        productIds: [for (final id in (row['product_ids'] as List?) ?? const []) id as String],
        startsOn: row['starts_on'] as String?,
        endsOn: row['ends_on'] as String?,
        enabled: row['enabled'] as bool? ?? true,
        description: row['description'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'name': name?.trim().isEmpty ?? true ? null : name!.trim(),
        'kind': kind.stored,
        // Only the two kinds with a number of their own carry one. The database
        // refuses a worded offer with a value, and a buy X get Y with one.
        'value': kind == OfferKind.percent || kind == OfferKind.amount ? value : null,
        'description': kind == OfferKind.text ? description?.trim() : null,
        'buy': kind == OfferKind.buyGet ? buy : null,
        'get': kind == OfferKind.buyGet ? get : null,
        'category_ids': categoryIds,
        'product_ids': productIds,
        'starts_on': startsOn,
        'ends_on': endsOn,
        'enabled': enabled,
      };
}

enum OfferState { running, scheduled, ended, off }

/// What prices are in when the shop has not said: the Jordanian dinar, written
/// out, as the product owner set it on 22 September 2026. The same words as
/// DEFAULT_CURRENCY in the webhook's ai.ts and the column default.
const defaultCurrency = 'دينار أردني';

/// Today in Amman, as `YYYY-MM-DD`. Jordan has kept UTC+3 all year since 2022,
/// so a fixed offset is the whole of it — the browser's own time zone is not,
/// since a seller abroad would see the wrong day.
String todayInAmman([DateTime? now]) {
  final amman = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${amman.year}-${two(amman.month)}-${two(amman.day)}';
}

/// What a product costs today with the best offer that covers it, or null if
/// none brings the price down.
///
/// The same rule as `salePrice` in the webhook's ai.ts, which is what the
/// assistant tells customers. The two are held together by the shared cases in
/// test/fixtures/offers.json: offers do not stack, the lowest price wins,
/// worked in whole fils, never below nothing.
double? salePrice(Product product, List<Offer> offers, String today) {
  final listed = product.price;
  if (listed == null) return null;

  final fils = (listed * 1000).round();
  int? best;

  for (final offer in offers) {
    // Only the kinds with a price of their own; a worded offer is read by the
    // assistant, not computed.
    if (offer.kind != OfferKind.percent && offer.kind != OfferKind.amount) continue;
    if (offer.stateOn(today) != OfferState.running || !offer.covers(product)) continue;

    final value = offer.value;
    if (value == null || value <= 0) continue;

    final after = offer.kind == OfferKind.percent
        ? (fils * (100 - value) / 100).round()
        : max(0, fils - (value * 1000).round());

    if (after < fils && (best == null || after < best)) best = after;
  }

  return best == null ? null : best / 1000;
}

/// A product code another product in the shop already has.
class CodeTaken implements Exception {
  const CodeTaken();
}

/// A rename to a name another category already has.
class CategoryTaken implements Exception {
  const CategoryTaken();
}

/// One name to a seller: case and surrounding space do not make a second
/// category. The same rule as the unique index in `20260923000001_catalog.sql`.
String categoryKey(String name) => name.trim().toLowerCase();

/// Where product photos live. Made in `20260923000001_catalog.sql`.
const photoBucket = 'product-photos';

/// The same cap as the check constraint on `products.photos`.
const maxPhotos = 5;

/// The small copy of a photo, kept beside it so the assistant can compare a
/// customer's screenshot against the catalog without reading full-size images.
String thumbnailOf(String path) => path.replaceFirst(RegExp(r'\.jpg$'), '_s.jpg');

/// A photo the seller has picked and not saved yet, already shrunk in the
/// browser. A phone photo arrives at about 6 MB, and a catalog does not need
/// that.
class PickedPhoto {
  const PickedPhoto({required this.full, required this.thumbnail});

  final Uint8List full;
  final Uint8List thumbnail;
}

/// One photo in the editor: either already stored, with a [path], or just
/// [picked]. One list of these keeps the seller's order across both, so a new
/// photo can be made the cover.
class PhotoSlot {
  const PhotoSlot.stored(String this.path) : picked = null;
  const PhotoSlot.picked(PickedPhoto this.picked) : path = null;

  final String? path;
  final PickedPhoto? picked;
}

/// What the assistant does when a customer pushes on price.
///
/// Neither mode invents a discount. What the assistant may say about money
/// comes from the catalog, and will come from the sales section once that
/// exists — the stance only decides what happens after it has said what it
/// knows.
enum PriceStance {
  /// The listed price is the price. The assistant says so warmly, then offers
  /// the cheapest thing that still suits, because a price somebody cannot meet
  /// is a reason to show them something else rather than to stop.
  strict,

  /// The assistant answers the price, argues nothing, and hands the
  /// conversation to the seller. The default, and the original behaviour.
  notify;

  /// Anything unfamiliar reads as `notify`.
  ///
  /// The safe direction, and deliberately not an error: a build that predates a
  /// stance added later must not fall back to telling customers a price is
  /// final on a shop that never said so.
  static PriceStance of(String? value) =>
      value == 'strict' ? PriceStance.strict : PriceStance.notify;

  String get stored => name;
}

/// The shop itself: everything a customer asks about that is not a product.
///
/// A catalog answers "how much is the red dress". Half of what a customer
/// actually asks is delivery, hours and where you are, and without these the
/// assistant hands most of a normal conversation back to the seller.
class Shop {
  const Shop({
    this.currency = defaultCurrency,
    this.deliveryNote,
    this.locations,
    this.hours,
    this.about,
    this.assistantEnabled = false,
    this.priceStance = PriceStance.notify,
    this.guide,
    this.guideSteps,
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

  /// What the assistant does when a customer pushes on price.
  ///
  /// It only reaches the customer through `renderFacts` on the server — which
  /// is also what makes the strict claim legitimate, because the guard that
  /// refuses invented price policies searches that same text.
  final PriceStance priceStance;

  /// How the seller wants conversations run, in their own words.
  final String? guide;

  /// The assistant's reading of [guide], drawn back as a diagram. Saved with
  /// it by the `guide` function, so it is always the reading of these words.
  final GuideSteps? guideSteps;

  Shop copyWith({
    String? currency,
    String? deliveryNote,
    String? locations,
    String? hours,
    String? about,
    bool? assistantEnabled,
    PriceStance? priceStance,
  }) =>
      Shop(
        currency: currency ?? this.currency,
        deliveryNote: deliveryNote ?? this.deliveryNote,
        locations: locations ?? this.locations,
        hours: hours ?? this.hours,
        about: about ?? this.about,
        assistantEnabled: assistantEnabled ?? this.assistantEnabled,
        priceStance: priceStance ?? this.priceStance,
      );

  factory Shop.fromRow(Map<String, dynamic> row) => Shop(
        currency: (row['currency'] as String?)?.trim().isNotEmpty == true
            ? (row['currency'] as String).trim()
            : defaultCurrency,
        deliveryNote: row['delivery_note'] as String?,
        locations: row['locations'] as String?,
        hours: row['hours'] as String?,
        about: row['about'] as String?,
        assistantEnabled: row['assistant_enabled'] as bool? ?? false,
        priceStance: PriceStance.of(row['price_stance'] as String?),
        guide: row['guide'] as String?,
        guideSteps: GuideSteps.fromJson(row['guide_steps']),
      );
}

/// The seller's guide, read into situations and what to do in each.
///
/// [when] null is a rule for every conversation. [cannot] is what the seller
/// asked for that the assistant has no way to do, shown so it is not silently
/// dropped.
class GuideSteps {
  const GuideSteps({required this.rules, required this.cannot});

  final List<GuideRule> rules;
  final List<({String text, String why})> cannot;

  bool get isEmpty => rules.isEmpty && cannot.isEmpty;

  /// Null for anything that is not a reading, so a malformed row draws
  /// nothing rather than throwing on the seller's screen.
  static GuideSteps? fromJson(Object? json) {
    if (json is! Map) return null;
    final rules = json['rules'];
    final cannot = json['cannot'];
    if (rules is! List || cannot is! List) return null;

    return GuideSteps(
      rules: [
        for (final r in rules)
          if (r is Map)
            GuideRule(
              when: r['when'] is String ? r['when'] as String : null,
              actions: [for (final a in (r['do'] as List?) ?? const []) if (a is String) a],
              handover: r['handover'] == true,
            ),
      ],
      cannot: [
        for (final c in cannot)
          if (c is Map && c['text'] is String)
            (text: c['text'] as String, why: c['why'] is String ? c['why'] as String : ''),
      ],
    );
  }
}

class GuideRule {
  const GuideRule({required this.when, required this.actions, required this.handover});

  final String? when;
  final List<String> actions;
  final bool handover;
}

/// The workspace's plan, and how much of this month's assistant replies it
/// has used.
class Allowance {
  const Allowance({required this.plan, required this.limit, required this.used});

  final String plan;
  final int limit;
  final int used;

  /// From 80%: early enough to do something about it, late enough not to nag.
  bool get nearlyUsed => !usedUp && used >= limit * 0.8;

  bool get usedUp => used >= limit;
}

/// Why the guide was not saved. Codes from the function, worded here.
class GuideRefused implements Exception {
  const GuideRefused(this.reason);
  final String reason;
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
///
/// `category` and `code` are last because they were added last. A file with no
/// header is read in this order, so a new column anywhere else would shift
/// every file saved from the old template by one.
const catalogColumns = ['name', 'price', 'description', 'in_stock', 'category', 'code'];

/// A spreadsheet the seller can fill in, with one example row to show the
/// shape. Arabic, because that is the language this product is for.
String catalogTemplateCsv() => '$catalogBom${catalogColumns.join(',')}\n'
    'فستان أحمر,25.500,قطن، مقاسات S M L,yes,فساتين,FS-101\n';

/// Products read out of a spreadsheet the seller filled in.
///
/// Forgiving on purpose: a seller exporting from Excel or Google Sheets has no
/// idea what a delimiter is, and a file that imports nothing with no
/// explanation is worse than one that imports what it understood. Rows with no
/// name are skipped, because a price with nothing attached to it is not a
/// product.
List<Product> parseCatalogCsv(String content) => readCatalogCsv(content).products;

CatalogSheet readCatalogCsv(String content) {
  final cleaned = content.replaceFirst(catalogBom, '');
  return readCatalogRows(_csvRows(cleaned, _delimiterOf(cleaned)));
}

/// The first sheet in an Excel workbook that has anything in it, as products.
///
/// Sellers keep price lists in Excel already. Asking them to save it as CSV
/// first is a step most do not know how to take.
List<Product> parseCatalogXlsx(Uint8List bytes) => readCatalogXlsx(bytes).products;

CatalogSheet readCatalogXlsx(Uint8List bytes) {
  final workbook = Excel.decodeBytes(bytes);

  for (final sheet in workbook.tables.values) {
    final rows = [
      for (final row in sheet.rows) [for (final cell in row) _cellText(cell?.value)],
    ];

    final read = readCatalogRows(rows);
    if (read.products.isNotEmpty) return read;
  }

  return const CatalogSheet([], {});
}

/// Products read out of a sheet, and which of our fields it had a column for.
///
/// The columns matter when the sheet updates products already saved. A sheet
/// with no stock column says nothing about stock, and must not put every
/// product the seller marked out of stock back in stock just because
/// [Product.inStock] defaults to true.
class CatalogSheet {
  const CatalogSheet(this.products, this.columns);

  final List<Product> products;
  final Set<String> columns;
}

/// What a sheet does to the catalog: products to add, and products already
/// there to update, each carrying its saved id.
///
/// A row updates the product with the same code — ignoring case and spacing.
/// Asked for by the product owner on 22 September 2026, and specifically not
/// by name: a shop writes one product in Arabic in one place and English in
/// another, and matching on names would update the wrong thing or nothing. So
/// a row with no code is always a new product, and a row whose code is new is
/// a new product that keeps that code. Matched by code, a row can rename a
/// product.
///
/// An update changes only what the sheet has something to say about. A column
/// the sheet does not have leaves the field alone, and so does an empty cell —
/// a blank is far more often a cell nobody filled in than a request to clear
/// it. Photos are never touched by a sheet. If one code appears twice in the
/// sheet, the lower row wins, as it would if it were typed in order.
///
/// Codes are given to the new products that have none — see [nextCodes] — so
/// that every product can be matched the next time.
({List<Product> added, List<Product> updated}) planImport(
  CatalogSheet sheet,
  List<Product> existing,
) {
  String key(String code) => code.trim().toLowerCase();

  final saved = {
    for (final product in existing)
      if (product.code != null) key(product.code!): product,
  };

  // Rows with a code collapse onto it; rows without one are all kept.
  final coded = <String, Product>{};
  final uncoded = <Product>[];
  for (final row in sheet.products) {
    if (row.code == null) {
      uncoded.add(row);
    } else {
      coded[key(row.code!)] = row;
    }
  }

  final added = <Product>[];
  final updated = <Product>[];
  final has = sheet.columns.contains;

  for (final MapEntry(key: code, value: row) in coded.entries) {
    final old = saved[code];
    if (old == null) {
      if (row.name.isNotEmpty) added.add(row);
      continue;
    }

    final category = has('category') && row.category != null ? row.category : null;

    updated.add(Product(
      id: old.id,
      code: old.code,
      name: row.name.isNotEmpty ? row.name : old.name,
      price: has('price') && row.price != null ? row.price : old.price,
      description:
          has('description') && row.description != null ? row.description : old.description,
      inStock: has('in_stock') ? row.inStock : old.inStock,
      // A new category is carried by name and resolved when saved; an
      // unchanged one keeps its id.
      categoryId: category == null ? old.categoryId : null,
      category: category ?? old.category,
      photos: old.photos,
    ));
  }

  final codes = nextCodes([...existing.map((p) => p.code), ...coded.values.map((p) => p.code)], uncoded.length);

  for (final (index, row) in uncoded.indexed) {
    added.add(Product(
      name: row.name,
      price: row.price,
      description: row.description,
      inStock: row.inStock,
      category: row.category,
      code: codes[index],
    ));
  }

  return (added: added, updated: updated);
}

/// The catalog as an Excel file the seller can edit and import again.
///
/// This is what makes generated codes useful: a seller who imported a sheet
/// with no codes gets them here, in a file that imports straight back and
/// updates what it lists. The headers are given in the seller's language and
/// are words the importer already reads — a test round-trips them.
Uint8List catalogWorkbook(
  List<Product> products, {
  required List<String> headers,
  required String yes,
  required String no,
}) {
  final book = Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];

  sheet.appendRow([for (final header in headers) TextCellValue(header)]);

  for (final product in products) {
    sheet.appendRow([
      TextCellValue(product.code ?? ''),
      TextCellValue(product.name),
      product.price == null ? null : DoubleCellValue(product.price!),
      TextCellValue(product.description ?? ''),
      TextCellValue(product.inStock ? yes : no),
      TextCellValue(product.category ?? ''),
    ]);
  }

  return Uint8List.fromList(book.encode()!);
}

/// The next [count] free codes in this shop: P-001, P-002…
///
/// Numbered after the highest P- code already taken rather than filling gaps,
/// so a code a seller deleted is not handed to a different product that their
/// old sheet would then update. Codes the seller chose themselves — "FS-101" —
/// are left alone and never collide, because they are not P- numbers.
List<String> nextCodes(Iterable<String?> taken, int count) {
  var highest = 0;
  for (final code in taken) {
    final match = RegExp(r'^p-(\d+)$').firstMatch(code?.trim().toLowerCase() ?? '');
    if (match != null) highest = max(highest, int.parse(match.group(1)!));
  }

  return [
    for (var i = 1; i <= count; i++) 'P-${(highest + i).toString().padLeft(3, '0')}',
  ];
}

/// A cell as the seller would read it. A whole number stored as 25.0 is "25",
/// not "25.0" — the same price the seller typed.
String _cellText(CellValue? value) => switch (value) {
      null => '',
      DoubleCellValue(value: final number) when number == number.roundToDouble() =>
        number.round().toString(),
      DoubleCellValue(value: final number) => number.toString(),
      IntCellValue(value: final number) => number.toString(),
      TextCellValue() => value.value.toString(),
      _ => value.toString(),
    };

/// Headers that mean one of our columns, in the words sellers actually use.
///
/// A seller's own sheet says "اسم المنتج" or "Product name", not `name`. Each
/// header is matched by containing one of these, in the order of this map:
/// category and price come before name because "اسم القسم" and "product price"
/// contain a word for name as well.
const _headerWords = {
  'category': ['category', 'type', 'section', 'collection', 'قسم', 'فئة', 'تصنيف', 'نوع'],
  'price': ['price', 'سعر'],
  'in_stock': [
    'stock', 'available', 'availability', 'qty', 'quantity',
    'متوفر', 'توفر', 'كمية', 'مخزون',
  ],
  'description': ['description', 'details', 'notes', 'desc', 'وصف', 'تفاصيل', 'ملاحظات'],
  'name': ['name', 'product', 'item', 'title', 'اسم', 'منتج', 'صنف', 'قطعة'],
};

/// Headers whose column is dropped rather than read, checked before anything
/// else. What a shop paid for something must never reach a customer, and
/// "سعر التكلفة" — cost price — contains the word for price. Barcodes and
/// links are dropped because the assistant has nothing useful to say with them.
const _dropWords = [
  'cost', 'تكلفة', 'كلفة', 'wholesale', 'جملة', 'profit', 'ربح', 'margin',
  'supplier', 'مورد', 'vendor', 'purchase', 'شراء',
  'barcode', 'باركود', 'image', 'photo', 'صورة', 'link', 'url', 'رابط',
];

/// Columns that are only ever a row number.
const _serialHeaders = {'#', 'no', 'no.', 'م', 'ت'};

/// Headers that are the seller's own product code — what a second import
/// matches on. Checked before the drop words, which hold "barcode", and
/// before names, since "رقم المنتج" contains the word for product.
bool _isCode(String words) =>
    words == 'id' ||
    words.endsWith(' id') ||
    words == 'رقم المنتج' ||
    words == 'رقم' ||
    (!words.contains('bar') && !words.contains('باركود') &&
        ['code', 'sku', 'كود', 'رمز'].any(words.contains));

const _drop = '-';

/// Which of our columns a header means: one of [catalogColumns], [_drop] for
/// one to ignore, or null for a column we do not have but the seller filled
/// in — colour, size, material. Those are not thrown away.
String? _columnOf(String header) {
  final words = header.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (words.isEmpty || _serialHeaders.contains(words)) return _drop;
  if (catalogColumns.contains(words)) return words;
  if (_isCode(words)) return 'code';
  if (_dropWords.any(words.contains)) return _drop;

  for (final MapEntry(key: column, value: aliases) in _headerWords.entries) {
    if (aliases.any(words.contains)) return column;
  }

  return null;
}

/// Where the header is, if there is one.
///
/// Not always the first row: a seller's own sheet often starts with a title —
/// the shop's name, "قائمة الأسعار" — and a blank line. So the first few rows
/// are searched for one that names a product column and at least one other.
int? _headerRow(List<List<String>> rows) {
  for (var i = 0; i < rows.length && i < 10; i++) {
    final columns = rows[i].map(_columnOf).whereType<String>().where((c) => c != _drop).toSet();
    if (columns.contains('name') && columns.length > 1) return i;

    // Our own template's header, even with only the name column left in it.
    if (rows[i].any((cell) => catalogColumns.contains(cell.trim().toLowerCase()))) return i;
  }

  return null;
}

/// Rows of cells, from either kind of file, as products.
///
/// Columns we have no field for are kept rather than dropped: they are added
/// to the details as "Colour: red", in the seller's own header. The product
/// owner asked for the least work for the seller even if it is more for the
/// assistant — so the seller's sheet is taken as it is and the assistant reads
/// what is in it, rather than the seller being asked to reshape it first.
List<Product> parseCatalogRows(List<List<String>> rows) => readCatalogRows(rows).products;

CatalogSheet readCatalogRows(List<List<String>> rows) {
  if (rows.isEmpty) return const CatalogSheet([], {});

  // With no header the file starts with data, and is read in the template's
  // own order.
  final at = _headerRow(rows);
  final headers = at == null ? catalogColumns : rows[at];
  final columns = at == null ? catalogColumns : headers.map(_columnOf).toList();
  final body = at == null ? rows : rows.skip(at + 1);

  // The first column that means each field is the one read. A second "price"
  // column — a sale price, an old price — is kept in the details instead of
  // silently overriding the first.
  final first = <String, int>{};
  for (final (index, column) in columns.indexed) {
    if (column != null && column != _drop) first.putIfAbsent(column, () => index);
  }

  final products = <Product>[];

  for (final row in body) {
    String? at(int? index) {
      if (index == null || index >= row.length) return null;

      final value = row[index].trim();
      return value.isEmpty ? null : value;
    }

    String? cell(String column) => at(first[column]);

    // A row needs a name or a code. A code alone is an update — a new price
    // for FS-101 — and needs no name; planImport drops it if nothing has that
    // code, rather than adding a product with no name.
    final name = cell('name');
    if (name == null && cell('code') == null) continue;

    final extras = [
      for (final (index, column) in columns.indexed)
        if (column != _drop && first[column] != index && at(index) != null)
          '${headers[index].trim()}: ${at(index)}',
    ];

    final description = [?cell('description'), ...extras].join('\n');

    products.add(Product(
      name: name ?? '',
      price: _price(cell('price')),
      description: description.isEmpty ? null : description,
      inStock: _inStock(cell('in_stock')),
      category: cell('category'),
      code: cell('code'),
    ));
  }

  // Columns beyond our own are written into the details, so a sheet that has
  // them has something to say about the details too.
  final hasExtras = columns.indexed.any(
    (entry) => entry.$2 != _drop && first[entry.$2] != entry.$1,
  );

  return CatalogSheet(products, {...first.keys, if (hasExtras) 'description'});
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
/// Inside the waiting group, what the assistant handed over comes first. The
/// customer was told a person is coming, and the product owner could not tell
/// such a conversation apart from the rest (23 September 2026). Oldest first
/// within each part, so neither part starves.
///
/// Pure, so the ordering can be tested without a database.
List<Conversation> inboxOrder(List<Conversation> all) {
  final waiting = all.where((c) => c.awaitingReply).toList()
    ..sort((a, b) {
      if (a.escalated != b.escalated) return a.escalated ? -1 : 1;
      return a.lastInboundAt!.compareTo(b.lastInboundAt!);
    });

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

/// The reasons a customer did not buy, in the order the seller reads them.
const lostReasons = [
  'price',
  'delivery_fee',
  'delivery_time',
  'size_or_variant',
  'out_of_stock',
  'not_sold',
  'no_answer',
  'unknown',
];

/// One week of how conversations ended, as `outcome_summary` returns it.
class WeekSummary {
  const WeekSummary({
    required this.conversations,
    required this.ordered,
    required this.notBought,
    required this.justAsking,
    required this.open,
    required this.reasons,
    required this.products,
    required this.areas,
    required this.unanswered,
    required this.hours,
    required this.readByAssistant,
    required this.corrected,
  });

  final int conversations;
  final int ordered;
  final int notBought;
  final int justAsking;
  final int open;

  /// Reason code to count, most common first.
  final List<MapEntry<String, int>> reasons;
  final List<({String name, int asked, int ordered})> products;
  final List<({String name, int count})> areas;
  final int unanswered;

  /// 24 counts, midnight first, in Amman time.
  final List<int> hours;
  final int readByAssistant;
  final int corrected;

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  factory WeekSummary.fromJson(Map<String, dynamic> j) {
    final reasons = Map<String, dynamic>.from((j['reasons'] as Map?) ?? {})
        .entries
        .map((e) => MapEntry(e.key, _int(e.value)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return WeekSummary(
      conversations: _int(j['conversations']),
      ordered: _int(j['ordered']),
      notBought: _int(j['not_bought']),
      justAsking: _int(j['just_asking']),
      open: _int(j['open']),
      reasons: reasons,
      products: [
        for (final p in (j['products'] as List?) ?? const [])
          (name: p['name'] as String, asked: _int(p['asked']), ordered: _int(p['ordered'])),
      ],
      areas: [
        for (final a in (j['areas'] as List?) ?? const [])
          (name: a['name'] as String, count: _int(a['count'])),
      ],
      unanswered: _int(j['unanswered']),
      hours: [for (final h in (j['hours'] as List?) ?? List.filled(24, 0)) _int(h)],
      readByAssistant: _int(j['read_by_assistant']),
      corrected: _int(j['corrected']),
    );
  }

  /// The busiest three hours of the day, as a start hour, or null on an empty
  /// week. Three hours wide because "most messages at 21:00" is noise and
  /// "21:00 to midnight" is a plan.
  int? get busiestFrom {
    if (hours.length != 24 || hours.every((h) => h == 0)) return null;
    var best = 0, bestSum = -1;
    for (var start = 0; start < 24; start++) {
      final sum = hours[start] + hours[(start + 1) % 24] + hours[(start + 2) % 24];
      if (sum > bestSum) {
        best = start;
        bestSum = sum;
      }
    }
    return best;
  }
}

/// Whether a password meets the rule the server enforces: ten characters,
/// with a lower-case letter, an upper-case letter and a digit. Checked here
/// first so the seller is told in words, rather than by a refusal from the
/// server after they have typed it twice.
bool passwordStrongEnough(String password) =>
    password.length >= 10 &&
    RegExp(r'[a-z]').hasMatch(password) &&
    RegExp(r'[A-Z]').hasMatch(password) &&
    RegExp(r'[0-9]').hasMatch(password);

/// The conversations matching what the seller typed into search.
///
/// Name and latest preview are matched here, from what is already loaded;
/// [inHistory] carries the ids whose older messages matched on the server.
/// Case-insensitive, and an empty query is no filter at all.
List<Conversation> searchConversations(
  List<Conversation> all,
  String query, {
  Set<String> inHistory = const {},
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;

  return all
      .where((c) =>
          inHistory.contains(c.id) ||
          (c.customerName ?? '').toLowerCase().contains(q) ||
          (c.preview ?? '').toLowerCase().contains(q))
      .toList();
}

/// What the "remember this" box starts with: the customer's question and the
/// seller's answer, on one line the assistant can read as a fact.
String answerDraft(String? question, String reply) {
  final q = question?.trim() ?? '';
  final a = reply.trim();
  return q.isEmpty ? a : '$q — $a';
}

/// The shop's free-text field with one more answer on the end.
String appendAnswer(String? about, String answer) {
  final existing = about?.trim() ?? '';
  final added = answer.trim();
  if (added.isEmpty) return existing;
  return existing.isEmpty ? added : '$existing\n$added';
}

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
          'ai_escalation_code, ai_paused, outcome, outcome_reason, outcome_by, '
          'connected_accounts!inner(platform)',
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
  /// The link to send by hand, or null when the invitation was emailed —
  /// which is what a project with real SMTP does. See INVITE_BY_EMAIL in
  /// supabase/functions/admin-invite.
  Future<String?> invite(String email) async {
    try {
      final response = await _db.functions.invoke(
        'admin-invite',
        body: {'email': email.trim()},
      );

      final data = response.data as Map?;
      if (data?['sent'] == true) return null;

      final link = data?['link'] as String?;
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
  /// A disconnected account is still returned, because its conversations are
  /// still here; the Accounts page leaves it out of its list.
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
        .select('id, code, name, price, description, in_stock, category_id, photos, categories(name)')
        .order('name', ascending: true);

    return rows.map(Product.fromRow).toList();
  }

  Future<List<Category>> categories() async {
    final rows = await _db.from('categories').select('id, name').order('name', ascending: true);
    return rows.map(Category.fromRow).toList();
  }

  /// The id of the category with this name, made if there is not one yet.
  ///
  /// Typing a category is how one is made — there is no screen for managing
  /// them, because a seller would never open it. Null for a blank name, which
  /// means no category.
  Future<String?> categoryNamed(String? name, [List<Category>? known]) async {
    if (name == null || name.trim().isEmpty) return null;

    final existing = (known ?? await categories())
        .where((category) => categoryKey(category.name) == categoryKey(name));
    if (existing.isNotEmpty) return existing.first.id;

    final workspace = await _workspaceId();
    final row = await _db
        .from('categories')
        .insert({'workspace_id': workspace, 'name': name.trim()})
        .select('id')
        .single();

    return row['id'] as String;
  }

  /// Offers point at a category by id, so a rename keeps every offer on it.
  /// A name another category already has is refused by the unique index;
  /// that arrives here as [CategoryTaken] so the interface can say so.
  Future<void> renameCategory(String id, String name) async {
    try {
      await _db.from('categories').update({'name': name.trim()}).eq('id', id);
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const CategoryTaken();
      rethrow;
    }
  }

  /// Its products keep everything but the category (`on delete set null`).
  ///
  /// Offers that name it are deliberately left alone. An offer with no
  /// targets means the whole shop, so taking this id out of them would turn
  /// "20% off dresses" into 20% off everything. Left in, it matches nothing,
  /// the assistant says nothing about it, and the offers screen says it no
  /// longer covers anything.
  Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }

  /// Where a photo can be fetched from. Public, because Meta fetches it itself
  /// to deliver it to a customer — see `20260923000001_catalog.sql`.
  String photoUrl(String path) => _db.storage.from(photoBucket).getPublicUrl(path);

  /// Puts a picked photo in storage and returns its path.
  ///
  /// The path starts with the workspace id because that is what the storage
  /// policy checks. The file name is random so the public URL cannot be
  /// guessed from another one.
  Future<String> uploadPhoto(PickedPhoto photo) async {
    final workspace = await _workspaceId();
    final random = Random.secure();
    final name = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final path = '$workspace/$name.jpg';

    const options = FileOptions(contentType: 'image/jpeg');
    final bucket = _db.storage.from(photoBucket);
    await bucket.uploadBinary(path, photo.full, fileOptions: options);
    await bucket.uploadBinary(thumbnailOf(path), photo.thumbnail, fileOptions: options);

    return path;
  }

  /// Removes photos and their thumbnails.
  ///
  /// Called after the row that pointed at them is saved or deleted, and its
  /// failure is swallowed: a file left over in storage costs a few hundred
  /// kilobytes, while failing the save over it would lose what the seller
  /// typed.
  Future<void> removePhotos(Iterable<String> paths) async {
    final all = [for (final path in paths) ...[path, thumbnailOf(path)]];
    if (all.isEmpty) return;

    try {
      await _db.storage.from(photoBucket).remove(all);
    } catch (_) {
      // ponytail: orphaned files are left behind. Sweep the bucket for paths
      // no product names if storage ever costs enough to notice.
    }
  }

  /// Adds a product, or updates the one already saved.
  ///
  /// No workspace is named. Row level security fills it in from the seller's
  /// own token, the same as every other write in this file.
  ///
  /// [photos] is the editor's list in the seller's order: photos already
  /// stored, and ones picked but not yet uploaded. The new ones go up here, on
  /// save, rather than when they are picked, so a seller who cancels leaves
  /// nothing behind. Null keeps whatever the product already had.
  ///
  /// [previousPhotos] are the ones the product had before the edit, so any the
  /// seller removed can be deleted from storage.
  Future<void> saveProduct(
    Product product, {
    List<PhotoSlot>? photos,
    List<String> previousPhotos = const [],
  }) async {
    final paths = photos == null
        ? product.photos
        : [for (final slot in photos) slot.path ?? await uploadPhoto(slot.picked!)];

    // Every product has a code. Left blank, it gets the next free one, so
    // the product can always be matched by a sheet later.
    final typed = product.code?.trim() ?? '';
    final code = typed.isNotEmpty
        ? typed
        : nextCodes((await products()).map((p) => p.code), 1).single;

    final values = {
      'code': code,
      'name': product.name.trim(),
      'price': product.price,
      'description': product.description?.trim(),
      'in_stock': product.inStock,
      'category_id': await categoryNamed(product.category),
      'photos': paths,
    };

    try {
      if (product.id == null) {
        final workspace = await _workspaceId();
        await _db.from('products').insert({...values, 'workspace_id': workspace});
      } else {
        await _db.from('products').update(values).eq('id', product.id!);
      }
    } catch (error) {
      // The photos went up before the row was written, so a refused row
      // would leave them in storage with nothing pointing at them.
      await removePhotos(paths.where((path) => !previousPhotos.contains(path)));

      // The only unique index a product save can hit is the code's.
      if (error is PostgrestException && error.code == '23505') throw const CodeTaken();
      rethrow;
    }

    await removePhotos(previousPhotos.where((path) => !paths.contains(path)));
  }

  Future<List<Offer>> offers() async {
    final rows = await _db
        .from('offers')
        .select(
          'id, name, kind, value, description, buy, get, category_ids, product_ids, starts_on, ends_on, enabled',
        )
        .order('created_at', ascending: true);

    return rows.map(Offer.fromRow).toList();
  }

  /// Adds an offer, or updates the one already saved. The database refuses a
  /// malformed one — a percentage of 100, an amount with no amount — so what
  /// reaches the assistant is always something it can state.
  Future<void> saveOffer(Offer offer) async {
    if (offer.id == null) {
      final workspace = await _workspaceId();
      await _db.from('offers').insert({...offer.toRow(), 'workspace_id': workspace});
    } else {
      await _db.from('offers').update(offer.toRow()).eq('id', offer.id!);
    }
  }

  Future<void> deleteOffer(String id) async {
    await _db.from('offers').delete().eq('id', id);
  }

  Future<void> deleteProduct(Product product) async {
    await _db.from('products').delete().eq('id', product.id!);
    await removePhotos(product.photos);
  }

  /// Saves a whole spreadsheet at once: new products are added, and products
  /// already in the catalog under the same name are updated — see
  /// [planImport] for exactly what changes.
  ///
  /// Nothing is ever removed. A product missing from the sheet stays, because
  /// a seller importing only their new arrivals would otherwise lose everything
  /// else.
  Future<({int added, int updated})> importProducts(CatalogSheet sheet) async {
    if (sheet.products.isEmpty) return (added: 0, updated: 0);

    final plan = planImport(sheet, await products());
    final workspace = await _workspaceId();

    // One lookup per distinct name, not per row. A category made for the first
    // row is added to the list so the fifth row finds it rather than making it
    // again and failing on the unique index.
    final known = await categories();
    final ids = <String, String?>{};
    for (final product in [...plan.added, ...plan.updated]) {
      final name = product.category;
      if (product.categoryId != null || name == null || ids.containsKey(categoryKey(name))) {
        continue;
      }

      final id = await categoryNamed(name, known);
      ids[categoryKey(name)] = id;
      if (id != null) known.add(Category(id: id, name: name));
    }

    Map<String, dynamic> row(Product product) => {
          'workspace_id': workspace,
          'code': product.code?.trim(),
          'name': product.name.trim(),
          'price': product.price,
          'description': product.description?.trim(),
          'in_stock': product.inStock,
          'category_id': product.categoryId ??
              (product.category == null ? null : ids[categoryKey(product.category!)]),
        };

    if (plan.added.isNotEmpty) {
      await _db.from('products').insert([for (final product in plan.added) row(product)]);
    }

    // One request for every update: each row carries its id and all of its
    // fields, already merged, so an upsert on the key is an update.
    if (plan.updated.isNotEmpty) {
      await _db.from('products').upsert([
        for (final product in plan.updated) {...row(product), 'id': product.id},
      ]);
    }

    return (added: plan.added.length, updated: plan.updated.length);
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
          'assistant_enabled, price_stance, guide, guide_steps',
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

  /// The plan, its monthly replies, and how many the assistant has sent.
  ///
  /// Counted the way the server counts before it answers — AI messages since
  /// the start of the month in UTC — so the number here is the number that
  /// stops it.
  Future<Allowance> allowance() async {
    final row = await _db
        .from('workspaces')
        .select('plan, plans(replies_per_month)')
        .limit(1)
        .single();

    final now = DateTime.now().toUtc();
    final used = await _db
        .from('messages')
        .count(CountOption.exact)
        .eq('origin', 'ai')
        .gte('created_at', DateTime.utc(now.year, now.month).toIso8601String());

    return Allowance(
      plan: row['plan'] as String,
      limit: ((row['plans'] as Map?)?['replies_per_month'] as num?)?.toInt() ?? 0,
      used: used,
    );
  }

  /// Saves the guide and gives back the assistant's reading of it.
  ///
  /// Through the `guide` function, which reads it and saves the words and the
  /// reading together. An empty guide clears both and reads as null.
  Future<GuideSteps?> saveGuide(String guide) async {
    try {
      final response = await _db.functions.invoke('guide', body: {'guide': guide});
      return GuideSteps.fromJson((response.data as Map?)?['steps']);
    } on FunctionException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      throw GuideRefused(reason is String ? reason : 'failed');
    } catch (_) {
      throw const GuideRefused('failed');
    }
  }

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
    final data = await _oauth('meta-oauth/start', query: {'return': Uri.base.origin});
    final url = data['url'];
    if (url is! String) throw const ConnectFailed('failed');
    return url;
  }

  /// What the page needs to open WhatsApp's signup itself: the app and the
  /// configuration. `not_configured` until that configuration exists.
  Future<({String appId, String configId})> whatsappSignupConfig() async {
    final data = await _oauth('meta-oauth/start', query: {'kind': 'whatsapp'});
    final appId = data['app_id'], configId = data['config_id'];
    if (appId is! String || configId is! String) throw const ConnectFailed('failed');
    return (appId: appId, configId: configId);
  }

  /// Hands what WhatsApp's signup returned to the server, which connects the
  /// number. Straight away: the code in it lives 30 seconds.
  Future<void> connectWhatsApp(Map<String, Object?> signup) =>
      _oauth('meta-oauth/whatsapp', body: signup);

  /// Stops an account receiving, without losing its conversations.
  Future<void> disconnect(String accountId) =>
      _oauth('meta-oauth/disconnect', body: {'account': accountId});

  /// One call to `meta-oauth`. A GET with [query], a POST with [body]. Any
  /// failure becomes a [ConnectFailed] carrying the server's reason.
  Future<Map> _oauth(String route, {Map<String, String>? query, Object? body}) async {
    try {
      final response = await _db.functions.invoke(
        route,
        method: body == null ? HttpMethod.get : HttpMethod.post,
        queryParameters: query,
        body: body,
      );
      final data = response.data;
      return data is Map ? data : const {};
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

  /// Nothing unread here any more: the seller has opened it.
  ///
  /// Only the dot. Whether the conversation is still waiting on a reply is
  /// decided by the timestamps, and opening a thread is not answering it.
  Future<void> markRead(String conversationId) async {
    await _db
        .from('conversations')
        .update({'unread_count': 0}).eq('id', conversationId);
  }

  /// Everything the admin screen shows, across every seller. The database
  /// refuses anyone who is not an admin; see admin_overview.
  Future<Map<String, dynamic>> adminOverview() async {
    final data = await _db.rpc('admin_overview');
    return Map<String, dynamic>.from(data as Map);
  }

  /// Moves a seller to another plan. Refused by the database for anyone who
  /// is not an admin.
  Future<void> setPlan(String workspaceId, String plan) =>
      _db.rpc('admin_set_plan', params: {'p_workspace': workspaceId, 'p_plan': plan});

  /// The seller's own word on how a conversation ended. Wins over the
  /// assistant's reading until the customer writes again.
  Future<void> setOutcome(String conversationId, String outcome, String? reason) async {
    await _db.from('conversations').update({
      'seller_outcome': outcome,
      'seller_outcome_reason': outcome == 'not_bought' ? reason : null,
      'seller_outcome_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', conversationId);
  }

  /// The last seven days, as the results screen shows them.
  Future<WeekSummary> week({DateTime? now}) async {
    final to = (now ?? DateTime.now()).toUtc();
    final from = to.subtract(const Duration(days: 7));
    final data = await _db.rpc('outcome_summary', params: {
      'p_from': from.toIso8601String(),
      'p_to': to.toIso8601String(),
    });
    return WeekSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// "I'll handle this one." The assistant stays out of this conversation
  /// while it is paused, whatever the shop-wide switch says.
  Future<void> setAiPaused(String conversationId, bool paused) async {
    await _db
        .from('conversations')
        .update({'ai_paused': paused}).eq('id', conversationId);
  }

  /// The conversations with a message containing [query] anywhere in their
  /// history, not only in the preview the list already holds.
  ///
  /// ponytail: `ilike` over every message, capped at 200 hits. Fine for a small
  /// shop's history; a trigram index is the upgrade if it ever feels slow.
  Future<Set<String>> searchMessages(String query) async {
    final escaped = query.replaceAll(RegExp(r'[%_\\]'), '');
    if (escaped.trim().isEmpty) return {};

    final rows = await _db
        .from('messages')
        .select('conversation_id')
        .ilike('text', '%$escaped%')
        .limit(200);

    return {for (final row in rows) row['conversation_id'] as String};
  }

  /// Asks Meta whether each connected account's token still works, and marks
  /// the ones that do not. Fire and forget: the answer arrives as a change to
  /// the accounts, which [accounts] reads.
  ///
  /// This is the only way a dead token is noticed on the receiving side. Meta
  /// simply stops delivering, so the webhook never gets a chance to see it.
  Future<void> checkAccounts() async {
    try {
      await _db.functions.invoke('meta-oauth/check', body: const {});
    } catch (_) {
      // Nothing to tell the seller: an account we could not check is not one
      // we know to be broken.
    }
  }

  /// Adds one answer to what the shop has written down for the assistant.
  ///
  /// Kept in the shop's own free-text field rather than a table of its own:
  /// that field already reaches the assistant and the checks that decide what
  /// it may say, so a saved answer is usable the moment it is saved.
  Future<void> rememberAnswer(String answer) async {
    final current = (await shop()).about;
    await updateShop({'about': appendAnswer(current, answer)});
  }

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
