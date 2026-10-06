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
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/alerts_switch.dart';
import '../data.dart';
import '../widgets/locale_switch.dart';
import '../strings.dart';
import '../theme.dart';

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
    if (mounted) setState(() { _view = _load(); });
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
        title: Text(l.shop),
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
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
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

                      _Heading(l.shopPricing),
                      Text(
                        l.shopPricingBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      _Pricing(
                        stance: shop.priceStance,
                        enabled: !busy,
                        onChanged: (stance) =>
                            _save({"price_stance": stance.stored}),
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
                      const SizedBox(height: 40),

                      // Everything above this line is read by the assistant and
                      // can end up in front of a customer. Everything below is
                      // the seller's own, and never leaves this browser except
                      // the password. Worth separating plainly: they are the
                      // same kind of control and not the same kind of risk.
                      Divider(height: 1, color: colors.line),
                      const SizedBox(height: 24),
                      Text(
                        l.settingsYou,
                        style: Style.groupLabel.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: 20),

                      _Heading(l.settingsLanguage),
                      Text(
                        l.settingsLanguageBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: LocaleSwitch(),
                      ),
                      const SizedBox(height: 32),

                      _Heading(l.alerts),
                      Text(
                        l.alertsBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      const AlertsSwitch(),
                      const SizedBox(height: 32),

                      _Heading(l.password),
                      Text(
                        l.passwordBody,
                        style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                      ),
                      const SizedBox(height: 10),
                      const _PasswordRow(),
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

/// What the assistant does when a customer asks for a better price.
///
/// Two choices rather than a switch, because neither is an absence of the
/// other and a switch would make one of them read as "off". A seller picking
/// between them is choosing how their shop behaves, not enabling a feature.
///
/// The consequence is stated under each one, because the difference that
/// matters is not what the assistant says — it is whether these conversations
/// reach the seller at all.
class _Pricing extends StatelessWidget {
  const _Pricing({
    required this.stance,
    required this.enabled,
    required this.onChanged,
  });

  final PriceStance stance;
  final bool enabled;
  final ValueChanged<PriceStance> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Choice(
          label: l.shopPricingFinal,
          body: l.shopPricingFinalBody,
          selected: stance == PriceStance.strict,
          enabled: enabled,
          onTap: () => onChanged(PriceStance.strict),
        ),
        const SizedBox(height: 8),
        _Choice(
          label: l.shopPricingHandOver,
          body: l.shopPricingHandOverBody,
          selected: stance == PriceStance.notify,
          enabled: enabled,
          onTap: () => onChanged(PriceStance.notify),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.body,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String body;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: selected ? colors.raised : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colors.edge : colors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 17,
              color: selected ? colors.accent : colors.muted,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Style.name.copyWith(
                      color: selected ? colors.accent : colors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: Style.preview.copyWith(color: colors.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The password, as a row that opens a dialog rather than a form left open.
///
/// It was two fields sitting on the page. That reads as something to fill in
/// rather than something to decide to do, and it leaves a password box open
/// over a shoulder for as long as the screen is. Editing happens in a dialog
/// everywhere else in this application — a product, a delivery zone — and this
/// is the same shape of action.
class _PasswordRow extends StatelessWidget {
  const _PasswordRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 18, color: colors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              // Dots rather than the word "password" again: the row is under a
              // heading that already says it, and this says there is one.
              '••••••••',
              style: Style.name.copyWith(color: colors.muted, letterSpacing: 2),
            ),
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const _PasswordDialog(),
            ),
            child: Text(
              l.passwordChange,
              style: Style.name.copyWith(color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Current password, new, repeat.
///
/// The current one is asked for and checked. Supabase does not require it — the
/// session alone is enough — but this product's own reasoning says sellers work
/// on machines they share or did not configure, and a signed-in tab left open
/// should not hand somebody the account. It is verified by signing in with it,
/// which is the only way to ask Supabase "is this the password" without a
/// server function of our own.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l;
    final password = _password.text;

    // The same two rules the invitation screen applies, so a password that is
    // acceptable there cannot be refused here.
    if (!passwordStrongEnough(password)) {
      setState(() => _problem = l.passwordTooShort);
      return;
    }
    if (password != _repeat.text) {
      setState(() => _problem = l.passwordMismatch);
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
    });

    final auth = Supabase.instance.client.auth;
    final email = auth.currentUser?.email;

    try {
      // Checked before anything is changed. A wrong current password must not
      // leave the account altered.
      if (email != null) {
        await auth.signInWithPassword(email: email, password: _current.text);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = l.passwordWrong;
      });
      return;
    }

    try {
      await auth.updateUser(UserAttributes(password: password));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.passwordChanged)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = l.passwordFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        l.passwordChange,
        style: Style.heading.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Password(
              controller: _current,
              label: l.passwordCurrent,
              enabled: !_busy,
              autofocus: true,
              current: true,
            ),
            const SizedBox(height: 12),
            _Password(controller: _password, label: l.passwordNew, enabled: !_busy),
            const SizedBox(height: 12),
            _Password(controller: _repeat, label: l.passwordRepeat, enabled: !_busy),
            const SizedBox(height: 10),
            Text(
              _problem ?? l.passwordBody,
              style: Style.preview.copyWith(
                color: _problem == null ? colors.muted : colors.urgent,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l.cancel, style: Style.name.copyWith(color: colors.muted)),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(
            _busy ? l.passwordChanging : l.passwordChange,
            style: Style.name.copyWith(color: _busy ? colors.muted : colors.accent),
          ),
        ),
      ],
    );
  }
}

class _Password extends StatelessWidget {
  const _Password({
    required this.controller,
    required this.label,
    required this.enabled,
    this.autofocus = false,
    this.current = false,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool autofocus;

  /// The one the seller already has, so a password manager offers to fill it
  /// rather than offering to save it.
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: true,
      autofillHints: [
        current ? AutofillHints.password : AutofillHints.newPassword,
      ],
      style: Style.name.copyWith(color: colors.ink),
      decoration: InputDecoration(
        labelText: label,
        // Latin either way: a password is not translated, and an Arabic
        // interface must not flip the field one is typed into.
        hintTextDirection: TextDirection.ltr,
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
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: BorderSide(color: colors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: BorderSide(color: colors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
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
