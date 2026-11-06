import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_search_field.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../models/sale.dart';
import '../providers/sale_providers.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() =>
      _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  String _query = '';
  int _range = 0; // 0 = todas, 1 = hoy, 2 = 7 días

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppSearchField(
                  hint: 'Buscar por número, cliente o pago...',
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Todas')),
                  ButtonSegment(value: 1, label: Text('Hoy')),
                  ButtonSegment(value: 2, label: Text('7 días')),
                ],
                selected: {_range},
                onSelectionChanged: (value) =>
                    setState(() => _range = value.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: sales.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('No se pudo cargar el historial: $error'),
            ),
            data: (items) {
              final filtered = _filter(items);
              if (filtered.isEmpty) {
                return const Center(
                  child: AppText(
                    'No hay ventas para mostrar',
                    variant: AppTextVariant.titleMedium,
                    color: AppColors.textSecondary,
                  ),
                );
              }

              final total = filtered.fold<double>(
                0,
                (sum, sale) => sum + sale.total,
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        AppText(
                          '${filtered.length} ventas',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                        const Spacer(),
                        AppText(
                          'Total: ${Money.usd(total)}',
                          variant: AppTextVariant.titleSmall,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final sale = filtered[index];
                        return _SaleTile(
                          sale: sale,
                          onTap: () => context.push('/venta/${sale.id}'),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Sale> _filter(List<Sale> sales) {
    var result = sales;
    final now = DateTime.now();

    if (_range == 1) {
      final start = DateTime(now.year, now.month, now.day);
      result = result
          .where((sale) => sale.createdAt.isAfter(start))
          .toList();
    } else if (_range == 2) {
      final start = now.subtract(const Duration(days: 7));
      result = result
          .where((sale) => sale.createdAt.isAfter(start))
          .toList();
    }

    if (_query.trim().isNotEmpty) {
      final query = _query.toLowerCase();
      result = result.where((sale) {
        return sale.number.toLowerCase().contains(query) ||
            (sale.customerName ?? '').toLowerCase().contains(query) ||
            PaymentMethods.label(sale.paymentMethod)
                .toLowerCase()
                .contains(query);
      }).toList();
    }

    return result;
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sale.isCredit
                    ? AppColors.warningContainer
                    : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                sale.isCredit
                    ? Icons.receipt_long_outlined
                    : Icons.receipt_outlined,
                color: sale.isCredit
                    ? AppColors.warning
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '${Money.dateTime(sale.createdAt)} · '
                    '${sale.customerName ?? 'Consumidor final'}',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  Money.usd(sale.total),
                  variant: AppTextVariant.titleSmall,
                ),
                AppText(
                  PaymentMethods.label(sale.paymentMethod),
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondary,
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
