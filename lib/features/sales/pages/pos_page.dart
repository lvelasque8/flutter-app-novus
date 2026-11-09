import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_search_field.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../accounts/providers/account_providers.dart';
import '../../accounts/widgets/customer_picker_dialog.dart';
import '../../cash/providers/cash_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../documents/data/thermal_printer_service.dart';
import '../../documents/receipt_pdf.dart';
import '../../products/models/product.dart';
import '../../products/providers/product_providers.dart';
import '../../products/widgets/barcode_scanner_page.dart';
import '../../settings/models/business_settings.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/sale_repository.dart';
import '../models/sale.dart';
import '../providers/cart_provider.dart';
import '../providers/sale_providers.dart';
import '../widgets/payment_dialog.dart';

class POSPage extends ConsumerStatefulWidget {
  const POSPage({super.key});

  @override
  ConsumerState<POSPage> createState() => _POSPageState();
}

class _POSPageState extends ConsumerState<POSPage> {
  final _search = TextEditingController();
  String _query = '';
  bool _processing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addProduct(Product product) async {
    final cart = ref.read(cartProvider);
    final index = cart.lines.indexWhere(
      (line) => line.product.id == product.id,
    );
    final line = index == -1 ? null : cart.lines[index];

    if (line != null && line.quantity >= product.stock) {
      _show('No hay más stock de ${product.name}');
      return;
    }

    ref.read(cartProvider.notifier).add(product);
  }

  Future<void> _onSubmitted(String value) async {
    if (value.trim().isEmpty) return;
    final product =
        await ref.read(productRepositoryProvider).findByBarcode(value.trim());
    if (product == null) {
      _show('No se encontró un producto con ese código');
      return;
    }
    await _addProduct(product);
    _search.clear();
    setState(() => _query = '');
  }

  Future<void> _scanAndAdd() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;

    final product = await ref
        .read(productRepositoryProvider)
        .findByBarcode(code.trim());
    if (!mounted) return;
    if (product == null) {
      _show('No hay un producto con el código $code');
      return;
    }

    await _addProduct(product);
    if (mounted) _show('${product.name} agregado al carrito');
  }

  Future<void> _checkout(BusinessSettings settings) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final total = cart.total(settings.ivaRate);
    final selection = await showPaymentDialog(
      context,
      total: total,
      rate: settings.rateBs,
      customer: cart.customer,
    );
    if (selection == null || !mounted) return;

    setState(() => _processing = true);
    try {
      final sale = await ref.read(saleRepositoryProvider).createSale(
            lines: cart.lines
                .map(
                  (line) => SaleLineInput(
                    productId: line.product.id,
                    name: line.product.name,
                    price: line.product.price,
                    unitCost: line.product.cost,
                    quantity: line.quantity,
                    taxExempt: line.product.taxExempt,
                  ),
                )
                .toList(),
            payments: selection.lines
                .map(
                  (line) => PaymentInput(
                    method: line.method,
                    amount: line.amount,
                    reference:
                        line.reference.isEmpty ? null : line.reference,
                  ),
                )
                .toList(),
            discount: cart.discount,
            ivaRate: settings.ivaRate,
            rateBs: settings.rateBs,
            customerId: selection.customer?.id ?? cart.customer?.id,
            customerName:
                selection.customer?.name ?? cart.customer?.name,
          );

      ref.read(cartProvider.notifier).clear();
      ref.invalidate(activeProductsProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(salesProvider);
      ref.invalidate(todayTotalProvider);
      ref.invalidate(todayCountProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(receivableTotalProvider);
      ref.invalidate(openAccountsCountProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(cashSummaryProvider);

      if (!mounted) return;
      await _showSaleDone(sale, settings);
    } catch (error) {
      if (mounted) {
        _show(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _showSaleDone(Sale sale, BusinessSettings settings) async {
    final printer = await ThermalPrinterService().load();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Venta ${sale.number} registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total: ${Money.usd(sale.total)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (sale.rate > 0)
              Text('Equivalente: ${Money.bs(sale.totalBs)}'),
            if (sale.payments.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Pagos:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              ...sale.payments.map(
                (payment) => Text(
                  '${PaymentMethods.label(payment.method)}: '
                  '${Money.usd(payment.amount)}',
                ),
              ),
            ],
            if (sale.isCredit) ...[
              const SizedBox(height: 8),
              Text(
                'Fiado a ${sale.customerName ?? 'cliente'}: '
                '${Money.usd(sale.payments.where((p) => PaymentMethods.isCredit(p.method)).fold<double>(0, (sum, p) => sum + p.amount))}. '
                'Quedó registrado en cuentas por cobrar.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (printer.isConfigured)
            AppButton(
              'Imprimir ticket',
              icon: Icons.print_outlined,
              onPressed: () async {
                Navigator.pop(context);
                await _printThermal(sale, settings, printer);
              },
            ),
          AppButton(
            'Nota PDF',
            icon: Icons.picture_as_pdf_outlined,
            onPressed: () async {
              Navigator.pop(context);
              await printSaleReceipt(sale: sale, settings: settings);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _printThermal(
    Sale sale,
    BusinessSettings settings,
    PrinterSettings printer,
  ) async {
    try {
      await ThermalPrinterService().printSale(
        sale: sale,
        settings: settings,
        printer: printer,
      );
      if (mounted) _show('Ticket impreso');
    } catch (error) {
      if (mounted) {
        _show(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _pickCustomer() async {
    final customer = await showCustomerPicker(context);
    if (customer != null) {
      ref.read(cartProvider.notifier).setCustomer(customer);
    }
  }

  Future<void> _editDiscount(BusinessSettings settings) async {
    final cart = ref.read(cartProvider);
    final controller = TextEditingController(
      text: cart.discount > 0 ? cart.discount.toStringAsFixed(2) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descuento'),
        content: AppTextField(
          label: 'Monto en dólares',
          hint: '0,00',
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          AppButton(
            'Aplicar',
            onPressed: () =>
                Navigator.pop(context, Money.parse(controller.text)),
          ),
        ],
      ),
    );

    if (result != null) {
      ref.read(cartProvider.notifier).setDiscount(result);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(activeProductsProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final cart = ref.watch(cartProvider);
    final settings =
        settingsAsync.valueOrNull ?? BusinessSettings.initial();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final catalog = _buildCatalog(
          products,
          settings,
          bottomPadding: wide ? AppSpacing.lg : 100,
        );

        if (wide) {
          return Row(
            children: [
              Expanded(child: catalog),
              Container(
                width: 390,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  border: Border(
                    left: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                child: _CartPanel(
                  settings: settings,
                  source: 'side',
                  processing: _processing,
                  onCheckout: () => _checkout(settings),
                  onPickCustomer: _pickCustomer,
                  onEditDiscount: () => _editDiscount(settings),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            catalog,
            if (cart.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                '${cart.itemCount} artículos',
                                variant: AppTextVariant.caption,
                                color: AppColors.textSecondary,
                              ),
                              AppText(
                                Money.usd(cart.total(settings.ivaRate)),
                                variant: AppTextVariant.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          'Ver carrito',
                          icon: Icons.shopping_cart_outlined,
                          onPressed: () => _openCartSheet(settings),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openCartSheet(BusinessSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: _CartPanel(
          settings: settings,
          source: 'sheet',
          processing: _processing,
          onCheckout: () {
            Navigator.pop(context);
            _checkout(settings);
          },
          onPickCustomer: _pickCustomer,
          onEditDiscount: () => _editDiscount(settings),
        ),
      ),
    );
  }

  Widget _buildCatalog(
    AsyncValue<List<Product>> products,
    BusinessSettings settings, {
    required double bottomPadding,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: AppSearchField(
            controller: _search,
            hint: 'Buscar producto o escanear código...',
            onChanged: (value) => setState(() => _query = value),
            onSubmitted: _onSubmitted,
            trailing: IconButton(
              tooltip: 'Escanear código de barras',
              onPressed: _scanAndAdd,
              icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            ),
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('No se pudo cargar el catálogo: $error'),
            ),
            data: (items) {
              final filtered = _filter(items);
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 56,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppText(
                        _query.isEmpty
                            ? 'No hay productos disponibles'
                            : 'No encontramos ese producto',
                        variant: AppTextVariant.titleMedium,
                        color: AppColors.textSecondary,
                      ),
                      if (_query.isEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const AppText(
                          'Agrega productos desde Inventario para vender.',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textHint,
                        ),
                      ],
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      (constraints.maxWidth / 190).floor().clamp(2, 6);
                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      bottomPadding,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final product = filtered[index];
                      return _ProductButton(
                        product: product,
                        rate: settings.rateBs,
                        onTap: () => _addProduct(product),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<Product> _filter(List<Product> products) {
    if (_query.trim().isEmpty) return products;
    final query = _query.toLowerCase();
    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.barcode.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
  }
}

class _ProductButton extends StatelessWidget {
  const _ProductButton({
    required this.product,
    required this.rate,
    required this.onTap,
  });

  final Product product;
  final double rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = product.stock > 0;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: available ? AppColors.outlineVariant : AppColors.gray200,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      product.name,
                      variant: AppTextVariant.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (product.lowStock)
                    const AppBadge(
                      'Bajo',
                      variant: AppBadgeVariant.warning,
                      size: AppBadgeSize.small,
                    ),
                ],
              ),
              const Spacer(),
              AppText(
                Money.usd(product.price),
                variant: AppTextVariant.titleLarge,
                color: available ? AppColors.primary : AppColors.textHint,
              ),
              if (rate > 0)
                AppText(
                  Money.bs(product.price * rate),
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondary,
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    available
                        ? Icons.inventory_2_outlined
                        : Icons.block_outlined,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  AppText(
                    available ? '${product.stock} disponibles' : 'Agotado',
                    variant: AppTextVariant.caption,
                    color: available
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({
    required this.settings,
    required this.source,
    required this.onCheckout,
    required this.onPickCustomer,
    required this.onEditDiscount,
    this.processing = false,
  });

  final BusinessSettings settings;
  final String source;
  final VoidCallback onCheckout;
  final VoidCallback onPickCustomer;
  final VoidCallback onEditDiscount;
  final bool processing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);
    final isSheet = source == 'sheet';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Carrito',
                  variant: AppTextVariant.titleLarge,
                ),
              ),
              if (cart.isNotEmpty)
                IconButton(
                  tooltip: 'Vaciar carrito',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              if (isSheet)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onPickCustomer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppText(
                      cart.customer?.name ?? 'Consumidor final',
                      variant: AppTextVariant.bodySmall,
                      color: cart.customer == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const AppText(
                          'El carrito está vacío',
                          variant: AppTextVariant.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const AppText(
                          'Toca un producto para agregarlo',
                          variant: AppTextVariant.caption,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.lines.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final line = cart.lines[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    line.product.name,
                                    variant: AppTextVariant.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppText(
                                    Money.usd(line.product.price),
                                    variant: AppTextVariant.caption,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.remove,
                              onTap: () => controller.decrement(
                                line.product.id,
                              ),
                            ),
                            SizedBox(
                              width: 30,
                              child: AppText(
                                '${line.quantity}',
                                variant: AppTextVariant.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            _QtyButton(
                              icon: Icons.add,
                              onTap: () => controller.increment(
                                line.product.id,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: 66,
                              child: AppText(
                                Money.usd(line.subtotal),
                                variant: AppTextVariant.bodyMedium,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar',
                              onPressed: () =>
                                  controller.remove(line.product.id),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          _row('Subtotal', Money.usd(cart.subtotal)),
          InkWell(
            onTap: onEditDiscount,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: AppText(
                      'Descuento',
                      variant: AppTextVariant.bodySmall,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppText(
                    cart.discount > 0
                        ? '-${Money.usd(cart.discount)}'
                        : 'Agregar',
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.primary,
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          _row(
            'IVA (${settings.ivaRate.toStringAsFixed(0)}%)',
            Money.usd(cart.tax(settings.ivaRate)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Total',
                  variant: AppTextVariant.titleMedium,
                ),
              ),
              AppText(
                Money.usd(cart.total(settings.ivaRate)),
                variant: AppTextVariant.titleLarge,
                color: AppColors.primary,
              ),
            ],
          ),
          if (settings.rateBs > 0)
            Align(
              alignment: Alignment.centerRight,
              child: AppText(
                Money.bs(cart.total(settings.ivaRate) * settings.rateBs),
                variant: AppTextVariant.caption,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              'Cobrar',
              icon: Icons.check_circle_outline,
              size: AppButtonSize.large,
              loading: processing,
              onPressed: cart.isEmpty || processing ? null : onCheckout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
          ),
          AppText(value, variant: AppTextVariant.bodySmall),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}
