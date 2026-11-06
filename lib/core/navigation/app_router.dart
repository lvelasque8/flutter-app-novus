import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/pages/account_detail_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/products/pages/product_form_page.dart';
import '../../features/sales/pages/sale_detail_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../shell/app_root.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String productNew = '/producto/nuevo';
  static const String productEdit = '/producto/:id';
  static const String saleDetail = '/venta/:id';
  static const String accountDetail = '/cuenta/:id';
  static const String settings = '/ajustes';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const AppRoot(),
      ),
      GoRoute(
        path: AppRoutes.productNew,
        name: 'productNew',
        builder: (context, state) => const ProductFormPage(),
      ),
      GoRoute(
        path: AppRoutes.productEdit,
        name: 'productEdit',
        builder: (context, state) => ProductFormPage(
          productId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.saleDetail,
        name: 'saleDetail',
        builder: (context, state) => SaleDetailPage(
          saleId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.accountDetail,
        name: 'accountDetail',
        builder: (context, state) => AccountDetailPage(
          customerId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/inicio',
        name: 'dashboardAlias',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
