import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> readToken();

  Future<void> writeToken(String token, {bool persist = true});

  Future<void> clearToken();
}

class SessionTokenStorage implements TokenStorage {
  SessionTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;
  String? _memoryToken;

  @override
  Future<String?> readToken() async {
    return _memoryToken ?? _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> writeToken(String token, {bool persist = true}) async {
    _memoryToken = token;
    if (persist) {
      await _storage.write(key: _accessTokenKey, value: token);
    } else {
      await _storage.delete(key: _accessTokenKey);
    }
  }

  @override
  Future<void> clearToken() async {
    _memoryToken = null;
    await _storage.delete(key: _accessTokenKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SessionTokenStorage(),
);
