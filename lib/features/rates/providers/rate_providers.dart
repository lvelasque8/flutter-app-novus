import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_providers.dart';
import '../data/exchange_rate_service.dart';

final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService();
});

/// Intenta actualizar la tasa una vez al día, sin bloquear el arranque.
final rateAutoRefreshProvider = FutureProvider<void>((ref) async {
  final settings = await ref.read(settingsProvider.future);
  final now = DateTime.now();

  if (!settings.onboarded) return;

  if (settings.rateBs > 0 &&
      settings.rateUpdatedAt != null &&
      _sameDay(settings.rateUpdatedAt!, now)) {
    return;
  }

  try {
    await ref.read(exchangeRateServiceProvider).updateRate();
    ref.invalidate(settingsProvider);
  } catch (_) {
    // Sin internet se conserva la última tasa configurada.
  }
});

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String rateSourceLabel(String source) {
  switch (source) {
    case 'bcv':
      return 'BCV';
    case 'api':
      return 'API';
    default:
      return 'manual';
  }
}
