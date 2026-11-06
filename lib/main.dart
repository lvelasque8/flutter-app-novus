import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Abre/crea la base local antes de mostrar la aplicación.
  await AppDatabase.instance.database;

  runApp(const ProviderScope(child: NovusApp()));
}
