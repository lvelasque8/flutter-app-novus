import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote_sync_repository.dart';

class RemoteSyncState {
  const RemoteSyncState({
    this.available = false,
    this.signedIn = false,
    this.email,
    this.syncing = false,
    this.lastSyncAt,
    this.pending = 0,
    this.error,
  });

  final bool available;
  final bool signedIn;
  final String? email;
  final bool syncing;
  final DateTime? lastSyncAt;
  final int pending;
  final String? error;

  RemoteSyncState copyWith({
    bool? available,
    bool? signedIn,
    String? email,
    bool? syncing,
    DateTime? lastSyncAt,
    int? pending,
    String? error,
    bool clearError = false,
  }) {
    return RemoteSyncState(
      available: available ?? this.available,
      signedIn: signedIn ?? this.signedIn,
      email: email ?? this.email,
      syncing: syncing ?? this.syncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pending: pending ?? this.pending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final remoteSyncRepositoryProvider = Provider<RemoteSyncRepository>((ref) {
  return RemoteSyncRepository();
});

final remoteSyncControllerProvider =
    StateNotifierProvider<RemoteSyncController, RemoteSyncState>((ref) {
      return RemoteSyncController(ref.watch(remoteSyncRepositoryProvider));
    });

class RemoteSyncController extends StateNotifier<RemoteSyncState> {
  RemoteSyncController(this._repository)
    : super(RemoteSyncState(available: RemoteClient.client != null)) {
    if (state.available) {
      _refresh();
    }
  }

  final RemoteSyncRepository _repository;
  Timer? _timer;
  Timer? _debounce;
  bool _busy = false;

  /// Arranca la sincronización periódica (cada 10 minutos).
  Future<void> start() async {
    if (!state.available) {
      final ok = await RemoteClient.ensureInitialized();
      if (!ok || !mounted) return;
      state = state.copyWith(available: true);
    }
    await _refresh();
    _timer ??= Timer.periodic(const Duration(minutes: 10), (_) {
      if (state.signedIn && !_busy) syncNow(silent: true);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
  }

  /// Pide una sincronización poco después de una venta o un abono.
  void requestSync() {
    if (!state.available || !state.signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () {
      if (mounted && state.signedIn && !_busy) syncNow(silent: true);
    });
  }

  Future<void> _refresh() async {
    final available = RemoteClient.client != null;
    final signedIn = available && _repository.hasSession;
    final lastSyncAt = await _repository.lastSyncAt();
    final pending = await _repository.pendingCount();
    if (!mounted) return;
    state = state.copyWith(
      available: available,
      signedIn: signedIn,
      email: _repository.email,
      lastSyncAt: lastSyncAt,
      pending: pending,
    );
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (!state.available) {
      final ok = await RemoteClient.ensureInitialized();
      if (!ok) {
        state = state.copyWith(
          error: 'Sin conexión con el panel remoto. Revisa tu internet.',
        );
        return false;
      }
      state = state.copyWith(available: true);
    }
    state = state.copyWith(syncing: true, clearError: true);
    try {
      await _repository.signIn(email: email, password: password);
      await _refresh();
      await syncNow(silent: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        syncing: false,
        error: _friendly(error),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    _timer?.cancel();
    _timer = null;
    await _repository.signOut();
    await _refresh();
  }

  Future<void> syncNow({bool silent = false}) async {
    if (_busy) return;
    if (!state.available) {
      final ok = await RemoteClient.ensureInitialized();
      if (!ok || !mounted) return;
      state = state.copyWith(available: true);
      await _refresh();
    }
    if (!state.signedIn) return;
    _busy = true;
    if (!silent) state = state.copyWith(syncing: true, clearError: true);
    try {
      final result = await _repository.syncNow();
      if (!mounted) return;
      state = state.copyWith(
        syncing: false,
        lastSyncAt: result.at,
        pending: result.pending,
        clearError: true,
      );
      if (result.pending > 0) {
        Timer(const Duration(seconds: 5), () {
          if (mounted && state.signedIn && !_busy) {
            syncNow(silent: true);
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        syncing: false,
        clearError: silent,
        error: silent ? null : _friendly(error),
      );
      if (silent) {
        state = state.copyWith(pending: await _repository.pendingCount());
      }
    } finally {
      _busy = false;
    }
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos';
    }
    if (text.contains('JWT') || text.contains('session')) {
      return 'La sesión venció. Vuelve a conectar.';
    }
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup')) {
      return 'No hay conexión a internet';
    }
    return text;
  }
}
