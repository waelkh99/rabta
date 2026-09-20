// The shop itself, and whether the assistant may speak for it.
//
// A catalog answers "how much is the red dress". Half of what a customer
// actually asks is delivery, hours and where you are — and an assistant that
// hands all of those back reads as broken rather than careful. This is where
// the seller writes them down once.
//
// The assistant's own switch lives here rather than with the products, because
// what it can say is decided by this page more than by the catalog. Everything
// on it is optional: a shop that fills in nothing still gets answers about its
// products.

import 'package:flutter/material.dart';

import 'data.dart';
import 'strings.dart';
import 'theme.dart';

typedef _ShopView = ({Shop shop, List<DeliveryZone> zones, int products});

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late Future<_ShopView> _view = _load();
  String? _working;

  Future<_ShopView> _load() async {
    final shop = await widget.inbox.shop();
    final zones = await widget.inbox.deliveryZones();
    final products = await widget.inbox.products();
    return (shop: shop, zones: zones, products: products.length);
  }

  void _reload() {
    if (mounted) setState(() => _view = _load());
  }

  void _complain() {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l.catalogSaveFailed),
        backgroundColor: context.rabta.urgent,
      ),
    );
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    setState(() => _working = "shop");

    try {
      await widget.inbox.updateShop(changes);
    } catch (_) {
      _complain();
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  Future<void> _editZone(DeliveryZone? existing, String currency) async {
    final edited = await showDialog<DeliveryZone>(
      context: context,
      builder: (context) => _ZoneDialog(zone: existing, currency: currency),
    );

    if (edited == null || !mounted) return;

    setState(() => _working = existing?.id ?? 'new');

    try {
      await widget.inbox.saveDeliveryZone(edited);
    } catch (_) {
      _complain();
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  Future<void> _deleteZone(DeliveryZone zone) async {
    if (zone.id == null) return;

    setState(() => _working = zone.id);

    try {
      await widget.inbox.deleteDeliveryZone(zone.id!);
    } catch (_) {
      _complain();
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        elevation: 0,
        title: Text(l.shop, style: Style.heading.copyWith(color: colors.ink)),
        iconTheme: IconThemeData(color: colors.ink),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: FutureBuilder<_ShopView>(
        future: _view,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Notice(title: l.catalogFailed, body: l.catalogFailedBody);
          }

          if (!snapshot.hasData) {
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: colors.muted),
              ),
            );
          }

          final view = snapshot.data!;
          final shop = view.shop;
          final busy = _working != null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AssistantCard(
                        shop: shop,
                        hasProducts: view.products > 0,
                        busy: busy,
                        onChanged: _save,
                      ),
                      const SizedBox(height: 32),

                      _Heading(l.shopCurrency),
                      Text(
                        l.shopCurrencyBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      _SavedField(
                        value: shop.currency,
                        label: l.shopCurrency,
                        enabled: !busy,
                        onSaved: (value) =>
                            _save({"currency": value.trim().isEmpty ? "د.ا" : value.trim()}),
                      ),
                      const SizedBox(height: 32),

                      _Heading(l.shopDelivery),
                      Text(
                        l.shopDeliveryBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 14),
                      for (final zone in view.zones)
                        _ZoneRow(
                          zone: zone,
                          currency: shop.currency,
                          busy: _working == zone.id,
                          onEdit: () => _editZone(zone, shop.currency),
                          onDelete: () => _deleteZone(zone),
                        ),
                      if (view.zones.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            l.shopDeliveryEmpty,
                            style: Style.preview.copyWith(color: colors.muted),
                          ),
                        ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          onPressed: busy ? null : () => _editZone(null, shop.currency),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: Text(
                            l.shopZoneAdd,
                            style: Style.name.copyWith(color: colors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SavedField(
                        value: shop.deliveryNote ?? '',
                        label: l.shopDeliveryNote,
                        hint: l.shopDeliveryNoteHint,
                        lines: 2,
                        enabled: !busy,
                        onSaved: (value) => _save({"delivery_note": Inbox.textOrNull(value)}),
                      ),
                      const SizedBox(height: 32),

                      _Heading(l.shopLocations),
                      _SavedField(
                        value: shop.locations ?? '',
                        label: l.shopLocations,
                        hint: l.shopLocationsHint,
                        lines: 3,
                        enabled: !busy,
                        onSaved: (value) => _save({"locations": Inbox.textOrNull(value)}),
                      ),
                      const SizedBox(height: 24),

                      _Heading(l.shopHours),
                      _SavedField(
                        value: shop.hours ?? '',
                        label: l.shopHours,
                        hint: l.shopHoursHint,
                        lines: 2,
                        enabled: !busy,
                        onSaved: (value) => _save({"hours": Inbox.textOrNull(value)}),
                      ),
                      const SizedBox(height: 24),

                      _Heading(l.shopAbout),
                      Text(
                        l.shopAboutBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      _SavedField(
                        value: shop.about ?? '',
                        label: l.shopAbout,
                        hint: l.shopAboutHint,
                        lines: 5,
                        enabled: !busy,
                        onSaved: (value) => _save({"about": Inbox.textOrNull(value)}),
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

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: Style.name.copyWith(color: context.rabta.ink),
        ),
      );
}

/// Whether the assistant answers, and how freely.
class _AssistantCard extends StatelessWidget {
  const _AssistantCard({
    required this.shop,
    required this.hasProducts,
    required this.busy,
    required this.onChanged,
  });

  final Shop shop;
  final bool hasProducts;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    // An assistant with nothing to read would answer every question by handing
    // it back, which looks broken rather than careful. Saying so is better
    // than letting them switch it on and wonder.
    final blocked = !hasProducts && !shop.assistantEnabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.assistantTitle,
                  style: Style.name.copyWith(color: colors.ink),
                ),
              ),
              Switch(
                value: shop.assistantEnabled,
                activeThumbColor: colors.onAccent,
                activeTrackColor: colors.assistant,
                onChanged: busy || blocked
                    ? null
                    : (on) => onChanged({"assistant_enabled": on}),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            blocked ? l.assistantNeedsCatalog : l.assistantBody,
            style: Style.preview.copyWith(color: colors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.currency,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final DeliveryZone zone;
  final String currency;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              zone.name,
              style: Style.name.copyWith(color: colors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: directionOf(zone.name),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            // No fee is not free. It says the shop covers that place but the
            // price depends, which is what the assistant will tell a customer.
            zone.fee == null ? l.shopZoneNoFee : formatPrice(zone.fee!, currency),
            style: Style.meta.copyWith(
              color: zone.fee == null ? colors.muted : colors.ink,
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: busy ? null : onEdit,
            child: Text(
              l.productEdit,
              style: Style.meta.copyWith(color: busy ? colors.muted : colors.accent),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onDelete,
            child: Text(
              l.productDelete,
              style: Style.meta.copyWith(color: busy ? colors.muted : colors.urgent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneDialog extends StatefulWidget {
  const _ZoneDialog({this.zone, required this.currency});

  final DeliveryZone? zone;
  final String currency;

  @override
  State<_ZoneDialog> createState() => _ZoneDialogState();
}

class _ZoneDialogState extends State<_ZoneDialog> {
  late final _name = TextEditingController(text: widget.zone?.name ?? '');
  late final _fee = TextEditingController(
    text: widget.zone?.fee == null ? '' : _plain(widget.zone!.fee!),
  );

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        widget.zone == null ? l.shopZoneAdd : l.productEdit,
        style: Style.heading.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Field(controller: _name, label: l.shopZoneName, autofocus: true),
            const SizedBox(height: 12),
            _Field(controller: _fee, label: '${l.shopZoneFee} (${widget.currency})'),
            const SizedBox(height: 8),
            Text(
              l.shopZoneFeeHint,
              style: Style.meta.copyWith(color: colors.muted, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: Style.name.copyWith(color: colors.muted)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, _) => TextButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                      context,
                      DeliveryZone(
                        id: widget.zone?.id,
                        name: _name.text.trim(),
                        fee: parsePrice(_fee.text),
                      ),
                    ),
            child: Text(
              l.productSave,
              style: Style.name.copyWith(
                color: value.text.trim().isEmpty ? colors.muted : colors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A text field that saves when the seller leaves it.
///
/// No Save button per box. There are six of them on this screen and a row of
/// buttons would make writing down a phone number feel like filing a form.
class _SavedField extends StatefulWidget {
  const _SavedField({
    required this.value,
    required this.label,
    required this.onSaved,
    this.hint,
    this.lines = 1,
    this.enabled = true,
  });

  final String value;
  final String label;
  final String? hint;
  final int lines;
  final bool enabled;
  final ValueChanged<String> onSaved;

  @override
  State<_SavedField> createState() => _SavedFieldState();
}

class _SavedFieldState extends State<_SavedField> {
  late final _controller = TextEditingController(text: widget.value);
  late final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) return;

      final typed = _controller.text.trim();
      if (typed != widget.value.trim()) widget.onSaved(typed);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          controller: _controller,
          focusNode: _focus,
          label: widget.label,
          lines: widget.lines,
          enabled: widget.enabled,
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.hint!,
            style: Style.meta.copyWith(color: colors.muted, height: 1.5),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.focusNode,
    this.lines = 1,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final int lines;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        enabled: enabled,
        minLines: lines,
        maxLines: lines,
        // Each field takes its direction from what is in it: an address is as
        // likely to be Arabic as the interface is not.
        textDirection: directionOf(value.text),
        style: Style.message.copyWith(color: colors.ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: Style.preview.copyWith(color: colors.muted),
          filled: true,
          fillColor: colors.ground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.accent),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Style.heading.copyWith(color: colors.ink)),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Style.preview.copyWith(color: colors.muted, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
