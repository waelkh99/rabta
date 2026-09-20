// What the seller sells, and whether the assistant may answer from it.
//
// Two things share this screen because they are one decision: an assistant
// with no catalog has nothing to say, and a catalog with the assistant off is
// a list nobody reads. Putting the switch above the list makes the dependency
// obvious without explaining it.
//
// The list is deliberately plain — name, price, in stock. No variants, no
// SKUs, no quantities, no pictures. CLAUDE.md rules those out, and a catalog
// that grows into stock control stops being something a seller will keep up
// to date.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'strings.dart';
import 'theme.dart';

/// The catalog and the assistant's settings, loaded together.
typedef _Catalog = ({List<Product> products, Shop shop});

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late Future<_Catalog> _catalog = _load();

  /// The id of the row being worked on, not a screen-wide flag: a seller
  /// deleting one product should not see every other row go dead.
  String? _working;

  Future<_Catalog> _load() async {
    final products = await widget.inbox.products();
    final shop = await widget.inbox.shop();
    return (products: products, shop: shop);
  }

  void _reload() {
    if (mounted) setState(() => _catalog = _load());
  }

  void _complain(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(context.l.catalogSaveFailed),
        backgroundColor: context.rabta.urgent,
      ),
    );
  }

  Future<void> _edit(Product? existing) async {
    final edited = await showDialog<Product>(
      context: context,
      builder: (context) => _ProductDialog(product: existing),
    );

    if (edited == null || !mounted) return;

    setState(() => _working = existing?.id ?? '');

    try {
      await widget.inbox.saveProduct(edited);
    } catch (error) {
      _complain(error);
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  Future<void> _delete(Product product) async {
    final l = context.l;
    final colors = context.rabta;

    // Asked first. A catalog is typed in by hand and a mis-tap costs the
    // seller work they will not enjoy repeating.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l.productDeleteTitle, style: Style.heading.copyWith(color: colors.ink)),
        content: Text(
          l.productDeleteBody(product.name),
          style: Style.preview.copyWith(color: colors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: Style.name.copyWith(color: colors.muted)),
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

    if (confirmed != true || !mounted || product.id == null) return;

    setState(() => _working = product.id);

    try {
      await widget.inbox.deleteProduct(product.id!);
    } catch (error) {
      _complain(error);
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  Future<void> _paste() async {
    final pasted = await showDialog<String>(
      context: context,
      builder: (context) => const _PasteDialog(),
    );

    if (pasted == null || !mounted) return;

    final products = parseCatalogCsv(pasted);
    final l = context.l;
    final colors = context.rabta;

    if (products.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l.catalogPasteNothing), backgroundColor: colors.urgent),
      );
      return;
    }

    setState(() => _working = '');

    try {
      final added = await widget.inbox.importProducts(products);

      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l.catalogPasteAdded(added))),
        );
      }
    } catch (error) {
      _complain(error);
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
        title: Text(l.products, style: Style.heading.copyWith(color: colors.ink)),
        iconTheme: IconThemeData(color: colors.ink),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: FutureBuilder<_Catalog>(
        future: _catalog,
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

          final catalog = snapshot.data!;

          // The same column width as the accounts screen. Left to stretch, a
          // row puts its name and its controls a thousand pixels apart.
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
                      Text(
                        l.productsBody,
                        style: Style.preview.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: 24),
                      if (catalog.products.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            l.productsEmpty,
                            style: Style.preview.copyWith(color: colors.muted),
                          ),
                        ),
                      for (final product in catalog.products)
                        _ProductRow(
                          product: product,
                          currency: catalog.shop.currency,
                          busy: _working == product.id,
                          onEdit: () => _edit(product),
                          onDelete: () => _delete(product),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: _working != null ? null : () => _edit(null),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: colors.onAccent,
                              disabledBackgroundColor: colors.accentSoft,
                              disabledForegroundColor: colors.muted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(l.productAdd, style: Style.name),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: _working != null ? null : _paste,
                            child: Text(
                              l.catalogPaste,
                              style: Style.name.copyWith(color: colors.accent),
                            ),
                          ),
                        ],
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

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.currency,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final String currency;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Style.name.copyWith(color: colors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: directionOf(product.name),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (product.price != null)
                      formatPrice(product.price!, currency),
                    if (!product.inStock) l.productOutOfStock,
                  ].join(' · '),
                  style: Style.meta.copyWith(
                    color: product.inStock ? colors.muted : colors.urgent,
                  ),
                ),
              ],
            ),
          ),
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

/// Adding or changing one product.
class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product});

  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(
    text: widget.product?.price == null ? '' : _plain(widget.product!.price!),
  );
  late final _description =
      TextEditingController(text: widget.product?.description ?? '');
  late bool _inStock = widget.product?.inStock ?? true;

  /// 25000 rather than 25000.0, which is what a seller typed in the first place.
  static String _plain(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(
      context,
      Product(
        id: widget.product?.id,
        name: name,
        price: parsePrice(_price.text),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        inStock: _inStock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        widget.product == null ? l.productAdd : l.productEdit,
        style: Style.heading.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(controller: _name, label: l.productName, autofocus: true),
            const SizedBox(height: 12),
            _Field(controller: _price, label: l.productPrice),
            const SizedBox(height: 12),
            _Field(controller: _description, label: l.productDescription, lines: 2),
            const SizedBox(height: 4),
            SwitchListTile(
              value: _inStock,
              onChanged: (value) => setState(() => _inStock = value),
              title: Text(l.productInStock, style: Style.preview.copyWith(color: colors.ink)),
              activeThumbColor: colors.onAccent,
              activeTrackColor: colors.accent,
              contentPadding: EdgeInsets.zero,
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
            onPressed: value.text.trim().isEmpty ? null : _save,
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

/// Pasting a price list straight out of a spreadsheet.
class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(l.catalogPaste, style: Style.heading.copyWith(color: colors.ink)),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.catalogPasteBody,
              style: Style.preview.copyWith(color: colors.muted, height: 1.6),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: catalogTemplateCsv()));
                ScaffoldMessenger.maybeOf(context)
                    ?.showSnackBar(SnackBar(content: Text(l.catalogTemplateCopied)));
              },
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                l.catalogTemplateCopy,
                style: Style.meta.copyWith(color: colors.accent),
              ),
            ),
            const SizedBox(height: 8),
            _Field(controller: _text, label: l.catalogPasteHint, lines: 6, autofocus: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: Style.name.copyWith(color: colors.muted)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (context, value, _) => TextButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _text.text),
            child: Text(
              l.catalogPasteAdd,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.lines = 1,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final int lines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: lines,
        maxLines: lines,
        // A product name is as likely to be Arabic as the interface is not.
        // Each field takes its direction from what is in it.
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
