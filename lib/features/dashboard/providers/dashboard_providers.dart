import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/models/account.dart';
import '../../accounts/providers/account_providers.dart';
import '../../products/providers/product_providers.dart';
import '../../sales/models/sale.dart';
import '../../sales/providers/sale_providers.dart';

class DashboardData {
  const DashboardData({
    required this.todayTotal,
    required this.todayCount,
    required this.lowStock,
    required this.outOfStock,
    required this.receivable,
    required this.openAccounts,
    required this.overdueCount,
    required this.overdueAmount,
    required this.dueSoonCount,
    required this.recentSales,
  });

  final double todayTotal;
  final int todayCount;
  final int lowStock;
  final int outOfStock;
  final double receivable;
  final int openAccounts;
  final int overdueCount;
  final double overdueAmount;
  final int dueSoonCount;
  final List<Sale> recentSales;
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final salesRepo = ref.watch(saleRepositoryProvider);
  final productsRepo = ref.watch(productRepositoryProvider);
  final accountsRepo = ref.watch(accountRepositoryProvider);

  final results = await Future.wait([
    salesRepo.todayTotal(),
    salesRepo.todayCount(),
    productsRepo.lowStockCount(),
    productsRepo.outOfStockCount(),
    accountsRepo.totalReceivable(),
    accountsRepo.openAccountsCount(),
    accountsRepo.listCollection(),
    salesRepo.list(limit: 5, includeCancelled: false),
  ]);

  final collection = results[6] as List<CollectionGroup>;
  final overdue = collection.where((group) => group.isOverdue).toList();

  return DashboardData(
    todayTotal: results[0] as double,
    todayCount: results[1] as int,
    lowStock: results[2] as int,
    outOfStock: results[3] as int,
    receivable: results[4] as double,
    openAccounts: results[5] as int,
    overdueCount: overdue.length,
    overdueAmount:
        overdue.fold<double>(0, (sum, group) => sum + group.balance),
    dueSoonCount: collection.where((group) => group.isDueSoon).length,
    recentSales: results[7] as List<Sale>,
  );
});
