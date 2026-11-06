import '../../../core/database/app_database.dart';
import '../models/business_settings.dart';

class SettingsRepository {
  Future<BusinessSettings> load() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings');
    final values = <String, String>{
      for (final row in rows)
        (row['key'] as String): (row['value'] as String),
    };

    return BusinessSettings(
      businessName: values['business_name'] ?? 'Mi negocio',
      rif: values['rif'] ?? '',
      address: values['address'] ?? '',
      phone: values['phone'] ?? '',
      rateBs: double.tryParse(values['rate_bs'] ?? '') ?? 0,
      ivaRate: double.tryParse(values['iva_rate'] ?? '') ?? 16,
      onboarded: values['onboarded'] == '1',
      rateUpdatedAt: DateTime.tryParse(values['rate_updated_at'] ?? ''),
      rateSource: values['rate_source'] ?? '',
      lastBackupAt: DateTime.tryParse(values['last_backup_at'] ?? ''),
    );
  }

  Future<void> save(BusinessSettings settings) async {
    await AppDatabase.instance.setSettings({
      'business_name': settings.businessName,
      'rif': settings.rif,
      'address': settings.address,
      'phone': settings.phone,
      'rate_bs': settings.rateBs.toString(),
      'iva_rate': settings.ivaRate.toString(),
      'onboarded': settings.onboarded ? '1' : '0',
      'rate_updated_at':
          settings.rateUpdatedAt?.toIso8601String() ?? '',
      'rate_source': settings.rateSource,
      'last_backup_at':
          settings.lastBackupAt?.toIso8601String() ?? '',
    });
  }

  Future<void> saveRate({
    required double rateBs,
    required DateTime updatedAt,
    required String source,
  }) async {
    await AppDatabase.instance.setSettings({
      'rate_bs': rateBs.toString(),
      'rate_updated_at': updatedAt.toIso8601String(),
      'rate_source': source,
    });
  }

  Future<DateTime?> lastRateUpdate() async {
    final value = await AppDatabase.instance.getSetting('rate_updated_at');
    return DateTime.tryParse(value);
  }

  Future<void> markBackupDone(DateTime date) async {
    await AppDatabase.instance.setSetting(
      'last_backup_at',
      date.toIso8601String(),
    );
  }
}
