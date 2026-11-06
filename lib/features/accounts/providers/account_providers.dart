import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/account_repository.dart';
import '../models/account.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  ref.watch(appDatabaseProvider);
  return AccountRepository();
});

final accountsProvider = FutureProvider<List<AccountSummary>>((ref) {
  return ref.watch(accountRepositoryProvider).listSummaries();
});

final customersProvider = FutureProvider<List<Customer>>((ref) {
  return ref.watch(accountRepositoryProvider).listCustomers();
});

final customerByIdProvider = FutureProvider.family<Customer?, String>((
  ref,
  id,
) async {
  final customers = await ref.watch(accountRepositoryProvider).listCustomers();
  for (final customer in customers) {
    if (customer.id == id) return customer;
  }
  return null;
});

final customerAccountsProvider = FutureProvider.family<List<Account>, String>((
  ref,
  customerId,
) {
  return ref.watch(accountRepositoryProvider).accountsForCustomer(customerId);
});

final accountPaymentsProvider =
    FutureProvider.family<List<AccountPayment>, String>((ref, accountId) {
  return ref.watch(accountRepositoryProvider).paymentsForAccount(accountId);
});

final receivableTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(accountRepositoryProvider).totalReceivable();
});

final openAccountsCountProvider = FutureProvider<int>((ref) {
  return ref.watch(accountRepositoryProvider).openAccountsCount();
});
