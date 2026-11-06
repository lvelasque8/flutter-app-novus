import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reports_repository.dart';
import '../models/reports_data.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository();
});

final reportRangeProvider = StateProvider<ReportRange>((ref) {
  return ReportRange.today();
});

final reportsProvider = FutureProvider<ReportsData>((ref) {
  final range = ref.watch(reportRangeProvider);
  return ref.watch(reportsRepositoryProvider).get(range);
});
