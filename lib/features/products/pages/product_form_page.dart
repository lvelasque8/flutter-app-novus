import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../models/product.dart';
import '../providers/product_providers.dart';
import '../widgets/barcode_scanner_page.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.productId});

  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _minStock = TextEditingController(text: '0');
  final _nameFocus = FocusNode();
  bool _taxExempt = false;
  bool _loaded = false;
  bool _saving = false;
  int? _initialStock;
  Product? _product;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _sku.dispose();
    _barcode.dispose();
    _price.dispose();
    _cost.dispose();
    _stock.dispose();
    _minStock.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _fill(Product product) {
    if (_loaded) return;
    _loaded = true;
    _product = product;
    _initialStock = product.stock;
    _name.text = product.name;
    _category.text = product.category;
    _sku.text = product.sku;
    _barcode.text = product.barcode;
    _price.text = product.price.toStringAsFixed(2);
    _cost.text = product.cost.toStringAsFixed(2);
    _stock.text = product.stock.toString();
    _minStock.text = product.minStock.toString();
    _taxExempt = product.taxExempt;
  }

  Future<void> _save({bool andAnother = false}) async {
    final name = _name.text.trim();
    final price = Money.parse(_price.text);
    final category = _category.text.trim();
    var sku = _sku.text.trim();
    final barcode = _barcode.text.trim();

    if (name.isEmpty) {
      _show('Escribe el nombre del producto');
      return;
    }
    if (price <= 0) {
      _show('El precio debe ser mayor que cero');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(productRepositoryProvider);

    try {
      // El código de barras no se puede repetir.
      final sameBarcode = await repo.findByBarcodeOnly(
        barcode,
        excludeId: _product?.id,
      );
      if (sameBarcode != null) {
        _show(
          'Ya existe "${sameBarcode.name}" con ese código de barras',
        );
        return;
      }

      // Si el SKU está vacío se genera uno automático por categoría.
      if (sku.isEmpty) {
        sku = await repo.generateSku(category);
      } else {
        final sameSku = await repo.findBySku(
          sku,
          excludeId: _product?.id,
        );
        if (sameSku != null) {
          _show('Ya existe "${sameSku.name}" con ese SKU');
          return;
        }
      }

      if (widget.isEditing && _product != null) {
        final updated = _product!.copyWith(
          name: name,
          category: category,
          sku: sku,
          barcode: barcode,
          price: price,
          cost: Money.parse(_cost.text),
          minStock: Money.parseInt(_minStock.text),
          taxExempt: _taxExempt,
          updatedAt: DateTime.now(),
        );
        await repo.update(updated);

        final newStock = Money.parseInt(_stock.text);
        if (_initialStock != null && newStock != _initialStock) {
          await repo.adjustStock(
            updated.id,
            newStock,
            reason: 'Ajuste desde edición de producto',
          );
        }
      } else {
        await repo.create(
          name: name,
          category: category,
          sku: sku,
          barcode: barcode,
          price: price,
          cost: Money.parse(_cost.text),
          stock: Money.parseInt(_stock.text),
          minStock: Money.parseInt(_minStock.text),
          taxExempt: _taxExempt,
        );
      }

      ref.invalidate(productsProvider);
      ref.invalidate(activeProductsProvider);
      ref.invalidate(productCategoriesProvider);
      ref.invalidate(dashboardProvider);

      if (!mounted) return;

      if (andAnother && !widget.isEditing) {
        _resetForNext();
        _show('Guardado. Listo para el siguiente producto.');
      } else {
        _show('Producto guardado');
        context.pop();
      }
    } catch (error) {
      if (mounted) _show('No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForNext() {
    setState(() {
      _name.clear();
      _sku.clear();
      _barcode.clear();
      _price.clear();
      _cost.clear();
      _stock.text = '0';
      _minStock.text = '0';
      _taxExempt = false;
    });
    _nameFocus.requestFocus();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Eliminar "${_product?.name ?? ''}" del inventario? '
          'Las ventas anteriores se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || _product == null) return;

    await ref.read(productRepositoryProvider).deactivate(_product!.id);
    ref.invalidate(productsProvider);
    ref.invalidate(activeProductsProvider);
    if (mounted) context.pop();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    setState(() => _barcode.text = code);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return _buildScaffold(null);
    }

    final product = ref.watch(productByIdProvider(widget.productId!));
    return product.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (value) {
        if (value == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Producto no encontrado')),
          );
        }
        _fill(value);
        return _buildScaffold(value);
      },
    );
  }

  Widget _buildScaffold(Product? product) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Editar producto' : 'Nuevo producto',
        ),
        centerTitle: false,
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText(
                      'Información del producto',
                      variant: AppTextVariant.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Nombre *',
                      hint: 'Ej: Harina PAN 1 kg',
                      controller: _name,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Categoría',
                            hint: 'Ej: Alimentos',
                            controller: _category,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Código / SKU',
                            hint: 'Opcional',
                            helperText: 'Se genera automático si lo dejas vacío',
                            controller: _sku,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _CategoryChips(
                      selected: _category.text,
                      onSelected: (value) =>
                          setState(() => _category.text = value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: 'Código de barras',
                      hint: 'Escanea o escribe el código',
                      controller: _barcode,
                      keyboardType: TextInputType.number,
                      suffix: IconButton(
                        tooltip: 'Escanear código de barras',
                        onPressed: _scanBarcode,
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const AppText(
                      'Precios e inventario',
                      variant: AppTextVariant.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Precio de venta (USD) *',
                            hint: '0,00',
                            controller: _price,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Costo (USD)',
                            hint: '0,00',
                            controller: _cost,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Stock actual',
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppTextField(
                            label: 'Stock mínimo',
                            helperText: 'Te avisaremos cuando baje',
                            controller: _minStock,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _taxExempt,
                      onChanged: (value) =>
                          setState(() => _taxExempt = value),
                      title: const Text('Producto exento de IVA'),
                      subtitle: const Text(
                        'No se le calcula IVA al venderlo',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  widget.isEditing ? 'Guardar cambios' : 'Agregar producto',
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
              if (!widget.isEditing) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    'Guardar y agregar otro',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.playlist_add,
                    loading: _saving,
                    onPressed:
                        _saving ? null : () => _save(andAnother: true),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atajos de categorías para no escribirla cada vez.
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(productCategoriesProvider);

    return categories.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Categorías rápidas',
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final category in items)
                  ChoiceChip(
                    label: Text(category),
                    selected: selected.trim().toLowerCase() ==
                        category.toLowerCase(),
                    onSelected: (_) => onSelected(category),
                  ),
              ],
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
