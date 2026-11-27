import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../features/sales/models/sale.dart';
import '../../shared/widgets/atoms/app_badge.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../../shared/widgets/atoms/app_text_field.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_common.dart';
import '../widgets/sale_detail_dialog.dart';

class AdminSalesPage extends StatefulWidget {
  const AdminSalesPage({super.key, required this.data});

  final AdminData data;

  @override
  State<AdminSalesPage> createState() => _AdminSalesPageState();
}

class _AdminSalesPageState extends State<AdminSalesPage> {
  AdminRange _range = AdminRange.week;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final query = _query.trim().toLowerCase();
    final sales = widget.data.sales
        .where((sale) => _range.contains(sale.createdAt, now))
        .where(
          (sale) =>
              query.isEmpty ||
              sale.number.toLowerCase().contains(query) ||
              (sale.customerName ?? '').toLowerCase().contains(query),
        )
        .toList();
    final total = sales
        .where((sale) => !sale.isCancelled)
        .fold<double>(0, (sum, sale) => sum + sale.netTotal);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AdminSectionHeader(
          title: 'Ventas',
          subtitle:
              '${sales.length} ${sales.length == 1 ? 'venta' : 'ventas'} · '
              '${Money.usd(total)} netos',
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: AppTextField(
                hint: 'Buscar por número o cliente',
                prefixIcon: Icons.search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            AdminRangeSelector(
              value: _range,
              onChanged: (value) => setState(() => _range = value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: sales.isEmpty
              ? const AdminEmpty(
                  message: 'No hay ventas para este filtro',
                  icon: Icons.receipt_long_outlined,
                )
              : Column(
                  children: [
                    for (final sale in sales) _SaleRow(sale: sale),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showSaleDetailDialog(context, sale),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppText(
                        sale.number,
                        variant: AppTextVariant.titleSmall,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (sale.isCancelled)
                        const AppBadge(
                          'Anulada',
                          variant: AppBadgeVariant.error,
                          size: AppBadgeSize.small,
                        )
                      else if (sale.isFullyRefunded)
                        const AppBadge(
                          'Devuelta',
                          variant: AppBadgeVariant.error,
                          size: AppBadgeSize.small,
                        )
                      else if (sale.hasReturns)
                        const AppBadge(
                          'Con devolución',
                          variant: AppBadgeVariant.warning,
                          size: AppBadgeSize.small,
                        )
                      else if (sale.isCredit)
                        const AppBadge(
                          'Fiado',
                          variant: AppBadgeVariant.warning,
                          size: AppBadgeSize.small,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '${Money.dateTime(sale.createdAt)} · '
                    '${sale.customerName ?? 'Sin cliente'}',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: AppText(
                PaymentMethods.label(sale.paymentMethod),
                variant: AppTextVariant.caption,
                color: AppColors.textSecondary,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  Money.usd(sale.netTotal),
                  variant: AppTextVariant.titleSmall,
                ),
                if (sale.hasReturns)
                  AppText(
                    'Devuelto -${Money.usd(sale.refunded)}',
                    variant: AppTextVariant.caption,
                    color: AppColors.error,
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
