import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

final adminDataProvider = FutureProvider.autoDispose<AdminData>((ref) {
  return ref.watch(adminRepositoryProvider).load();
});

final adminSessionProvider = StreamProvider<Session?>((ref) async* {
  final client = Supabase.instance.client;
  yield client.auth.currentSession;
  await for (final state in client.auth.onAuthStateChange) {
    yield state.session;
  }
});
