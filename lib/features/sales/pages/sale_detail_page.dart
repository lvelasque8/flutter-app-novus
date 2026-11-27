import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../../shared/widgets/atoms/app_text_field.dart';
import '../../accounts/providers/account_providers.dart';
import '../../cash/providers/cash_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../documents/data/thermal_printer_service.dart';
import '../../documents/receipt_pdf.dart';
import '../../products/providers/product_providers.dart';
import '../../reports/providers/reports_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../../sync/providers/remote_sync_providers.dart';
import '../data/sale_repository.dart';
import '../models/sale.dart';
import '../providers/sale_providers.dart';

class SaleDetailPage extends ConsumerWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleAsync = ref.watch(saleByIdProvider(saleId));
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de venta'),
        centerTitle: false,
        actions: [
          saleAsync.maybeWhen(
            data: (sale) => sale == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Imprimir ticket (Bluetooth)',
                        onPressed: () async {
                          final business = settings.valueOrNull;
                          if (business == null) return;
                          final messenger = ScaffoldMessenger.of(context);
                          final service = ThermalPrinterService();
                          final printer = await service.load();
                          if (!printer.isConfigured) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Configura la impresora térmica en Ajustes',
                                ),
                              ),
                            );
                            return;
                          }
                          try {
                            await service.printSale(
                              sale: sale,
                              settings: business,
                              printer: printer,
                            );
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Ticket impreso')),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  error
                                      .toString()
                                      .replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.print_outlined),
                      ),
                      IconButton(
                        tooltip: 'Imprimir nota (PDF)',
                        onPressed: () {
                          final business = settings.valueOrNull;
                          if (business == null) return;
                          printSaleReceipt(sale: sale, settings: business);
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                      ),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('No se pudo cargar la venta: $error'),
        ),
        data: (sale) {
          if (sale == null) {
            return const Center(child: Text('Venta no encontrada'));
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    sale.number,
                                    variant: AppTextVariant.headlineSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  AppText(
                                    Money.dateTime(sale.createdAt),
                                    variant: AppTextVariant.bodySmall,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            if (sale.isCancelled)
                              const AppBadge(
                                'Anulada',
                                variant: AppBadgeVariant.error,
                              )
                            else if (sale.isFullyRefunded)
                              const AppBadge(
                                'Devuelta',
                                variant: AppBadgeVariant.error,
                              )
                            else if (sale.hasReturns)
                              const AppBadge(
                                'Con devolución',
                                variant: AppBadgeVariant.warning,
                              )
                            else if (sale.isCredit)
                              const AppBadge(
                                'Fiado · pendiente',
                                variant: AppBadgeVariant.warning,
                              )
                            else
                              const AppBadge(
                                'Pagada',
                                variant: AppBadgeVariant.success,
                              ),
                          ],
                        ),
                        const Divider(height: AppSpacing.xl2),
                        _InfoRow(
                          label: 'Cliente',
                          value: sale.customerName ?? 'Consumidor final',
                        ),
                        if (sale.payments.isEmpty) ...[
                          _InfoRow(
                            label: 'Forma de pago',
                            value: PaymentMethods.label(sale.paymentMethod),
                          ),
                          if (sale.reference != null &&
                              sale.reference!.isNotEmpty)
                            _InfoRow(
                              label: 'Referencia',
                              value: sale.reference!,
                            ),
                        ] else ...[
                          const SizedBox(height: AppSpacing.sm),
                          const AppText(
                            'Formas de pago',
                            variant: AppTextVariant.labelMedium,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          ...sale.payments.map(
                            (payment) => _InfoRow(
                              label: PaymentMethods.label(payment.method),
                              value: [
                                Money.usd(payment.amount),
                                if (payment.reference != null &&
                                    payment.reference!.isNotEmpty)
                                  'Ref. ${payment.reference}',
                              ].join(' · '),
                            ),
                          ),
                        ],
                        _InfoRow(
                          label: 'Tasa BCV',
                          value: sale.rate > 0
                              ? '${Money.bs(sale.rate)} / USD'
                              : 'No registrada',
                        ),
                        if (sale.hasReturns)
                          _InfoRow(
                            label: 'Devuelto',
                            value: '-${Money.usd(sale.refunded)}',
                          ),
                        if (sale.isCancelled) ...[
                          const Divider(height: AppSpacing.lg),
                          _InfoRow(
                            label: 'Anulada',
                            value: sale.cancelledAt == null
                                ? 'Sí'
                                : Money.dateTime(sale.cancelledAt!),
                          ),
                          if (sale.cancelReason != null &&
                              sale.cancelReason!.isNotEmpty)
                            _InfoRow(
                              label: 'Motivo',
                              value: sale.cancelReason!,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Productos',
                          variant: AppTextVariant.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ...sale.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: AppText(
                                    '${item.quantity}x',
                                    variant: AppTextVariant.bodySmall,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        item.name,
                                        variant: AppTextVariant.bodyMedium,
                                      ),
                                      if (sale.returnedQuantity(item.id) > 0)
                                        AppText(
                                          'Devuelto: '
                                          '${sale.returnedQuantity(item.id)}',
                                          variant: AppTextVariant.caption,
                                          color: AppColors.error,
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: AppText(
                                    Money.usd(item.price),
                                    variant: AppTextVariant.bodySmall,
                                    textAlign: TextAlign.right,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: AppText(
                                    Money.usd(item.subtotal),
                                    variant: AppTextVariant.bodyMedium,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: AppSpacing.xl),
                        _TotalRow(
                          label: 'Subtotal',
                          value: Money.usd(sale.subtotal),
                        ),
                        if (sale.discount > 0)
                          _TotalRow(
                            label: 'Descuento',
                            value: '-${Money.usd(sale.discount)}',
                          ),
                        _TotalRow(
                          label: 'IVA',
                          value: Money.usd(sale.tax),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (sale.hasReturns) ...[
                          _TotalRow(
                            label: 'Total original',
                            value: Money.usd(sale.total),
                          ),
                          _TotalRow(
                            label: 'Devuelto',
                            value: '-${Money.usd(sale.refunded)}',
                          ),
                          _TotalRow(
                            label: 'Total neto USD',
                            value: Money.usd(sale.netTotal),
                            strong: true,
                          ),
                          if (sale.rate > 0)
                            _TotalRow(
                              label: 'Total neto Bs',
                              value: Money.bs(sale.netTotalBs),
                              strong: true,
                            ),
                        ] else ...[
                          _TotalRow(
                            label: 'Total USD',
                            value: Money.usd(sale.total),
                            strong: true,
                          ),
                          if (sale.rate > 0)
                            _TotalRow(
                              label: 'Total Bs',
                              value: Money.bs(sale.totalBs),
                              strong: true,
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (sale.returns.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Devoluciones',
                            variant: AppTextVariant.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final saleReturn in sale.returns)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppText(
                                          Money.dateTime(saleReturn.createdAt),
                                          variant: AppTextVariant.bodySmall,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      AppBadge(
                                        PaymentMethods.label(
                                          saleReturn.method,
                                        ),
                                        variant: AppBadgeVariant.outline,
                                        size: AppBadgeSize.small,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      AppText(
                                        '-${Money.usd(saleReturn.total)}',
                                        variant: AppTextVariant.titleSmall,
                                        color: AppColors.error,
                                      ),
                                    ],
                                  ),
                                  if (saleReturn.reason != null &&
                                      saleReturn.reason!.isNotEmpty)
                                    AppText(
                                      'Motivo: ${saleReturn.reason}',
                                      variant: AppTextVariant.caption,
                                      color: AppColors.textSecondary,
                                    ),
                                  for (final item in saleReturn.items)
                                    AppText(
                                      '${item.quantity}x ${item.name} · '
                                      '${Money.usd(item.subtotal)}',
                                      variant: AppTextVariant.caption,
                                      color: AppColors.textSecondary,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    'Imprimir / compartir nota',
                    icon: Icons.print_outlined,
                    onPressed: () {
                      final business = settings.valueOrNull;
                      if (business == null) return;
                      printSaleReceipt(sale: sale, settings: business);
                    },
                  ),
                  if (!sale.isCancelled) ...[
                    if (sale.items.any(
                      (item) =>
                          sale.returnedQuantity(item.id) < item.quantity,
                    )) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        'Devolver productos',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.assignment_return_outlined,
                        onPressed: () => _showReturnDialog(
                          context,
                          ref,
                          sale,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      'Anular venta',
                      variant: AppButtonVariant.danger,
                      icon: Icons.block_outlined,
                      onPressed: sale.hasReturns
                          ? null
                          : () => _confirmCancelSale(
                                context,
                                ref,
                                sale,
                              ),
                    ),
                    if (sale.hasReturns)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs),
                        child: AppText(
                          'No se puede anular una venta con devoluciones.',
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> _confirmCancelSale(
  BuildContext context,
  WidgetRef ref,
  Sale sale,
) async {
  final reason = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Anular venta ${sale.number}'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se devolverá el stock de los productos y la venta dejará de '
              'sumar en caja, reportes y cuentas por cobrar.'
              '${sale.isCredit ? ' También se anulará el fiado de esta venta.' : ''}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Ej: error de cobro, producto devuelto',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Anular venta'),
        ),
      ],
    ),
  );

  final text = reason.text.trim();
  reason.dispose();
  if (confirmed != true) return;

  try {
    await ref.read(saleRepositoryProvider).cancelSale(sale.id, reason: text);
    ref.invalidate(salesProvider);
    ref.invalidate(saleByIdProvider(sale.id));
    ref.invalidate(todayTotalProvider);
    ref.invalidate(todayCountProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(cashSummaryProvider);
    ref.invalidate(reportsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(receivableTotalProvider);
    ref.invalidate(openAccountsCountProvider);
    ref.invalidate(activeProductsProvider);
    ref.invalidate(productsProvider);
    ref.read(remoteSyncControllerProvider.notifier).requestSync();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta ${sale.number} anulada')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }
}

Future<void> _showReturnDialog(
  BuildContext context,
  WidgetRef ref,
  Sale sale,
) async {
  final data = await showDialog<_ReturnData>(
    context: context,
    builder: (context) => _ReturnDialog(sale: sale),
  );
  if (data == null) return;

  try {
    final result = await ref.read(saleRepositoryProvider).returnItems(
          saleId: sale.id,
          lines: data.lines,
          method: data.method,
          reason: data.reason,
        );

    ref.invalidate(saleByIdProvider(sale.id));
    ref.invalidate(salesProvider);
    ref.invalidate(todayTotalProvider);
    ref.invalidate(todayCountProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(cashSummaryProvider);
    ref.invalidate(reportsProvider);
    ref.invalidate(accountsProvider);
    ref.invalidate(collectionProvider);
    ref.invalidate(receivableTotalProvider);
    ref.invalidate(openAccountsCountProvider);
    ref.invalidate(activeProductsProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(accountPaymentsProvider);
    if (sale.customerId != null) {
      ref.invalidate(customerAccountsProvider(sale.customerId!));
    }
    ref.read(remoteSyncControllerProvider.notifier).requestSync();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Devolución registrada: ${Money.usd(result.total)}',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }
}

class _ReturnData {
  const _ReturnData({
    required this.lines,
    required this.method,
    required this.reason,
  });

  final List<ReturnLineInput> lines;
  final String method;
  final String reason;
}

class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.sale});

  final Sale sale;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _quantities = <String, int>{};
  final _reason = TextEditingController();
  late String _method;

  static const _methods = [
    PaymentMethods.efectivoBs,
    PaymentMethods.efectivoUsd,
    PaymentMethods.pagoMovil,
    PaymentMethods.transferencia,
    PaymentMethods.puntoVenta,
  ];

  @override
  void initState() {
    super.initState();
    _method = _methods.contains(widget.sale.paymentMethod)
        ? widget.sale.paymentMethod
        : PaymentMethods.efectivoUsd;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int _remaining(SaleItem item) {
    return item.quantity - widget.sale.returnedQuantity(item.id);
  }

  int _quantity(SaleItem item) => _quantities[item.id] ?? 0;

  double get _total {
    var total = 0.0;
    for (final item in widget.sale.items) {
      final quantity = _quantity(item);
      if (quantity <= 0) continue;
      total += SaleRepository.refundForLine(
        price: item.price,
        quantity: quantity,
        saleSubtotal: widget.sale.subtotal,
        saleTotal: widget.sale.total,
      );
    }
    return (total * 100).round() / 100;
  }

  void _setQuantity(SaleItem item, int value) {
    final max = _remaining(item);
    final next = value.clamp(0, max);
    setState(() {
      if (next == 0) {
        _quantities.remove(item.id);
      } else {
        _quantities[item.id] = next;
      }
    });
  }

  void _confirm() {
    final lines = <ReturnLineInput>[
      for (final entry in _quantities.entries)
        ReturnLineInput(saleItemId: entry.key, quantity: entry.value),
    ];
    if (lines.isEmpty) return;
    Navigator.pop(
      context,
      _ReturnData(
        lines: lines,
        method: _method,
        reason: _reason.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final items = sale.items.where((item) => _remaining(item) > 0).toList();

    return AlertDialog(
      scrollable: true,
      title: Text('Devolver productos · ${sale.number}'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Elige las cantidades que devuelve el cliente. El stock se '
              'repone automáticamente.',
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            item.name,
                            variant: AppTextVariant.bodyMedium,
                          ),
                          AppText(
                            'Vendidos ${item.quantity} · '
                            'Devueltos ${sale.returnedQuantity(item.id)} · '
                            '${Money.usd(item.price)} c/u',
                            variant: AppTextVariant.caption,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar uno',
                      onPressed: _quantity(item) > 0
                          ? () => _setQuantity(item, _quantity(item) - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 28,
                      child: AppText(
                        '${_quantity(item)}',
                        variant: AppTextVariant.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Agregar uno',
                      onPressed: _quantity(item) < _remaining(item)
                          ? () => _setQuantity(item, _quantity(item) + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.xl),
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Total a devolver',
                    variant: AppTextVariant.titleMedium,
                  ),
                ),
                AppText(
                  Money.usd(_total),
                  variant: AppTextVariant.titleLarge,
                  color: AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (sale.isCredit)
              const AppText(
                'La devolución se abonará a la cuenta del cliente.',
                variant: AppTextVariant.bodySmall,
                color: AppColors.textSecondary,
              )
            else ...[
              const AppText(
                'Forma de devolución',
                variant: AppTextVariant.labelMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _methods.map((method) {
                  final selected = _method == method;
                  return ChoiceChip(
                    label: Text(PaymentMethods.label(method)),
                    selected: selected,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _method = method),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Motivo (opcional)',
              hint: 'Ej: producto defectuoso',
              controller: _reason,
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        AppButton(
          'Registrar devolución',
          onPressed: _total > 0 ? _confirm : null,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: AppText(
              label,
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: AppText(value, variant: AppTextVariant.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              variant: strong
                  ? AppTextVariant.titleMedium
                  : AppTextVariant.bodySmall,
              color: strong ? null : AppColors.textSecondary,
            ),
          ),
          AppText(
            value,
            variant: strong
                ? AppTextVariant.titleMedium
                : AppTextVariant.bodySmall,
            color: strong ? AppColors.primary : null,
          ),
        ],
      ),
    );
  }
}
