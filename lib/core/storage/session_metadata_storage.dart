import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/session.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/deputy/domain/deputy_character.dart';

abstract interface class SessionMetadataStorage {
  Future<Session?> read();

  Future<void> write(Session session, {required bool persist});

  Future<void> clear();
}

class SecureSessionMetadataStorage implements SessionMetadataStorage {
  SecureSessionMetadataStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth_session_metadata';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final principalType = json['principalType'] == 'DEPUTY'
          ? SessionPrincipalType.deputy
          : SessionPrincipalType.user;
      final character = json['activeCharacter'];
      return Session(
        accessToken: '',
        userId: _int(json['userId']),
        username: json['username']?.toString() ?? '',
        nickname: json['nickname']?.toString() ?? '',
        role: UserRole.fromApi(json['role']?.toString()),
        principalType: principalType,
        deputyId: _nullableInt(json['deputyId']),
        guildId: _nullableInt(json['guildId']),
        activeCharacter: character is Map<String, dynamic>
            ? DeputyCharacter.fromJson(character)
            : null,
        permissions: _strings(json['permissions']),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(Session session, {required bool persist}) async {
    if (!persist) {
      await clear();
      return;
    }
    await _storage.write(
      key: _key,
      value: jsonEncode(<String, dynamic>{
        'principalType': session.isDeputy ? 'DEPUTY' : 'USER',
        'userId': session.userId,
        'username': session.username,
        'nickname': session.nickname,
        'role': session.role.apiValue,
        'deputyId': session.deputyId,
        'guildId': session.guildId,
        'activeCharacter': session.activeCharacter?.toJson(),
        'permissions': session.permissions,
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: _key);

  static List<String> _strings(Object? value) {
    if (value is! List<dynamic>) return const <String>[];
    return value.map((item) => item.toString()).toList();
  }

  static int _int(Object? value) => _nullableInt(value) ?? 0;

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

final sessionMetadataStorageProvider = Provider<SessionMetadataStorage>((ref) {
  return SecureSessionMetadataStorage();
});
