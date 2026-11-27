import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../features/sales/models/sale.dart';
import '../../shared/widgets/atoms/app_badge.dart';
import '../../shared/widgets/atoms/app_text.dart';

Future<void> showSaleDetailDialog(BuildContext context, Sale sale) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      'Venta ${sale.number}',
                      variant: AppTextVariant.titleLarge,
                    ),
                  ),
                  _statusBadge(sale),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              AppText(
                '${Money.dateTime(sale.createdAt)} · '
                '${sale.customerName ?? 'Consumidor final'}',
                variant: AppTextVariant.bodySmall,
                color: AppColors.textSecondary,
              ),
              const Divider(height: AppSpacing.xl),
              AppText(
                'Productos',
                variant: AppTextVariant.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in sale.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: AppText(
                          '${item.quantity}x',
                          variant: AppTextVariant.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: AppText(
                          item.name,
                          variant: AppTextVariant.bodyMedium,
                        ),
                      ),
                      AppText(
                        Money.usd(item.subtotal),
                        variant: AppTextVariant.bodyMedium,
                      ),
                    ],
                  ),
                ),
              const Divider(height: AppSpacing.xl),
              _row('Subtotal', Money.usd(sale.subtotal)),
              if (sale.discount > 0)
                _row('Descuento', '-${Money.usd(sale.discount)}'),
              _row('IVA', Money.usd(sale.tax)),
              if (sale.hasReturns) ...[
                _row('Total original', Money.usd(sale.total)),
                _row(
                  'Devuelto',
                  '-${Money.usd(sale.refunded)}',
                  color: AppColors.error,
                ),
                _row(
                  'Total neto USD',
                  Money.usd(sale.netTotal),
                  strong: true,
                ),
                if (sale.rate > 0)
                  _row(
                    'Total neto Bs',
                    Money.bs(sale.netTotalBs),
                    strong: true,
                  ),
              ] else ...[
                _row('Total USD', Money.usd(sale.total), strong: true),
                if (sale.rate > 0)
                  _row('Total Bs', Money.bs(sale.totalBs), strong: true),
              ],
              if (sale.payments.isNotEmpty) ...[
                const Divider(height: AppSpacing.xl),
                AppText('Pagos', variant: AppTextVariant.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final payment in sale.payments)
                  _row(
                    PaymentMethods.label(payment.method),
                    Money.usd(payment.amount),
                  ),
              ],
              if (sale.returns.isNotEmpty) ...[
                const Divider(height: AppSpacing.xl),
                AppText('Devoluciones', variant: AppTextVariant.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final saleReturn in sale.returns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                '${Money.dateTime(saleReturn.createdAt)} · '
                                '${PaymentMethods.label(saleReturn.method)}',
                                variant: AppTextVariant.bodySmall,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            AppText(
                              '-${Money.usd(saleReturn.total)}',
                              variant: AppTextVariant.bodyMedium,
                              color: AppColors.error,
                            ),
                          ],
                        ),
                        for (final item in saleReturn.items)
                          AppText(
                            '${item.quantity}x ${item.name}',
                            variant: AppTextVariant.caption,
                            color: AppColors.textHint,
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _statusBadge(Sale sale) {
  if (sale.isCancelled) {
    return const AppBadge('Anulada', variant: AppBadgeVariant.error);
  }
  if (sale.isFullyRefunded) {
    return const AppBadge('Devuelta', variant: AppBadgeVariant.error);
  }
  if (sale.hasReturns) {
    return const AppBadge('Con devolución', variant: AppBadgeVariant.warning);
  }
  if (sale.isCredit) {
    return const AppBadge('Fiado', variant: AppBadgeVariant.warning);
  }
  return const AppBadge('Pagada', variant: AppBadgeVariant.success);
}

Widget _row(String label, String value, {bool strong = false, Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: AppText(
            label,
            variant: strong
                ? AppTextVariant.titleSmall
                : AppTextVariant.bodyMedium,
          ),
        ),
        AppText(
          value,
          variant: strong
              ? AppTextVariant.titleSmall
              : AppTextVariant.bodyMedium,
          color: color,
        ),
      ],
    ),
  );
}
