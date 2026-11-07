import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../sales/models/sale.dart';
import '../models/reports_data.dart';
import '../providers/reports_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  int _preset = 0;

  void _selectPreset(int preset) {
    setState(() => _preset = preset);
    final notifier = ref.read(reportRangeProvider.notifier);
    switch (preset) {
      case 0:
        notifier.state = ReportRange.today();
        return;
      case 1:
        notifier.state = ReportRange.last7Days();
        return;
      case 2:
        notifier.state = ReportRange.thisMonth();
        return;
    }
  }

  Future<void> _pickRange() async {
    final current = ref.read(reportRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Rango de fechas',
      saveText: 'Aplicar',
    );
    if (picked == null) return;

    setState(() => _preset = 3);
    ref.read(reportRangeProvider.notifier).state = ReportRange(
      start: DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      ),
      end: DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      ).add(const Duration(days: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportsProvider);
    final range = ref.watch(reportRangeProvider);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Reportes'),
              centerTitle: false,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Hoy'),
                    selected: _preset == 0,
                    onSelected: (_) => _selectPreset(0),
                  ),
                  ChoiceChip(
                    label: const Text('7 días'),
                    selected: _preset == 1,
                    onSelected: (_) => _selectPreset(1),
                  ),
                  ChoiceChip(
                    label: const Text('Este mes'),
                    selected: _preset == 2,
                    onSelected: (_) => _selectPreset(2),
                  ),
                  ChoiceChip(
                    label: const Text('Personalizado'),
                    selected: _preset == 3,
                    onSelected: (_) => _pickRange(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppText(
                    range.label,
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              reports.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl3),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text('No se pudieron cargar los reportes: $error'),
                  ),
                ),
                data: (data) => _buildData(data),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildData(ReportsData data) {
    final summary = data.summary;
    if (summary.salesCount == 0) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl3),
        child: Column(
          children: [
            const Icon(
              Icons.bar_chart_outlined,
              size: 56,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppSpacing.md),
            const AppText(
              'No hay ventas en este período',
              variant: AppTextVariant.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppText(
              'Prueba con otro rango de fechas.',
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            final spacing = AppSpacing.md;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    label: 'Ventas',
                    value: Money.usd(summary.totalUsd),
                    detail: Money.bs(summary.totalBs),
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    label: 'Ticket promedio',
                    value: Money.usd(summary.averageTicket),
                    detail: '${summary.salesCount} ventas',
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    label: 'IVA',
                    value: Money.usd(summary.tax),
                    detail: 'Descuentos ${Money.usd(summary.discount)}',
                    color: AppColors.tertiary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _SummaryCard(
                    label: 'Utilidad estimada',
                    value: Money.usd(summary.profit),
                    detail: 'Costo ${Money.usd(summary.cost)}',
                    color: AppColors.accent,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            final methods = _buildMethods(data);
            final products = _buildProducts(data);
            if (!wide) {
              return Column(
                children: [
                  methods,
                  const SizedBox(height: AppSpacing.lg),
                  products,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: methods),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: products),
              ],
            );
          },
        ),
        if (data.daily.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          _buildDaily(data),
        ],
      ],
    );
  }

  Widget _buildMethods(ReportsData data) {
    final maxTotal = data.byMethod.isEmpty
        ? 0.0
        : data.byMethod
            .map((method) => method.totalUsd)
            .reduce((a, b) => a > b ? a : b);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Ventas por forma de pago',
            variant: AppTextVariant.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.byMethod.map(
            (method) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          PaymentMethods.label(method.method),
                          variant: AppTextVariant.bodySmall,
                        ),
                      ),
                      AppText(
                        Money.usd(method.totalUsd),
                        variant: AppTextVariant.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxTotal == 0 ? 0 : method.totalUsd / maxTotal,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '${method.count} ventas',
                    variant: AppTextVariant.caption,
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

  Widget _buildProducts(ReportsData data) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Productos más vendidos',
            variant: AppTextVariant.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.topProducts.take(8).map(
                (product) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              product.name,
                              variant: AppTextVariant.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppText(
                              '${product.quantity} unidades · '
                              'utilidad ${Money.usd(product.profit)}',
                              variant: AppTextVariant.caption,
                              color: AppColors.textHint,
                            ),
                          ],
                        ),
                      ),
                      AppText(
                        Money.usd(product.revenue),
                        variant: AppTextVariant.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildDaily(ReportsData data) {
    final days = data.daily.length > 31
        ? data.daily.sublist(data.daily.length - 31)
        : data.daily;
    final maxTotal = days
        .map((day) => day.totalUsd)
        .reduce((a, b) => a > b ? a : b);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Ventas por día',
            variant: AppTextVariant.titleLarge,
          ),
          if (data.daily.length > 31)
            const AppText(
              'Mostrando los últimos 31 días del rango.',
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final height = maxTotal == 0 ? 0.0 : day.totalUsd / maxTotal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AppText(
                          Money.usd(day.totalUsd),
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondary,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 110 * height,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppText(
                          Money.shortDate(day.date),
                          variant: AppTextVariant.caption,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppText(
                label,
                variant: AppTextVariant.caption,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppText(
            value,
            variant: AppTextVariant.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          AppText(
            detail,
            variant: AppTextVariant.caption,
            color: AppColors.textHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
