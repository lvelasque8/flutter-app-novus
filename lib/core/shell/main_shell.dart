import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../features/accounts/pages/accounts_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/products/pages/inventory_page.dart';
import '../../features/sales/pages/pos_page.dart';
import '../../features/sales/pages/sales_history_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = [
    'Inicio',
    'Vender',
    'Inventario',
    'Cuentas por cobrar',
    'Ventas',
  ];

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Inicio'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: Text('Vender'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: Text('Inventario'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: Text('Cuentas'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: Text('Ventas'),
    ),
  ];

  static const _bottomItems = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: 'Vender',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Inventario',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Cuentas',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'Ventas',
    ),
  ];

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 900;

    final body = IndexedStack(
      index: _index,
      children: [
        DashboardPage(
          onSell: () => _select(1),
          onInventory: () => _select(2),
          onAccounts: () => _select(3),
          onSales: () => _select(4),
        ),
        const POSPage(),
        const InventoryPage(),
        const AccountsPage(),
        const SalesHistoryPage(),
      ],
    );

    if (isTablet) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primaryContainer,
              selectedIconTheme: const IconThemeData(
                color: AppColors.primary,
              ),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              leading: const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: _RailLogo(),
              ),
              destinations: _destinations,
            ),
            const VerticalDivider(width: 1, color: AppColors.outlineVariant),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: _bottomItems,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(_titles[_index]),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => context.push(AppRoutes.settings),
          icon: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Text(
        'N',
        style: TextStyle(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
      ),
    );
  }
}
