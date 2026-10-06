import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/session.dart';
import '../../auth/domain/user_role.dart';
import '../domain/deputy_account.dart';
import '../domain/deputy_character.dart';

abstract interface class DeputyAuthRepository {
  Future<Session> login({required String username, required String password});

  Future<List<DeputyCharacter>> fetchCharacters();

  Future<DeputyCharacter?> fetchActiveCharacter();

  Future<void> updateActiveCharacter(String characterKey);

  Future<List<DeputyAccount>> fetchAccounts();

  Future<void> createAccount({
    required String username,
    required String password,
    required String nickname,
  });

  Future<void> resetPassword(int accountId, String password);

  Future<void> setActive(int accountId, bool isActive);
}

class ApiDeputyAuthRepository implements DeputyAuthRepository {
  const ApiDeputyAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Session> login({required String username, required String password}) {
    return _apiClient.post<Session>(
      ApiPaths.deputyLogin,
      data: <String, String>{'username': username, 'password': password},
      decode: (data) {
        final json = _mapPayload(data);
        final activeCharacter = _character(
          json['activeCharacter'] ?? json['active_character'],
        );
        return Session(
          accessToken: _requiredString(json, 'token'),
          userId: 0,
          username: _requiredString(json, 'username', fallback: username),
          nickname: _string(json, 'nickname'),
          role: UserRole.deputy,
          principalType: SessionPrincipalType.deputy,
          deputyId: _int(json['deputyId'] ?? json['deputy_id'] ?? json['id']),
          guildId: _nullableInt(json['guildId'] ?? json['guild_id']),
          activeCharacter: activeCharacter,
          permissions: _permissions(json['permissions']),
        );
      },
    );
  }

  @override
  Future<List<DeputyCharacter>> fetchCharacters() {
    return _apiClient.get<List<DeputyCharacter>>(
      ApiPaths.deputyCharacters,
      decode: (data) => _listPayload(
        data,
        '캐릭터 목록 형식이 올바르지 않습니다.',
      ).map(_asJson).map(DeputyCharacter.fromJson).toList(),
    );
  }

  @override
  Future<DeputyCharacter?> fetchActiveCharacter() {
    return _apiClient.get<DeputyCharacter?>(
      ApiPaths.deputyActiveCharacter,
      decode: (data) {
        final payload = _payload(data);
        if (payload == null) return null;
        if (payload is Map<String, dynamic> &&
            payload.containsKey('activeCharacter')) {
          return _character(payload['activeCharacter']);
        }
        if (payload is Map<String, dynamic> &&
            payload.containsKey('active_character')) {
          return _character(payload['active_character']);
        }
        return _character(payload);
      },
    );
  }

  @override
  Future<void> updateActiveCharacter(String characterKey) {
    return _apiClient.put<void>(
      ApiPaths.deputyActiveCharacter,
      data: <String, String>{'characterKey': characterKey},
      decode: (_) {},
    );
  }

  @override
  Future<List<DeputyAccount>> fetchAccounts() {
    return _apiClient.get<List<DeputyAccount>>(
      ApiPaths.deputyAccounts,
      decode: (data) => _listPayload(
        data,
        '부주 계정 목록 형식이 올바르지 않습니다.',
      ).map(_asJson).map(_account).toList(),
    );
  }

  @override
  Future<void> createAccount({
    required String username,
    required String password,
    required String nickname,
  }) {
    return _apiClient.post<void>(
      ApiPaths.deputyAccounts,
      data: <String, String>{
        'username': username.trim(),
        'password': password,
        'nickname': nickname.trim(),
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> resetPassword(int accountId, String password) {
    return _apiClient.put<void>(
      ApiPaths.deputyAccountPassword(accountId),
      data: <String, String>{'password': password},
      decode: (_) {},
    );
  }

  @override
  Future<void> setActive(int accountId, bool isActive) {
    return _apiClient.put<void>(
      ApiPaths.deputyAccountActive(accountId),
      data: <String, bool>{'isActive': isActive},
      decode: (_) {},
    );
  }

  static DeputyAccount _account(Map<String, dynamic> json) {
    final activeCharacter = _character(
      json['activeCharacter'] ?? json['active_character'],
    );
    return DeputyAccount(
      id: _int(json['id'] ?? json['deputyId'] ?? json['deputy_id']),
      username: _string(json, 'username'),
      nickname: _string(json, 'nickname'),
      isActive: _bool(json['isActive'] ?? json['is_active']),
      activeCharacter: activeCharacter,
      activeCharacterKey: _nullableString(
        json['activeCharacterKey'] ??
            json['active_character_key'] ??
            activeCharacter?.characterKey,
      ),
    );
  }

  static DeputyCharacter? _character(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return DeputyCharacter.fromJson(value);
  }

  static Map<String, dynamic> _mapPayload(Object? data) {
    final payload = _payload(data);
    if (payload is Map<String, dynamic>) return payload;
    throw const FormatException('부주 인증 응답 형식이 올바르지 않습니다.');
  }

  static Object? _payload(Object? data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'];
    }
    return data;
  }

  static List<dynamic> _listPayload(Object? data, String message) {
    final payload = _payload(data);
    if (payload is List<dynamic>) return payload;
    if (payload is Map<String, dynamic>) {
      final items = payload['characters'] ?? payload['accounts'];
      if (items is List<dynamic>) return items;
    }
    throw FormatException(message);
  }

  static Map<String, dynamic> _asJson(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('서버 응답 항목 형식이 올바르지 않습니다.');
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String key, {
    String? fallback,
  }) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
    throw FormatException('$key 필드가 없습니다.');
  }

  static String _string(Map<String, dynamic> json, String key) {
    return json[key]?.toString().trim() ?? '';
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value) => _nullableInt(value) ?? 0;

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static List<String> _permissions(Object? value) {
    if (value is List<dynamic>) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is Map<String, dynamic>) {
      return value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();
    }
    return const <String>[];
  }
}

final deputyAuthRepositoryProvider = Provider<DeputyAuthRepository>((ref) {
  return ApiDeputyAuthRepository(ref.watch(apiClientProvider));
});
