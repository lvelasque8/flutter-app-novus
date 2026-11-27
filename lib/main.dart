import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/remote_config.dart';
import 'core/database/app_database.dart';
import 'features/sync/data/remote_sync_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Abre/crea la base local antes de mostrar la aplicación.
  await AppDatabase.instance.database;

  // El panel remoto es opcional: si falla la inicialización, la app sigue
  // funcionando con la base local.
  if (RemoteConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: RemoteConfig.supabaseUrl,
        publishableKey: RemoteConfig.supabaseKey,
      );
      RemoteClient.initialized = true;
    } catch (_) {
      // Sin conexión o configuración inválida: modo local.
    }
  }

  runApp(const ProviderScope(child: NovusApp()));
}
