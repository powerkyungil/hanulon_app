import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/installation_storage.dart';
import '../data/push_token_repository.dart';

class PushTokenCoordinator {
  PushTokenCoordinator(this._repository, this._installationStorage);

  final PushTokenRepository _repository;
  final InstallationStorage _installationStorage;

  bool _authenticated = false;

  bool get isAuthenticated => _authenticated;

  Future<bool> registerAfterAuthentication(String? token) async {
    _authenticated = true;
    return _register(token);
  }

  Future<bool> registerRefreshedToken(String token) {
    if (!_authenticated) return Future<bool>.value(false);
    return _register(token);
  }

  Future<bool> _register(String? token) async {
    if (token == null || token.isEmpty) return false;
    try {
      final deviceId = await _installationStorage.getOrCreateDeviceId();
      await _repository.register(token: token, deviceId: deviceId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeBeforeLogout(String? token) async {
    _authenticated = false;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.delete(token: token);
    } catch (_) {
      // Logout must continue when offline or when FCM invalidated the token.
    }
  }
}

final pushTokenCoordinatorProvider = Provider<PushTokenCoordinator>(
  (ref) => PushTokenCoordinator(
    ref.watch(pushTokenRepositoryProvider),
    ref.watch(installationStorageProvider),
  ),
);
