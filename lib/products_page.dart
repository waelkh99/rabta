// What the seller sells, and whether the assistant may answer from it.
//
// Two things share this screen because they are one decision: an assistant
// with no catalog has nothing to say, and a catalog with the assistant off is
// a list nobody reads. Putting the switch above the list makes the dependency
// obvious without explaining it.
//
// Still deliberately plain: a name, a price, photos, an optional category, and
// one box of details in the seller's own words. No variants, no SKUs, no
// quantities. The product owner asked for the least typing for the seller
// "even if it puts extra load on the agent" — sizes and colours are written in
// the details and the assistant reads them, rather than being a grid of fields
// nobody fills in.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'files.dart';
import 'strings.dart';
import 'theme.dart';

/// The catalog and the assistant's settings, loaded together.
typedef _Catalog = ({
  List<Product> products,
  Shop shop,
  List<Category> categories,
  List<Offer> offers,
});

/// What the editor hands back: the product as typed, and its photos in the
/// seller's order, some of them not uploaded yet.
typedef _Edited = ({Product product, List<PhotoSlot> photos});

/// Below this the editor takes the whole screen. A dialog on a phone leaves a
/// strip of dimmed page around a form that is already cramped.
const _phoneWidth = 600.0;

/// Past this many products a seller scrolls to find one, so a search appears.
/// Below it, a search box is one more thing on the screen for no reason.
const _searchFrom = 12;

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

  /// The category chip that is selected. Null is "All".
  String? _category;

  String _query = '';

  Future<_Catalog> _load() async {
    final products = await widget.inbox.products();
    final shop = await widget.inbox.shop();
    final categories = await widget.inbox.categories();
    final offers = await widget.inbox.offers();
    return (
      products: products,
      shop: shop,
      categories: categories,
      offers: offers,
    );
  }

  void _reload() {
    if (mounted) setState(() { _catalog = _load(); });
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

  Future<void> _edit(Product? existing, _Catalog catalog) async {
    final phone = MediaQuery.sizeOf(context).width < _phoneWidth;

    final editor = _ProductDialog(
      product: existing,
      categories: catalog.categories,
      takenCodes: {
        for (final product in catalog.products)
          if (product.id != existing?.id && product.code != null) categoryKey(product.code!),
      },
      urlOf: widget.inbox.photoUrl,
      fullScreen: phone,
    );

    final edited = await showDialog<_Edited>(
      context: context,
      builder: (context) => editor,
    );

    if (edited == null || !mounted) return;

    setState(() => _working = existing?.id ?? '');

    try {
      await widget.inbox.saveProduct(
        edited.product,
        photos: edited.photos,
        previousPhotos: existing?.photos ?? const [],
      );
    } on CodeTaken {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.l.productCodeTaken),
            backgroundColor: context.rabta.urgent,
          ),
        );
      }
    } catch (error) {
      _complain(error);
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  void _download(_Catalog catalog) {
    final l = context.l;
    downloadCatalog(
      catalog.products,
      // The same order catalogWorkbook writes, and words the importer reads,
      // so the file goes straight back in.
      headers: [
        l.productCode,
        l.productName,
        l.productPrice,
        l.productDescription,
        l.productInStock,
        l.productCategory,
      ],
      yes: l.catalogYes,
      no: l.catalogNo,
    );
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
        title: Text(
          l.productDeleteTitle,
          style: Style.heading.copyWith(color: colors.ink),
        ),
        content: Text(
          l.productDeleteBody(product.name),
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

    if (confirmed != true || !mounted || product.id == null) return;

    setState(() => _working = product.id);

    try {
      await widget.inbox.deleteProduct(product);
    } catch (error) {
      _complain(error);
    } finally {
      if (mounted) setState(() => _working = null);
      _reload();
    }
  }

  Future<void> _editCategories(_Catalog catalog) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CategoriesDialog(
        inbox: widget.inbox,
        categories: catalog.categories,
        products: catalog.products,
      ),
    );

    // Whatever changed in there — a rename, a deletion — is read back rather
    // than patched into the list here.
    _reload();
  }

  Future<void> _paste() async {
    final sheet = await showDialog<CatalogSheet>(
      context: context,
      builder: (context) => const _ImportDialog(),
    );

    if (sheet == null || !mounted) return;

    final l = context.l;
    final colors = context.rabta;

    if (sheet.products.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(l.catalogPasteNothing),
          backgroundColor: colors.urgent,
        ),
      );
      return;
    }

    setState(() => _working = '');

    try {
      final result = await widget.inbox.importProducts(sheet);

      // Both numbers, so a seller who re-imported their sheet can see it
      // changed what they had rather than adding it all a second time.
      final message = [
        if (result.added > 0 || result.updated == 0) l.catalogPasteAdded(result.added),
        if (result.updated > 0) l.catalogUpdated(result.updated),
      ].join(' · ');

      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(message)));
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
        title: Text(
          l.products,
        ),
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
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: colors.muted,
                ),
              ),
            );
          }

          final catalog = snapshot.data!;
          final today = todayInAmman();

          // Only categories something is in. One typed once and never used
          // again would otherwise sit in the chips forever, filtering to
          // nothing.
          final used = {
            for (final product in catalog.products) product.categoryId,
          };
          final chips = catalog.categories
              .where((c) => used.contains(c.id))
              .toList();

          // A chip for a category that has since emptied selects nothing.
          final selected = chips.any((c) => c.id == _category)
              ? _category
              : null;

          final query = _query.trim().toLowerCase();
          final shown = catalog.products.where((product) {
            if (selected != null && product.categoryId != selected) {
              return false;
            }
            if (query.isEmpty) return true;
            return product.name.toLowerCase().contains(query) ||
                (product.code ?? '').toLowerCase().contains(query) ||
                (product.description ?? '').toLowerCase().contains(query);
          }).toList();

          // The same column width as the accounts screen. Left to stretch, a
          // row puts its name and its controls a thousand pixels apart.
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
                        l.productsBody,
                        style: Style.preview.copyWith(color: colors.muted),
                      ),
                      const SizedBox(height: 20),
                      if (catalog.products.length > _searchFrom) ...[
                        _SearchField(
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (catalog.categories.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (chips.isNotEmpty)
                              _Chip(
                                label: l.catalogAll,
                                selected: selected == null,
                                onTap: () => setState(() => _category = null),
                              ),
                            for (final category in chips)
                              _Chip(
                                label: category.name,
                                selected: selected == category.id,
                                onTap: () =>
                                    setState(() => _category = category.id),
                              ),
                            // Every category, used or not, is reached from
                            // here — including one typed once by mistake.
                            TextButton(
                              onPressed: _working != null
                                  ? null
                                  : () => _editCategories(catalog),
                              child: Text(
                                l.categoriesEdit,
                                style: Style.meta.copyWith(
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (catalog.products.isEmpty || shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(
                            catalog.products.isEmpty
                                ? l.productsEmpty
                                : l.catalogNoMatch,
                            style: Style.preview.copyWith(color: colors.muted),
                          ),
                        ),
                      if (shown.isNotEmpty)
                        Panel(children: [
                      for (final product in shown)
                        _ProductRow(
                          product: product,
                          currency: catalog.shop.currency,
                          sale: salePrice(product, catalog.offers, today),
                          cover: product.photos.isEmpty
                              ? null
                              : widget.inbox.photoUrl(
                                  thumbnailOf(product.photos.first),
                                ),
                          busy: _working == product.id,
                          onEdit: () => _edit(product, catalog),
                          onDelete: () => _delete(product),
                        ),
                        ]),
                      const SizedBox(height: 20),
                      // Wraps rather than overflowing: at phone width in English
                      // the three buttons ran 25px past the edge and the last
                      // was cut off. Arabic fitted only because its labels are
                      // shorter.
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Stamp(
                            enabled: _working == null,
                            child: FilledButton.icon(
                              onPressed: _working != null
                                  ? null
                                  : () => _edit(null, catalog),
                              style: FilledButton.styleFrom(
                                shape: const RoundedRectangleBorder(),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(l.productAdd),
                            ),
                          ),
                          // Only once there is something to download. Shown
                          // disabled it kept the accent colour and looked
                          // like a button that did nothing.
                          if (catalog.products.isNotEmpty)
                            TextButton(
                              onPressed: _working != null ? null : () => _download(catalog),
                              child: Text(
                                l.catalogDownload,
                                style: Style.name.copyWith(color: colors.accent),
                              ),
                            ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return TextField(
      onChanged: onChanged,
      style: Style.message.copyWith(color: colors.ink),
      decoration: InputDecoration(
        hintText: context.l.catalogSearch,
        hintStyle: Style.preview.copyWith(color: colors.muted),
        prefixIcon: Icon(Icons.search, size: 18, color: colors.muted),
        isDense: true,
        filled: true,
        fillColor: colors.surface,
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
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Material(
      color: selected ? colors.saffron : colors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.ink : colors.edge,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            textDirection: directionOf(label),
            style: Style.meta.copyWith(
              color: colors.ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// A square photo with rounded corners, or a quiet placeholder where there is
/// none. The placeholder is deliberately plain — an icon that looks like an
/// error would tell the seller something is wrong with a product that is fine.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.size, this.url, this.bytes});

  final double size;
  final String? url;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    final placeholder = Container(
      color: colors.ground,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: size * 0.42, color: colors.muted),
    );

    // A hairline edge: product photos are often shot on white, and without it
    // a white photo on a white page read as an empty row — seen with a perfume
    // bottle in the Playwright pass of 22 September.
    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: size,
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover)
              : url != null
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                )
              : placeholder,
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.currency,
    required this.sale,
    required this.cover,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final String currency;

  /// Today's price with the best running offer, or null. The same number the
  /// assistant quotes, so the seller sees what customers are being told.
  final double? sale;
  final String? cover;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    final separator = metaSeparator(context);
    final meta = [
      if (product.code != null) product.code!,
      if (product.category != null) product.category!,
      if (!product.inStock) l.productOutOfStock,
    ];

    final style = Style.meta.copyWith(
      color: product.inStock ? colors.muted : colors.urgent,
    );

    // The listed price struck through beside the sale price, the way a shop
    // tag shows it. Ink rather than accent: the accent is for the seller's own
    // actions, and this is a fact.
    final price = product.price == null
        ? null
        : sale == null
        ? TextSpan(
            text: formatPrice(product.price!, currency),
            style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
          )
        : TextSpan(
            children: [
              TextSpan(
                text: formatPrice(product.price!),
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              const TextSpan(text: ' '),
              TextSpan(
                text: formatPrice(sale!, currency),
                style: TextStyle(
                  color: colors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      child: Row(
        children: [
          _Thumb(size: 52, url: cover),
          const SizedBox(width: 14),
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
                if (price != null || meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        ?price,
                        if (price != null && meta.isNotEmpty)
                          TextSpan(text: separator),
                        if (meta.isNotEmpty) TextSpan(text: meta.join(separator)),
                      ],
                    ),
                    // Two lines, not one: at phone width a product on sale
                    // and out of stock had "out of stock" cut off the end.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onEdit,
            child: Text(
              l.productEdit,
              style: Style.meta.copyWith(
                color: busy ? colors.muted : colors.accent,
              ),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onDelete,
            child: Text(
              l.productDelete,
              style: Style.meta.copyWith(
                color: busy ? colors.muted : colors.urgent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renaming and deleting categories. They are made by typing one on a
/// product, so this is where a typo, or a shop reorganising, is put right.
class _CategoriesDialog extends StatefulWidget {
  const _CategoriesDialog({
    required this.inbox,
    required this.categories,
    required this.products,
  });

  final Inbox inbox;
  final List<Category> categories;
  final List<Product> products;

  @override
  State<_CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends State<_CategoriesDialog> {
  late final List<Category> _categories = List.of(widget.categories);
  String? _working;

  int _count(Category category) => widget.products
      .where((product) => product.categoryId == category.id)
      .length;

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.rabta.urgent),
    );
  }

  Future<void> _rename(Category category) async {
    final l = context.l;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameDialog(initial: category.name),
    );

    if (name == null || name == category.name || !mounted) return;

    setState(() => _working = category.id);
    try {
      await widget.inbox.renameCategory(category.id, name);
      final index = _categories.indexOf(category);
      if (mounted) {
        setState(
          () => _categories[index] = Category(id: category.id, name: name),
        );
      }
    } on CategoryTaken {
      if (mounted) _say(l.categoryTaken);
    } catch (_) {
      if (mounted) _say(l.catalogSaveFailed);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _delete(Category category) async {
    final l = context.l;
    final colors = context.rabta;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          l.categoryDeleteTitle(category.name),
          style: Style.heading.copyWith(color: colors.ink),
        ),
        content: Text(
          l.categoryDeleteBody,
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

    if (confirmed != true || !mounted) return;

    setState(() => _working = category.id);
    try {
      await widget.inbox.deleteCategory(category.id);
      if (mounted) setState(() => _categories.remove(category));
    } catch (_) {
      if (mounted) _say(l.catalogSaveFailed);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        l.categoriesTitle,
        style: Style.heading.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 400,
        child: _categories.isEmpty
            ? Text(
                l.categoriesEmpty,
                style: Style.preview.copyWith(color: colors.muted),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final category in _categories)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: directionOf(category.name),
                                  style: Style.name.copyWith(color: colors.ink),
                                ),
                                Text(
                                  l.categoryCount(_count(category)),
                                  style: Style.meta.copyWith(
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _working != null
                                ? null
                                : () => _rename(category),
                            child: Text(
                              l.categoryRename,
                              style: Style.meta.copyWith(color: colors.accent),
                            ),
                          ),
                          TextButton(
                            onPressed: _working != null
                                ? null
                                : () => _delete(category),
                            child: Text(
                              l.productDelete,
                              style: Style.meta.copyWith(color: colors.urgent),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.done, style: Style.name.copyWith(color: colors.accent)),
        ),
      ],
    );
  }
}

/// A new name for a category.
///
/// Its own widget so it owns its text controller. Created and disposed around
/// `showDialog` instead, the controller was disposed while the dialog was
/// still animating closed, and the whole screen went red — found renaming a
/// category in the Playwright pass of 22 September.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(l.categoryRename, style: Style.heading.copyWith(color: colors.ink)),
      content: SizedBox(
        width: 340,
        child: _Field(controller: _name, label: l.productCategory, autofocus: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: Style.name.copyWith(color: colors.muted)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, value, _) {
            final ready = value.text.trim().isNotEmpty;
            return TextButton(
              onPressed: ready ? () => Navigator.pop(context, value.text.trim()) : null,
              child: Text(
                l.productSave,
                style: Style.name.copyWith(color: ready ? colors.accent : colors.muted),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Adding or changing one product.
class _ProductDialog extends StatefulWidget {
  const _ProductDialog({
    this.product,
    required this.categories,
    required this.takenCodes,
    required this.urlOf,
    required this.fullScreen,
  });

  final Product? product;
  final List<Category> categories;

  /// Codes other products already have, compared the way the unique index
  /// compares them. Checked here, before the editor closes: found by the
  /// database instead, the seller lost everything they had typed and the
  /// photos had already been uploaded for nothing. The index is still there
  /// for the rare race.
  final Set<String> takenCodes;
  final String Function(String path) urlOf;
  final bool fullScreen;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _price = TextEditingController(
    text: widget.product?.price == null ? '' : _plain(widget.product!.price!),
  );
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late bool _inStock = widget.product?.inStock ?? true;
  late final _code = TextEditingController(text: widget.product?.code ?? '');

  /// Set by the Autocomplete once it has built its field. Its controller is
  /// the one that holds what the seller typed.
  TextEditingController? _category;

  late final List<PhotoSlot> _photos = [
    for (final path in widget.product?.photos ?? const <String>[])
      PhotoSlot.stored(path),
  ];

  bool _picking = false;

  /// 25000 rather than 25000.0, which is what a seller typed in the first place.
  static String _plain(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);

    final picked = await pickPhotos();
    if (!mounted) return;

    final room = maxPhotos - _photos.length;
    final kept = picked.photos.take(room).toList();

    setState(() {
      _picking = false;
      _photos.addAll(kept.map(PhotoSlot.picked));
    });

    final l = context.l;
    final message = picked.failed > 0
        ? l.productPhotosFailed
        : picked.photos.length > kept.length
        ? l.productPhotosFull
        : null;

    if (message != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final category = _category?.text.trim() ?? widget.product?.category ?? '';

    Navigator.pop<_Edited>(context, (
      product: Product(
        id: widget.product?.id,
        name: name,
        price: parsePrice(_price.text),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        inStock: _inStock,
        category: category.isEmpty ? null : category,
        code: _code.text.trim().isEmpty ? null : _code.text.trim(),
      ),
      photos: List.of(_photos),
    ));
  }

  Widget _photoStrip() {
    final colors = context.rabta;
    final l = context.l;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.productPhotos, style: Style.name.copyWith(color: colors.ink)),
        const SizedBox(height: 2),
        Text(
          l.productPhotosBody,
          style: Style.meta.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, slot) in _photos.indexed)
              _PhotoTile(
                key: ObjectKey(slot),
                cover: index == 0,
                url: slot.path == null
                    ? null
                    : widget.urlOf(thumbnailOf(slot.path!)),
                bytes: slot.picked?.thumbnail,
                // Tapping any photo but the cover moves it to the front. The
                // cover is the one thing about order that matters, so it is
                // the only reordering there is.
                onTap: index == 0
                    ? null
                    : () => setState(
                        () => _photos.insert(0, _photos.removeAt(index)),
                      ),
                onRemove: () => setState(() => _photos.removeAt(index)),
              ),
            if (_photos.length < maxPhotos)
              // No tooltip: the label is on the tile already, and a tooltip
              // made a screen reader say it twice.
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: _picking ? null : _pick,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.ground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.edge),
                    ),
                    alignment: Alignment.center,
                    child: _picking
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: colors.muted,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 20,
                                color: colors.accent,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.productPhotoAdd,
                                textAlign: TextAlign.center,
                                style: Style.meta.copyWith(
                                  color: colors.accent,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _categoryField() {
    final colors = context.rabta;
    final l = context.l;
    final names = [for (final category in widget.categories) category.name];

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.product?.category ?? ''),
      optionsBuilder: (value) {
        final typed = categoryKey(value.text);
        return names.where(
          (name) => typed.isEmpty || categoryKey(name).contains(typed),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _category = controller;
        return _Field(
          controller: controller,
          focusNode: focusNode,
          label: l.productCategory,
          hint: l.productCategoryHint,
        );
      },
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          color: colors.surface,
          elevation: 3,
          borderRadius: BorderRadius.circular(Radii.control),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 380),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              children: [
                for (final option in options)
                  InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        option,
                        textDirection: directionOf(option),
                        style: Style.preview.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final colors = context.rabta;
    final l = context.l;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoStrip(),
        const SizedBox(height: 18),
        _Field(
          controller: _name,
          label: l.productName,
          autofocus: widget.product == null,
        ),
        const SizedBox(height: 12),
        _Field(controller: _price, label: l.productPrice),
        const SizedBox(height: 12),
        _categoryField(),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _code,
          builder: (context, _, _) => _Field(
            controller: _code,
            label: l.productCode,
            hint: l.productCodeHint,
            error: _codeTaken ? l.productCodeTaken : null,
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          controller: _description,
          label: l.productDescription,
          hint: l.productDescriptionHint,
          lines: 5,
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          value: _inStock,
          onChanged: (value) => setState(() => _inStock = value),
          title: Text(
            l.productInStock,
            style: Style.preview.copyWith(color: colors.ink),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  bool get _codeTaken => widget.takenCodes.contains(categoryKey(_code.text));

  Widget _saveButton() {
    final colors = context.rabta;

    return ListenableBuilder(
      listenable: Listenable.merge([_name, _code]),
      builder: (context, _) {
        final ready = _name.text.trim().isNotEmpty && !_codeTaken;
        return TextButton(
          onPressed: ready ? _save : null,
          child: Text(
            context.l.productSave,
            style: Style.name.copyWith(color: ready ? colors.accent : colors.muted),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final title = widget.product == null ? l.productAdd : l.productEdit;

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
            actions: [_saveButton(), const SizedBox(width: 8)],
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
        width: 420,
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
        _saveButton(),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.cover,
    required this.url,
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  final bool cover;
  final String? url;
  final Uint8List? bytes;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    // Remove sits under the photo, not on it. On it — a small × in the corner
    // — its accessibility label overflowed the corner and covered the middle
    // of the photo, so with a screen reader on, clicking a photo to make it
    // the cover deleted it instead. Seen in the Playwright pass of
    // 22 September. Beside each other, the two cannot overlap however long
    // either label is.
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Semantics(
            button: onTap != null,
            label: cover ? l.productPhotoCover : l.productPhotoMakeCover,
            excludeSemantics: true,
            onTap: onTap,
            child: Tooltip(
              message: cover ? '' : l.productPhotoMakeCover,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    _Thumb(size: 72, url: url, bytes: bytes),
                    if (cover)
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            l.productPhotoCover,
                            textAlign: TextAlign.center,
                            style: Style.meta.copyWith(
                              color: colors.onAccent,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                l.productPhotoRemove,
                style: Style.meta.copyWith(color: colors.urgent, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bringing in a price list the seller already has: a file chosen from their
/// computer or phone, or rows copied straight out of an open sheet. Both end
/// as the same list of products, read the same way.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();

  bool _reading = false;
  String? _problem;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final l = context.l;
    setState(() {
      _reading = true;
      _problem = null;
    });

    try {
      final sheet = await pickCatalogFile();
      if (!mounted) return;
      if (sheet != null) {
        Navigator.pop(context, sheet);
        return;
      }
    } on SheetException catch (error) {
      _problem = switch (error.problem) {
        SheetProblem.oldExcel => l.catalogFileOldExcel,
        SheetProblem.unreadable => l.catalogFileUnreadable,
      };
    }

    if (mounted) setState(() => _reading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        l.catalogPaste,
        style: Style.heading.copyWith(color: colors.ink),
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.catalogPasteBody,
                style: Style.preview.copyWith(color: colors.muted, height: 1.6),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _reading ? null : _choose,
                icon: _reading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: colors.muted,
                        ),
                      )
                    : Icon(
                        Icons.upload_file_outlined,
                        size: 18,
                        color: colors.accent,
                      ),
                label: Text(
                  l.catalogFileChoose,
                  style: Style.name.copyWith(color: colors.accent),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.edge),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                ),
              ),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  _problem!,
                  style: Style.meta.copyWith(color: colors.urgent, height: 1.5),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                l.catalogFileOr,
                style: Style.name.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 8),
              _Field(controller: _text, label: l.catalogPasteHint, lines: 5),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: catalogTemplateCsv()));
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(content: Text(l.catalogTemplateCopied)),
                  );
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  l.catalogTemplateCopy,
                  style: Style.meta.copyWith(color: colors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l.cancel,
            style: Style.name.copyWith(color: colors.muted),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text,
          builder: (context, value, _) => TextButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, readCatalogCsv(_text.text)),
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
    this.focusNode,
    this.hint,
    this.error,
  });

  final TextEditingController controller;

  /// Said under the field in place of the hint, in the urgent colour.
  final String? error;
  final String label;
  final int lines;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Shown under the field all the time, not only once it has focus: it is
  /// what tells a seller what the field is for before they decide to use it.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        minLines: lines,
        maxLines: lines,
        // A product name is as likely to be Arabic as the interface is not.
        // Each field takes its direction from what is in it.
        textDirection: directionOf(value.text),
        style: Style.message.copyWith(color: colors.ink),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: lines > 1,
          labelStyle: Style.preview.copyWith(color: colors.muted),
          helperText: hint,
          errorText: error,
          errorMaxLines: 3,
          helperMaxLines: 3,
          helperStyle: Style.meta.copyWith(color: colors.muted),
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
