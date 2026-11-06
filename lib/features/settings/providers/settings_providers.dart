import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../data/settings_repository.dart';
import '../models/business_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  ref.watch(appDatabaseProvider);
  return SettingsRepository();
});

final settingsProvider = FutureProvider<BusinessSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).load();
});
