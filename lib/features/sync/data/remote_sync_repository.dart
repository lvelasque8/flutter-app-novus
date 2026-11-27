import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/remote_config.dart';
import '../../../core/database/app_database.dart';
import '../../settings/data/settings_repository.dart';

/// Cliente de Supabase. Queda nulo si la app arrancó sin conexión o sin
/// configuración, para que el resto del sistema siga funcionando local.
class RemoteClient {
  RemoteClient._();

  static bool initialized = false;

  static SupabaseClient? get client {
    if (!initialized || !RemoteConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Intenta inicializar Supabase si la app arrancó sin conexión.
  static Future<bool> ensureInitialized() async {
    if (!RemoteConfig.isConfigured) return false;
    if (initialized && client != null) return true;
    try {
      await Supabase.initialize(
        url: RemoteConfig.supabaseUrl,
        publishableKey: RemoteConfig.supabaseKey,
      );
      initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient requireClient() {
    final value = client;
    if (value == null) {
      throw Exception('La sincronización remota no está disponible');
    }
    return value;
  }
}

class RemoteSyncResult {
  const RemoteSyncResult({
    required this.uploaded,
    required this.pending,
    required this.at,
  });

  final int uploaded;
  final int pending;
  final DateTime at;
}

/// Sube los cambios locales a Supabase.
///
/// Solo se envían las filas marcadas por los triggers de [AppDatabase], así
/// que una sincronización normal mueve pocos kilobytes.
class RemoteSyncRepository {
  static const _uuid = Uuid();
  static const _batch = 200;
  static const _maxRounds = 40;

  /// Orden de subida: primero catálogos y ventas, luego sus dependencias.
  static const List<String> _entities = [
    'products',
    'customers',
    'cash_sessions',
    'sales',
    'sale_items',
    'payments',
    'inventory_movements',
    'accounts',
    'account_payments',
    'sale_returns',
    'sale_return_items',
  ];

  bool get hasSession => RemoteClient.client?.auth.currentSession != null;

  String? get email => RemoteClient.client?.auth.currentUser?.email;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final client = RemoteClient.requireClient();
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await AppDatabase.instance.setSetting('remote_business_id', '');
  }

  Future<void> signOut() async {
    await RemoteClient.client?.auth.signOut();
    await AppDatabase.instance.setSetting('remote_business_id', '');
  }

  Future<DateTime?> lastSyncAt() async {
    final value = await AppDatabase.instance.getSetting('remote_last_sync_at');
    return DateTime.tryParse(value);
  }

  Future<int> pendingCount() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM sync_queue',
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<String> resolveBusinessId() async {
    final cached = await AppDatabase.instance.getSetting('remote_business_id');
    if (cached.isNotEmpty) return cached;

    final client = RemoteClient.requireClient();
    final settings = await SettingsRepository().load();
    final result = await client.rpc<dynamic>(
      'ensure_business',
      params: {'p_name': settings.businessName},
    );
    if (result == null) {
      throw Exception('No se pudo preparar el negocio en el panel');
    }
    final id = result.toString();
    await AppDatabase.instance.setSetting('remote_business_id', id);
    return id;
  }

  Future<RemoteSyncResult> syncNow() async {
    final client = RemoteClient.requireClient();
    if (client.auth.currentSession == null) {
      throw Exception('Inicia sesión para sincronizar');
    }

    final businessId = await resolveBusinessId();
    var uploaded = 0;

    await _uploadSettings(businessId);
    for (final entity in _entities) {
      uploaded += await _drainEntity(entity, businessId);
    }

    final pending = await pendingCount();
    final now = DateTime.now();
    await client.from('sync_devices').upsert({
      'business_id': businessId,
      'device_id': await _deviceId(),
      'app_version': '1.0.0',
      'last_sync_at': now.toUtc().toIso8601String(),
      'pending': pending,
    });

    await AppDatabase.instance.setSetting(
      'remote_last_sync_at',
      now.toIso8601String(),
    );
    await AppDatabase.instance.setSetting(
      'remote_last_pending',
      pending.toString(),
    );

    return RemoteSyncResult(uploaded: uploaded, pending: pending, at: now);
  }

  Future<void> _uploadSettings(String businessId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settings');
    if (rows.isEmpty) return;

    await RemoteClient.requireClient().from('business_settings').upsert([
      for (final row in rows)
        {
          'business_id': businessId,
          'key': row['key'],
          'value': row['value'],
        },
    ]);
  }

  Future<int> _drainEntity(String entity, String businessId) async {
    final db = await AppDatabase.instance.database;
    final client = RemoteClient.requireClient();
    var uploaded = 0;

    for (var round = 0; round < _maxRounds; round++) {
      final queued = await db.query(
        'sync_queue',
        where: 'entity = ?',
        whereArgs: [entity],
        orderBy: 'changed_at ASC',
        limit: _batch,
      );
      if (queued.isEmpty) break;

      final upsertIds = <String>[];
      final deleteIds = <String>[];
      for (final row in queued) {
        final id = row['row_id'] as String;
        if ((row['op'] as String?) == 'delete') {
          deleteIds.add(id);
        } else {
          upsertIds.add(id);
        }
      }

      if (upsertIds.isNotEmpty) {
        final placeholders = List.filled(upsertIds.length, '?').join(',');
        final data = await db.query(
          entity,
          where: 'id IN ($placeholders)',
          whereArgs: upsertIds,
        );
        if (data.isNotEmpty) {
          final payload = [
            for (final row in data)
              {...row, 'business_id': businessId},
          ];
          await client.from(entity).upsert(payload);
          uploaded += payload.length;
        }
      }

      if (deleteIds.isNotEmpty) {
        for (var start = 0; start < deleteIds.length; start += 80) {
          final end = start + 80 < deleteIds.length
              ? start + 80
              : deleteIds.length;
          await client
              .from(entity)
              .delete()
              .eq('business_id', businessId)
              .inFilter('id', deleteIds.sublist(start, end));
        }
      }

      await db.transaction((txn) async {
        for (final row in queued) {
          await txn.delete(
            'sync_queue',
            where: 'entity = ? AND row_id = ? AND changed_at = ?',
            whereArgs: [row['entity'], row['row_id'], row['changed_at']],
          );
        }
      });

      if (queued.length < _batch) break;
    }

    return uploaded;
  }

  Future<String> _deviceId() async {
    final stored = await AppDatabase.instance.getSetting('remote_device_id');
    if (stored.isNotEmpty) return stored;
    final id = _uuid.v4();
    await AppDatabase.instance.setSetting('remote_device_id', id);
    return id;
  }
}
