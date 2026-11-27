import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../features/products/models/product.dart';
import '../../shared/widgets/atoms/app_badge.dart';
import '../../shared/widgets/atoms/app_card.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../../shared/widgets/atoms/app_text_field.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_common.dart';

class AdminInventoryPage extends StatefulWidget {
  const AdminInventoryPage({super.key, required this.data});

  final AdminData data;

  @override
  State<AdminInventoryPage> createState() => _AdminInventoryPageState();
}

class _AdminInventoryPageState extends State<AdminInventoryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final products = widget.data.products
        .where((product) => product.active)
        .where(
          (product) =>
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query) ||
              product.barcode.toLowerCase().contains(query) ||
              product.category.toLowerCase().contains(query),
        )
        .toList();

    final costValue = products.fold<double>(
      0,
      (sum, product) => sum + product.cost * product.stock,
    );
    final retailValue = products.fold<double>(
      0,
      (sum, product) => sum + product.price * product.stock,
    );
    final units = products.fold<int>(0, (sum, product) => sum + product.stock);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AdminSectionHeader(
          title: 'Inventario',
          subtitle: 'Existencias al último sincronizado',
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
                    label: 'Productos activos',
                    value: '${products.length}',
                    detail: '$units unidades en total',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Valor a costo',
                    value: Money.usd(costValue),
                    color: AppColors.tertiary,
                    icon: Icons.warehouse_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Valor a precio',
                    value: Money.usd(retailValue),
                    color: AppColors.success,
                    icon: Icons.sell_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: AdminStatCard(
                    label: 'Por reponer',
                    value: '${widget.data.lowStock.length}',
                    detail: 'Stock en el mínimo o agotado',
                    color: widget.data.lowStock.isEmpty
                        ? AppColors.success
                        : AppColors.warning,
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: 380,
          child: AppTextField(
            hint: 'Buscar por nombre, SKU, código o categoría',
            prefixIcon: Icons.search,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: products.isEmpty
              ? const AdminEmpty(
                  message: 'No hay productos para este filtro',
                  icon: Icons.inventory_2_outlined,
                )
              : Column(
                  children: [
                    for (final product in products)
                      _ProductRow(product: product),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                AppText(
                  product.name,
                  variant: AppTextVariant.titleSmall,
                ),
                AppText(
                  [
                    if (product.category.isNotEmpty) product.category,
                    if (product.sku.isNotEmpty) product.sku,
                    if (product.barcode.isNotEmpty) product.barcode,
                  ].join(' · '),
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          Expanded(
            child: AppText(
              product.price > 0 ? Money.usd(product.price) : '—',
              variant: AppTextVariant.bodyMedium,
            ),
          ),
          Expanded(
            child: AppText(
              product.cost > 0 ? Money.usd(product.cost) : '—',
              variant: AppTextVariant.caption,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppText(
                  '${product.stock}',
                  variant: AppTextVariant.titleSmall,
                ),
                const SizedBox(width: AppSpacing.sm),
                if (product.outOfStock)
                  const AppBadge(
                    'Agotado',
                    variant: AppBadgeVariant.error,
                    size: AppBadgeSize.small,
                  )
                else if (product.lowStock)
                  const AppBadge(
                    'Bajo',
                    variant: AppBadgeVariant.warning,
                    size: AppBadgeSize.small,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
