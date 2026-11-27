import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/sync/providers/remote_sync_providers.dart';

class NovusApp extends ConsumerStatefulWidget {
  const NovusApp({super.key});

  @override
  ConsumerState<NovusApp> createState() => _NovusAppState();
}

class _NovusAppState extends ConsumerState<NovusApp>
    with WidgetsBindingObserver {
  late final RemoteSyncController _sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync = ref.read(remoteSyncControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync.requestSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Novus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: const Locale('es', 'VE'),
      supportedLocales: const [
        Locale('es', 'VE'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
