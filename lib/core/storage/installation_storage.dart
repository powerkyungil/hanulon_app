import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

abstract interface class InstallationStorage {
  Future<String> getOrCreateDeviceId();
}

class SecureInstallationStorage implements InstallationStorage {
  SecureInstallationStorage({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage = storage ?? const FlutterSecureStorage(),
      _uuid = uuid ?? const Uuid();

  static const _deviceIdKey = 'installation_device_id';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  @override
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _uuid.v4();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }
}

final installationStorageProvider = Provider<InstallationStorage>(
  (ref) => SecureInstallationStorage(),
);
