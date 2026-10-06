// The sales the seller is running, and the assistant tells customers about.
//
// Asked for on 22 September 2026. Three kinds — a percentage off, an amount
// off, buy X get Y — each over the whole shop, some categories or some
// products, with optional dates. Nothing more: no promo codes (offered and
// declined), no stacking rules to choose between, no minimum basket. A seller
// should be able to set up an Eid sale in under a minute.
//
// For the three structured kinds the assistant never works a sale price out
// itself; the server does, and writes the number where the model reads it.
// An offer in the seller's own words (added 22 September 2026 for everything
// the structured kinds do not cover) is read by the assistant as written, and
// it may apply the percentage or amount it states to one listed price. This
// screen only records what the seller decided.

import 'package:flutter/material.dart';

import '../data.dart';
import '../strings.dart';
import '../theme.dart';

typedef _Loaded = ({
  List<Offer> offers,
  List<Category> categories,
  List<Product> products,
  Shop shop,
});

/// Below this the editor takes the whole screen, as the product editor does.
const _phoneWidth = 600.0;

/// A date the way a seller reads it at a glance: day and month, and the year
/// only when it is not this one. Western digits in both languages, as
/// everywhere else in the interface.
String _day(String iso, String today) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  final short = '${int.parse(parts[2])}/${int.parse(parts[1])}';
  return parts[0] == today.substring(0, 4) ? short : '$short/${parts[0]}';
}

String offerSummary(BuildContext context, Offer offer, String currency) {
  final l = context.l;
  final value = offer.value == null ? '' : formatPrice(offer.value!);

  return switch (offer.kind) {
    OfferKind.percent => l.offerSummaryPercent(value),
    OfferKind.amount => l.offerSummaryAmount(
      formatPrice(offer.value ?? 0, currency),
    ),
    OfferKind.buyGet => l.offerSummaryBuyGet(
      '${offer.buy ?? ''}',
      '${offer.get ?? ''}',
    ),
    OfferKind.text => offer.description?.trim() ?? '',
  };
}

class OffersPage extends StatefulWidget {
  const OffersPage({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  late Future<_Loaded> _loaded = _load();

  /// The row being worked on, as on the products screen.
  String? _working;

  Future<_Loaded> _load() async {
    final offers = await widget.inbox.offers();
    final categories = await widget.inbox.categories();
    final products = await widget.inbox.products();
    final shop = await widget.inbox.shop();
    return (
      offers: offers,
      categories: categories,
      products: products,
      shop: shop,
    );
  }

  void _reload() {
    if (mounted) setState(() { _loaded = _load(); });
  }

  Future<void> _run(String id, Future<void> Function() work) async {
    setState(() => _working = id);
    try {
      await work();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.l.catalogSaveFailed),
            backgroundColor: context.rabta.urgent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  Future<void> _edit(Offer? existing, _Loaded loaded) async {
    final edited = await showDialog<Offer>(
      context: context,
      builder: (context) => _OfferDialog(
        offer: existing,
        categories: loaded.categories,
        products: loaded.products,
        currency: loaded.shop.currency,
        fullScreen: MediaQuery.sizeOf(context).width < _phoneWidth,
      ),
    );

    if (edited == null || !mounted) return;
    await _run(existing?.id ?? '', () => widget.inbox.saveOffer(edited));
  }

  Future<void> _delete(Offer offer) async {
    final l = context.l;
    final colors = context.rabta;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          l.offerDeleteTitle,
          style: Style.heading.copyWith(color: colors.ink),
        ),
        content: Text(
          l.offerDeleteBody,
          style: Style.preview.copyWith(color: colors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l.cancel,
              style: Style.name.copyWith(color: colors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.productDeleteConfirm,
              style: Style.name.copyWith(color: colors.urgent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted || offer.id == null) return;
    await _run(offer.id!, () => widget.inbox.deleteOffer(offer.id!));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final today = todayInAmman();

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Text(l.offers),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: FutureBuilder<_Loaded>(
        future: _loaded,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${l.offersFailed}\n${l.catalogFailedBody}',
                  textAlign: TextAlign.center,
                  style: Style.preview.copyWith(
                    color: colors.muted,
                    height: 1.6,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: colors.muted,
                ),
              ),
            );
          }

          final loaded = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.offersBody,
                        style: Style.preview.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: 24),
                      if (loaded.offers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            l.offersEmpty,
                            style: Style.preview.copyWith(color: colors.muted),
                          ),
                        ),
                      if (loaded.offers.isNotEmpty)
                        Panel(children: [
                      for (final offer in loaded.offers)
                        _OfferRow(
                          offer: offer,
                          loaded: loaded,
                          today: today,
                          busy: _working == offer.id,
                          onToggle: (on) => _run(
                            offer.id!,
                            () => widget.inbox.saveOffer(
                              offer.copyWith(enabled: on),
                            ),
                          ),
                          onEdit: () => _edit(offer, loaded),
                          onDelete: () => _delete(offer),
                        ),
                        ]),
                      const SizedBox(height: 20),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Stamp(
                          enabled: _working == null,
                          child: FilledButton.icon(
                            onPressed: _working != null
                                ? null
                                : () => _edit(null, loaded),
                            style: FilledButton.styleFrom(
                              shape: const RoundedRectangleBorder(),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(l.offerAdd),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.loaded,
    required this.today,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Offer offer;
  final _Loaded loaded;
  final String today;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final summary = offerSummary(context, offer, loaded.shop.currency);

    // What it covers, by name: "فساتين، شنط" reads faster than "2 categories".
    final covers = offer.wholeShop
        ? l.offerWholeShop
        : [
            for (final c in loaded.categories)
              if (offer.categoryIds.contains(c.id)) c.name,
            for (final p in loaded.products)
              if (offer.productIds.contains(p.id)) p.name,
          ].join(
            Localizations.localeOf(context).languageCode == 'ar' ? '، ' : ', ',
          );

    final dates = [
      if (offer.startsOn != null &&
          offer.stateOn(today) == OfferState.scheduled)
        l.offerFrom(_day(offer.startsOn!, today)),
      if (offer.endsOn != null) l.offerUntil(_day(offer.endsOn!, today)),
    ];

    final state = offer.stateOn(today);
    final (stateLabel, stateColor) = switch (state) {
      // Accent, not teal: teal is reserved for the assistant's own messages,
      // and an offer is the seller's decision.
      OfferState.running => (l.offerRunning, colors.accent),
      OfferState.scheduled => (l.offerScheduled, colors.muted),
      OfferState.ended => (l.offerEnded, colors.muted),
      OfferState.off => (l.offerOff, colors.muted),
    };

    // Targets that no longer exist — a deleted category, a deleted product.
    // The assistant already says nothing about it; this says so to the seller
    // rather than leaving a row that looks fine and does nothing.
    final orphaned = !offer.wholeShop && covers.isEmpty;

    final title = offer.name?.trim().isNotEmpty == true
        ? offer.name!.trim()
        : summary;

    final showCovers = !(offer.kind == OfferKind.text && offer.wholeShop);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: directionOf(title),
                        style: Style.name.copyWith(color: colors.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stateLabel,
                      style: Style.meta.copyWith(
                        color: stateColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (title != summary) summary,
                    if (showCovers) orphaned ? l.offerCoversNothing : covers,
                    ...dates,
                  ]
                      .where((part) => part.trim().isNotEmpty)
                      .map(ownDirection)
                      .join(metaSeparator(context)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Style.meta.copyWith(
                    color: orphaned ? colors.urgent : colors.muted,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: busy ? null : onEdit,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 32),
                      ),
                      child: Text(
                        l.productEdit,
                        style: Style.meta.copyWith(
                          color: busy ? colors.muted : colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: busy ? null : onDelete,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 32),
                      ),
                      child: Text(
                        l.productDelete,
                        style: Style.meta.copyWith(
                          color: busy ? colors.muted : colors.urgent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: offer.enabled,
            onChanged: busy ? null : onToggle,
          ),
        ],
      ),
    );
  }
}

enum _Scope { shop, categories, products }

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({
    this.offer,
    required this.categories,
    required this.products,
    required this.currency,
    required this.fullScreen,
  });

  final Offer? offer;
  final List<Category> categories;
  final List<Product> products;
  final String currency;
  final bool fullScreen;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  late OfferKind _kind = widget.offer?.kind ?? OfferKind.percent;
  late final _value = TextEditingController(
    text: widget.offer?.value == null
        ? ''
        : formatPrice(widget.offer!.value!).replaceAll(',', ''),
  );
  late final _buy = TextEditingController(text: '${widget.offer?.buy ?? 2}');
  late final _get = TextEditingController(text: '${widget.offer?.get ?? 1}');
  late final _name = TextEditingController(text: widget.offer?.name ?? '');
  late final _description = TextEditingController(
    text: widget.offer?.description ?? '',
  );

  late _Scope _scope = widget.offer == null || widget.offer!.wholeShop
      ? _Scope.shop
      : widget.offer!.productIds.isNotEmpty
      ? _Scope.products
      : _Scope.categories;

  late final Set<String> _categories = {...?widget.offer?.categoryIds};
  late final Set<String> _products = {...?widget.offer?.productIds};

  late String? _startsOn = widget.offer?.startsOn;
  late String? _endsOn = widget.offer?.endsOn;

  @override
  void initState() {
    super.initState();
    for (final controller in [_value, _buy, _get, _description]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [_value, _buy, _get, _name, _description]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// What would be saved, or null while it is not yet something the database
  /// would accept. The save button is off until then, so the seller never
  /// meets a refusal.
  Offer? get _offer {
    final value = parsePrice(_value.text);
    final buy = int.tryParse(_buy.text.trim());
    final get = int.tryParse(_get.text.trim());

    final ok = switch (_kind) {
      OfferKind.percent => value != null && value > 0 && value < 100,
      OfferKind.amount => value != null && value > 0,
      OfferKind.buyGet => buy != null && buy >= 1 && get != null && get >= 1,
      OfferKind.text => _description.text.trim().isNotEmpty,
    };
    if (!ok) return null;

    final categories = _scope == _Scope.categories
        ? _categories.toList()
        : <String>[];
    final products = _scope == _Scope.products
        ? _products.toList()
        : <String>[];
    if (_scope != _Scope.shop && categories.isEmpty && products.isEmpty) {
      return null;
    }

    return Offer(
      id: widget.offer?.id,
      name: _name.text,
      kind: _kind,
      value: value,
      buy: buy,
      get: get,
      categoryIds: categories,
      productIds: products,
      startsOn: _startsOn,
      endsOn: _endsOn,
      enabled: widget.offer?.enabled ?? true,
      description: _description.text,
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final today = DateTime.parse(todayInAmman());
    final current = start ? _startsOn : _endsOn;

    final picked = await showDatePicker(
      context: context,
      initialDate: current == null ? today : DateTime.parse(current),
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 730)),
      // Always the portrait layout. On a laptop the picker chose its
      // landscape one, whose narrow side header cut the date to "٢٢ سبت…".
      builder: (context, child) {
        final size = MediaQuery.sizeOf(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(size.shortestSide, size.longestSide),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    final iso =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      if (start) {
        _startsOn = iso;
        // An end before the new start would be refused by the database.
        if (_endsOn != null && _endsOn!.compareTo(iso) < 0) _endsOn = iso;
      } else {
        _endsOn = iso;
        if (_startsOn != null && _startsOn!.compareTo(iso) > 0) _startsOn = iso;
      }
    });
  }

  Widget _segments<T>(
    List<(T, String)> options,
    T selected,
    ValueChanged<T> onChanged,
  ) {
    final colors = context.rabta;

    return SegmentedButton<T>(
      segments: [
        for (final (value, label) in options)
          ButtonSegment(value: value, label: Text(label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: colors.accentSoft,
        selectedForegroundColor: colors.accent,
        foregroundColor: colors.ink,
        side: BorderSide(color: colors.line),
        textStyle: Style.meta.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _chips(Iterable<(String, String)> items, Set<String> chosen) {
    final colors = context.rabta;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in items)
          FilterChip(
            label: Text(label, textDirection: directionOf(label)),
            selected: chosen.contains(id),
            onSelected: (on) =>
                setState(() => on ? chosen.add(id) : chosen.remove(id)),
            showCheckmark: false,
            labelStyle: Style.meta.copyWith(
              color: chosen.contains(id) ? colors.accent : colors.ink,
              fontWeight: chosen.contains(id)
                  ? FontWeight.w700
                  : FontWeight.w300,
            ),
            backgroundColor: colors.surface,
            selectedColor: colors.accentSoft,
            side: BorderSide(
              color: chosen.contains(id) ? colors.accent : colors.line,
            ),
          ),
      ],
    );
  }

  Widget _dateRow(
    String label,
    String? value,
    String empty, {
    required bool start,
  }) {
    final colors = context.rabta;
    final today = todayInAmman();

    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Style.preview.copyWith(color: colors.muted),
          ),
        ),
        TextButton(
          onPressed: () => _pickDate(start: start),
          child: Text(
            value == null ? empty : _day(value, today),
            style: Style.name.copyWith(color: colors.accent),
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: empty,
            icon: Icon(Icons.close, size: 16, color: colors.muted),
            onPressed: () =>
                setState(() => start ? _startsOn = null : _endsOn = null),
          ),
      ],
    );
  }

  Widget _form() {
    final colors = context.rabta;
    final l = context.l;
    final label = Style.name.copyWith(color: colors.ink);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _segments(
          [
            (OfferKind.percent, l.offerKindPercent),
            (OfferKind.amount, l.offerKindAmount),
            (OfferKind.buyGet, l.offerKindBuyGet),
            (OfferKind.text, l.offerKindText),
          ],
          _kind,
          (kind) => setState(() => _kind = kind),
        ),
        const SizedBox(height: 16),
        if (_kind == OfferKind.text)
          _Field(
            controller: _description,
            label: l.offerText,
            hint: l.offerTextHint,
            lines: 4,
          )
        else if (_kind == OfferKind.buyGet) ...[
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: _buy,
                  label: l.offerBuy,
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  controller: _get,
                  label: l.offerGet,
                  number: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.offerBuyGetHint,
            style: Style.meta.copyWith(color: colors.muted),
          ),
        ] else
          _Field(
            controller: _value,
            label: _kind == OfferKind.percent
                ? l.offerPercent
                : '${l.offerAmount} (${widget.currency})',
            number: true,
          ),
        const SizedBox(height: 20),
        Text(l.offerAppliesTo, style: label),
        if (_kind == OfferKind.text) ...[
          const SizedBox(height: 2),
          Text(l.offerTextScope, style: Style.meta.copyWith(color: colors.muted)),
        ],
        const SizedBox(height: 8),
        _segments(
          [
            (_Scope.shop, l.offerWholeShop),
            (_Scope.categories, l.offerCategories),
            (_Scope.products, l.offerProducts),
          ],
          _scope,
          (scope) => setState(() => _scope = scope),
        ),
        const SizedBox(height: 10),
        if (_scope == _Scope.categories)
          widget.categories.isEmpty
              ? Text(
                  l.offerNoCategories,
                  style: Style.meta.copyWith(color: colors.muted),
                )
              : _chips([
                  for (final c in widget.categories) (c.id, c.name),
                ], _categories),
        if (_scope == _Scope.products)
          _chips([for (final p in widget.products) (p.id!, p.code == null ? p.name : '${p.name} · ${p.code}')], _products),
        const SizedBox(height: 16),
        _dateRow(l.offerStarts, _startsOn, l.offerStartsNow, start: true),
        _dateRow(l.offerEnds, _endsOn, l.offerNoEnd, start: false),
        const SizedBox(height: 12),
        _Field(controller: _name, label: l.offerName, hint: l.offerNameHint),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final title = widget.offer == null ? l.offerAdd : l.offerEdit;
    final ready = _offer;

    final save = TextButton(
      // Read at the moment Save is pressed. Handing back the offer computed
      // at the last rebuild lost whatever was typed since — the name field
      // does not rebuild the dialog, so a name typed last was never saved.
      onPressed: ready == null ? null : () => Navigator.pop(context, _offer),
      child: Text(
        l.productSave,
        style: Style.name.copyWith(
          color: ready == null ? colors.muted : colors.accent,
        ),
      ),
    );

    if (widget.fullScreen) {
      return Dialog.fullscreen(
        backgroundColor: colors.surface,
        child: Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l.cancel,
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
            ),
            actions: [save, const SizedBox(width: 8)],
            shape: Border(bottom: BorderSide(color: colors.edge)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [_form()],
          ),
        ),
      );
    }

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(title, style: Style.heading.copyWith(color: colors.ink)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(child: _form()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l.cancel,
            style: Style.name.copyWith(color: colors.muted),
          ),
        ),
        save,
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.number = false,
    this.lines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool number;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      borderSide: BorderSide(color: color),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        textDirection: number ? TextDirection.ltr : directionOf(value.text),
        minLines: lines,
        maxLines: lines,
        style: Style.message.copyWith(color: colors.ink),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: lines > 1,
          labelStyle: Style.preview.copyWith(color: colors.muted),
          helperText: hint,
          // Room for the whole hint: the worded-offer one ends with "set the
          // dates below", and three lines cut exactly that off at phone width.
          helperMaxLines: 6,
          helperStyle: Style.meta.copyWith(color: colors.muted),
          filled: true,
          fillColor: colors.ground,
          border: border(colors.line),
          enabledBorder: border(colors.line),
          focusedBorder: border(colors.accent),
        ),
      ),
    );
  }
}
