import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../shared/widgets/atoms/app_button.dart';
import '../../shared/widgets/atoms/app_text.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';
import 'admin_accounts_page.dart';
import 'admin_cash_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_inventory_page.dart';
import 'admin_sales_page.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Inicio'),
    (
      icon: Icons.receipt_long_outlined,
      selected: Icons.receipt_long,
      label: 'Ventas',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      selected: Icons.account_balance_wallet,
      label: 'Cuentas',
    ),
    (
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2,
      label: 'Inventario',
    ),
    (icon: Icons.point_of_sale_outlined, selected: Icons.point_of_sale, label: 'Caja'),
  ];

  void _refresh() => ref.invalidate(adminDataProvider);

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(adminDataProvider);

    return data.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: AppSpacing.md),
                const AppText(
                  'No se pudieron cargar los datos',
                  variant: AppTextVariant.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                AppText(
                  '$error',
                  variant: AppTextVariant.bodySmall,
                  color: AppColors.textSecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    AppButton('Reintentar', onPressed: _refresh),
                    AppButton(
                      'Salir',
                      variant: AppButtonVariant.secondary,
                      onPressed: _signOut,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      data: (value) => _buildShell(value),
    );
  }

  Widget _buildShell(AdminData data) {
    final page = _pageFor(data, _index);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        if (!wide) {
          return Scaffold(
            appBar: AppBar(
              title: Text(data.businessName),
              centerTitle: false,
              actions: [
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Salir',
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) =>
                  setState(() => _index = value),
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selected),
                    label: destination.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.surface,
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(
                        destination.selected,
                        color: AppColors.primary,
                      ),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _Header(
                      data: data,
                      onRefresh: _refresh,
                      onSignOut: _signOut,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: page,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageFor(AdminData data, int index) {
    switch (index) {
      case 1:
        return AdminSalesPage(data: data);
      case 2:
        return AdminAccountsPage(data: data);
      case 3:
        return AdminInventoryPage(data: data);
      case 4:
        return AdminCashPage(data: data);
      default:
        return AdminDashboardPage(
          data: data,
          onSeeSales: () => setState(() => _index = 1),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    required this.onRefresh,
    required this.onSignOut,
  });

  final AdminData data;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  data.businessName,
                  variant: AppTextVariant.titleLarge,
                ),
                AppText(
                  data.lastSyncAt == null
                      ? 'Sin sincronizaciones todavía'
                      : 'Última sincronización: '
                            '${Money.dateTime(data.lastSyncAt!)}',
                  variant: AppTextVariant.caption,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Salir',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}
