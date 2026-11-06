import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cash_repository.dart';
import '../models/cash_session.dart';

final cashRepositoryProvider = Provider<CashRepository>((ref) {
  return CashRepository();
});

final openCashSessionProvider = FutureProvider<CashSession?>((ref) {
  return ref.watch(cashRepositoryProvider).getOpenSession();
});

final cashSummaryProvider = FutureProvider<CashSessionSummary?>((ref) async {
  final session = await ref.watch(openCashSessionProvider.future);
  if (session == null) return null;
  return ref.watch(cashRepositoryProvider).summary(session);
});

final cashHistoryProvider = FutureProvider<List<CashSession>>((ref) {
  return ref.watch(cashRepositoryProvider).history();
});
