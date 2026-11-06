import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../cash/models/cash_session.dart';
import '../../cash/providers/cash_providers.dart';
import '../../settings/models/business_settings.dart';
import '../../settings/providers/settings_providers.dart';
import '../providers/dashboard_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({
    super.key,
    this.onSell,
    this.onInventory,
    this.onAccounts,
    this.onSales,
  });

  final VoidCallback? onSell;
  final VoidCallback? onInventory;
  final VoidCallback? onAccounts;
  final VoidCallback? onSales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final settings = ref.watch(settingsProvider);
    final openCash = ref.watch(openCashSessionProvider);
    final businessName =
        settings.valueOrNull?.businessName ?? 'Mi negocio';
    final rate = settings.valueOrNull?.rateBs ?? 0;

    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('No se pudo cargar el inicio: $error'),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                'Reintentar',
                onPressed: () => ref.invalidate(dashboardProvider),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _buildHeader(context, businessName, settings.valueOrNull),
            const SizedBox(height: AppSpacing.md),
            _buildCashBanner(context, openCash.valueOrNull),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                final spacing = AppSpacing.md;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: _StatCard(
                        title: 'Ventas de hoy',
                        value: Money.usd(data.todayTotal),
                        subtitle: rate > 0
                            ? Money.bs(data.todayTotal * rate)
                            : '${data.todayCount} ventas',
                        icon: Icons.payments_outlined,
                        color: AppColors.success,
                        onTap: onSales,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _StatCard(
                        title: 'Cuentas por cobrar',
                        value: Money.usd(data.receivable),
                        subtitle: '${data.openAccounts} cuentas abiertas',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.tertiary,
                        onTap: onAccounts,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _StatCard(
                        title: 'Stock bajo',
                        value: '${data.lowStock}',
                        subtitle: data.outOfStock > 0
                            ? '${data.outOfStock} agotados'
                            : 'Productos por reponer',
                        icon: Icons.inventory_2_outlined,
                        color: data.lowStock > 0
                            ? AppColors.warning
                            : AppColors.secondary,
                        onTap: onInventory,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _StatCard(
                        title: 'Ventas registradas',
                        value: '${data.todayCount}',
                        subtitle: 'Hoy',
                        icon: Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                        onTap: onSell,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                AppButton(
                  'Nueva venta',
                  icon: Icons.point_of_sale,
                  onPressed: onSell,
                ),
                AppButton(
                  'Agregar producto',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.add_box_outlined,
                  onPressed: () => context.push(AppRoutes.productNew),
                ),
                AppButton(
                  'Ver cuentas',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.receipt_long_outlined,
                  onPressed: onAccounts,
                ),
                AppButton(
                  'Caja',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.point_of_sale_outlined,
                  onPressed: () => context.push(AppRoutes.cash),
                ),
                AppButton(
                  'Reportes',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.bar_chart_outlined,
                  onPressed: () => context.push(AppRoutes.reports),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: AppText(
                          'Últimas ventas',
                          variant: AppTextVariant.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: onSales,
                        child: const Text('Ver todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.recentSales.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: AppText(
                          'Todavía no hay ventas. ¡Empieza a vender!',
                          variant: AppTextVariant.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    ...data.recentSales.map(
                      (sale) => _SaleRow(
                        sale: sale,
                        onTap: () =>
                            context.push('/venta/${sale.id}'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String businessName,
    BusinessSettings? settings,
  ) {
    final now = DateTime.now();
    final rate = settings?.rateBs ?? 0;
    final updated = settings?.rateUpdatedAt;

    final extras = <String>[
      if (updated != null) 'actualizada ${Money.date(updated)}',
    ];

    final rateText = rate > 0 ? 'Tasa ${Money.bs(rate)}' : 'Tasa sin configurar';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                businessName,
                variant: AppTextVariant.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              AppText(
                'Hoy es ${Money.date(now)} · $rateText'
                '${extras.isEmpty ? '' : ' · ${extras.join(' · ')}'}',
                variant: AppTextVariant.bodyMedium,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCashBanner(BuildContext context, CashSession? session) {
    final isOpen = session != null;
    final background =
        isOpen ? AppColors.successContainer : AppColors.warningContainer;
    final foreground =
        isOpen ? AppColors.onSuccessContainer : AppColors.onWarningContainer;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: () => context.push(AppRoutes.cash),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                isOpen ? Icons.lock_open_outlined : Icons.lock_outline,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      isOpen ? 'Caja abierta' : 'Caja cerrada',
                      variant: AppTextVariant.titleSmall,
                      color: foreground,
                    ),
                    AppText(
                      isOpen
                          ? 'Desde ${Money.dateTime(session.openedAt)} · '
                              'toca para cerrar el turno'
                          : 'Abre la caja para iniciar el turno',
                      variant: AppTextVariant.caption,
                      color: foreground,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppText(
                    title,
                    variant: AppTextVariant.labelMedium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppText(
              value,
              variant: AppTextVariant.headlineSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              subtitle,
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.onTap});

  final dynamic sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCredit = sale.status == 'pendiente';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    sale.number as String,
                    variant: AppTextVariant.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '${Money.dateTime(sale.createdAt as DateTime)} · '
                    '${sale.customerName ?? 'Sin cliente'}',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isCredit) ...[
              const AppBadge(
                'Fiado',
                variant: AppBadgeVariant.warning,
                size: AppBadgeSize.small,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            AppText(
              Money.usd(sale.total as double),
              variant: AppTextVariant.titleSmall,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
