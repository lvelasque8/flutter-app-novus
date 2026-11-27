import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../features/sales/models/sale.dart';
import '../../shared/widgets/atoms/app_badge.dart';
import '../../shared/widgets/atoms/app_button.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_common.dart';
import '../widgets/sale_detail_dialog.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.data,
    required this.onSeeSales,
  });

  final AdminData data;
  final VoidCallback onSeeSales;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminRange _range = AdminRange.today;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final now = DateTime.now();
    final sales = data.sales
        .where(
          (sale) =>
              !sale.isCancelled && _range.contains(sale.createdAt, now),
        )
        .toList();
    final total = sales.fold<double>(0, (sum, sale) => sum + sale.netTotal);
    final refunded = sales.fold<double>(0, (sum, sale) => sum + sale.refunded);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            const Expanded(
              child: AdminSectionHeader(
                title: 'Resumen',
                subtitle: 'Datos de la tablet al último sincronizado',
              ),
            ),
            AdminRangeSelector(
              value: _range,
              onChanged: (value) => setState(() => _range = value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            const spacing = AppSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Ventas (${_range.label.toLowerCase()})',
                    value: Money.usd(total),
                    detail: refunded > 0
                        ? 'Devoluciones -${Money.usd(refunded)} ya restadas'
                        : '${sales.length} ${sales.length == 1 ? 'venta' : 'ventas'}',
                    icon: Icons.point_of_sale_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Cuentas por cobrar',
                    value: Money.usd(data.receivable),
                    detail:
                        '${data.openAccounts.length} ${data.openAccounts.length == 1 ? 'cuenta abierta' : 'cuentas abiertas'}',
                    color: AppColors.tertiary,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Vencidas',
                    value: Money.usd(data.overdueAmount),
                    detail: data.overdueCount == 0
                        ? 'Nada vencido'
                        : '${data.overdueCount} ${data.overdueCount == 1 ? 'cliente' : 'clientes'}',
                    color: data.overdueCount > 0
                        ? AppColors.error
                        : AppColors.success,
                    icon: Icons.notifications_active_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Stock bajo',
                    value: '${data.lowStock.length}',
                    detail: '${data.products.length} productos activos',
                    color: data.lowStock.isEmpty
                        ? AppColors.success
                        : AppColors.warning,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final left = _buildRecentSales(sales);
            final right = _buildMethods(sales);
            if (!wide) {
              return Column(
                children: [left, const SizedBox(height: AppSpacing.lg), right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: left),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentSales(List<Sale> sales) {
    final recent = sales.take(6).toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Últimas ventas',
            subtitle: '${sales.length} en el período',
            trailing: AppButton(
              'Ver todas',
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.small,
              onPressed: widget.onSeeSales,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (recent.isEmpty)
            const AdminEmpty(
              message: 'No hay ventas en este período',
              icon: Icons.receipt_long_outlined,
            )
          else
            for (final sale in recent)
              InkWell(
                onTap: () => showSaleDetailDialog(context, sale),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
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
                                if (sale.isCredit)
                                  const AppBadge(
                                    'Fiado',
                                    variant: AppBadgeVariant.warning,
                                    size: AppBadgeSize.small,
                                  ),
                                if (sale.hasReturns)
                                  const AppBadge(
                                    'Devolución',
                                    variant: AppBadgeVariant.error,
                                    size: AppBadgeSize.small,
                                  ),
                              ],
                            ),
                            AppText(
                              '${Money.dateTime(sale.createdAt)} · '
                              '${sale.customerName ?? 'Sin cliente'}',
                              variant: AppTextVariant.caption,
                              color: AppColors.textSecondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AppText(
                        Money.usd(sale.netTotal),
                        variant: AppTextVariant.titleSmall,
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMethods(List<Sale> sales) {
    final totals = <String, double>{};
    for (final sale in sales) {
      for (final payment in sale.payments) {
        if (payment.method == PaymentMethods.devolucion) continue;
        totals[payment.method] =
            (totals[payment.method] ?? 0) + payment.amount;
      }
      for (final saleReturn in sale.returns) {
        final method = saleReturn.method == PaymentMethods.devolucion
            ? PaymentMethods.fiado
            : saleReturn.method;
        totals[method] = (totals[method] ?? 0) - saleReturn.total;
      }
    }
    final entries = totals.entries
        .where((entry) => entry.value.abs() > 0.005)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty
        ? 0.0
        : entries.map((entry) => entry.value.abs()).reduce(
            (a, b) => a > b ? a : b,
          );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(title: 'Cobrado por método'),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            const AdminEmpty(
              message: 'Sin pagos en el período',
              icon: Icons.payments_outlined,
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            PaymentMethods.label(entry.key),
                            variant: AppTextVariant.bodySmall,
                          ),
                        ),
                        AppText(
                          Money.usd(entry.value),
                          variant: AppTextVariant.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: max == 0 ? 0 : entry.value.abs() / max,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
