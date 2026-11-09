import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../documents/data/thermal_printer_service.dart';
import '../../documents/receipt_pdf.dart';
import '../../settings/providers/settings_providers.dart';
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
                            if (sale.isCredit)
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
                                  child: AppText(
                                    item.name,
                                    variant: AppTextVariant.bodyMedium,
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
                    ),
                  ),
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
