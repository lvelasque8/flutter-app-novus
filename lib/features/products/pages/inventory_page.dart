import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/demo_data.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/atoms/app_badge.dart';
import '../../../shared/widgets/atoms/app_button.dart';
import '../../../shared/widgets/atoms/app_card.dart';
import '../../../shared/widgets/atoms/app_search_field.dart';
import '../../../shared/widgets/atoms/app_text.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../models/product.dart';
import '../providers/product_providers.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final search = ref.watch(productSearchProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppSearchField(
                  hint: 'Buscar por nombre, código o categoría...',
                  initialValue: search,
                  onChanged: (value) {
                    ref.read(productSearchProvider.notifier).state = value;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppButton(
                'Agregar producto',
                icon: Icons.add,
                onPressed: () => context.push(AppRoutes.productNew),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('No se pudo cargar el inventario: $error'),
            ),
            data: (items) {
              if (items.isEmpty) {
                return _EmptyInventory(
                  search: search,
                  onSeed: () async {
                    await DemoData.seedProducts();
                    ref.invalidate(productsProvider);
                    ref.invalidate(activeProductsProvider);
                    ref.invalidate(dashboardProvider);
                  },
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final showCategory = constraints.maxWidth > 760;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: AppText(
                                'Producto',
                                variant: AppTextVariant.labelMedium,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (showCategory)
                              const Expanded(
                                flex: 2,
                                child: AppText(
                                  'Categoría',
                                  variant: AppTextVariant.labelMedium,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(
                              width: 110,
                              child: AppText(
                                'Stock',
                                variant: AppTextVariant.labelMedium,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(
                              width: 130,
                              child: AppText(
                                'Precio',
                                variant: AppTextVariant.labelMedium,
                                color: AppColors.textSecondary,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 44),
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
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = items[index];
                            return _ProductRow(
                              product: product,
                              showCategory: showCategory,
                              onTap: () => context.push(
                                '/producto/${product.id}',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.showCategory,
    required this.onTap,
  });

  final Product product;
  final bool showCategory;
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
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    product.name,
                    variant: AppTextVariant.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    product.sku.isEmpty
                        ? 'Sin código'
                        : 'Código: ${product.sku}',
                    variant: AppTextVariant.caption,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            if (showCategory)
              Expanded(
                flex: 2,
                child: AppText(
                  product.category.isEmpty ? '—' : product.category,
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.textSecondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StockBadge(product: product),
              ),
            ),
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    Money.usd(product.price),
                    variant: AppTextVariant.titleSmall,
                  ),
                  if (product.cost > 0)
                    AppText(
                      'Costo ${Money.usd(product.cost)}',
                      variant: AppTextVariant.caption,
                      color: AppColors.textHint,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Editar',
              onPressed: onTap,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    if (product.outOfStock) {
      return const AppBadge(
        'Agotado',
        variant: AppBadgeVariant.error,
        size: AppBadgeSize.small,
      );
    }
    if (product.lowStock) {
      return AppBadge(
        '${product.stock} · bajo',
        variant: AppBadgeVariant.warning,
        size: AppBadgeSize.small,
      );
    }
    return AppBadge(
      '${product.stock} uds',
      variant: AppBadgeVariant.success,
      size: AppBadgeSize.small,
    );
  }
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.search, this.onSeed});

  final String search;
  final VoidCallback? onSeed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: AppColors.textHint,
              ),
              const SizedBox(height: AppSpacing.md),
              AppText(
                search.isEmpty
                    ? 'Tu inventario está vacío'
                    : 'No encontramos productos',
                variant: AppTextVariant.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppText(
                search.isEmpty
                    ? 'Agrega tu primer producto para empezar a vender.'
                    : 'Prueba con otro nombre o código.',
                variant: AppTextVariant.bodyMedium,
                color: AppColors.textSecondary,
                textAlign: TextAlign.center,
              ),
              if (search.isEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    AppButton(
                      'Agregar producto',
                      icon: Icons.add,
                      onPressed: () => context.push(AppRoutes.productNew),
                    ),
                    if (onSeed != null)
                      AppButton(
                        'Cargar productos de ejemplo',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.auto_awesome_outlined,
                        onPressed: onSeed,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
