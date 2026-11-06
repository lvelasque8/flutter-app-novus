import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/sale_repository.dart';
import '../models/sale.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  ref.watch(appDatabaseProvider);
  return SaleRepository();
});

final salesProvider = FutureProvider<List<Sale>>((ref) {
  return ref.watch(saleRepositoryProvider).list();
});

final saleByIdProvider = FutureProvider.family<Sale?, String>((ref, id) {
  return ref.watch(saleRepositoryProvider).getById(id);
});

final todayTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(saleRepositoryProvider).todayTotal();
});

final todayCountProvider = FutureProvider<int>((ref) {
  return ref.watch(saleRepositoryProvider).todayCount();
});
