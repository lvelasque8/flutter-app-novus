import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  ref.watch(appDatabaseProvider);
  return ProductRepository();
});

final productSearchProvider = StateProvider<String>((ref) => '');

final productsProvider = FutureProvider<List<Product>>((ref) {
  final search = ref.watch(productSearchProvider);
  return ref.watch(productRepositoryProvider).list(query: search);
});

final activeProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).list();
});

final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) {
  return ref.watch(productRepositoryProvider).getById(id);
});

final lowStockCountProvider = FutureProvider<int>((ref) {
  return ref.watch(productRepositoryProvider).lowStockCount();
});

final outOfStockCountProvider = FutureProvider<int>((ref) {
  return ref.watch(productRepositoryProvider).outOfStockCount();
});
