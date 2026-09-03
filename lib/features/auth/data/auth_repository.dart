import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../domain/alternate_character.dart';
import '../domain/profile_update_request.dart';
import '../domain/profile_settings.dart';
import '../domain/registration_request.dart';
import '../domain/session.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

abstract interface class AuthRepository {
  Future<Session> login({required String username, required String password});

  Future<UserProfile> fetchMe();

  Future<ProfileSettings> fetchProfileSettings();

  Future<String?> register(RegistrationRequest request);

  Future<void> updateMe(ProfileUpdateRequest request);

  Future<void> deleteMe({required String password});
}

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Session> login({required String username, required String password}) {
    return _apiClient.post<Session>(
      ApiPaths.login,
      data: <String, String>{'username': username, 'password': password},
      decode: (data) {
        final json = _payloadJson(data);
        return Session(
          accessToken: _requiredString(json, 'token'),
          userId: _requiredInt(json, 'userId'),
          username: _requiredString(json, 'username'),
          nickname: json['nickname'] as String? ?? '',
          role: UserRole.fromApi(json['role'] as String?),
        );
      },
    );
  }

  @override
  Future<UserProfile> fetchMe() {
    return _apiClient.get<UserProfile>(
      ApiPaths.me,
      decode: (data) {
        final json = _asJson(data);
        return UserProfile(
          id: _requiredInt(json, 'id'),
          username: json['username'] as String?,
          role: UserRole.fromApi(json['role'] as String?),
          nickname: json['nickname'] as String? ?? '',
          occupation: json['occupation'] as String?,
          mainClass: json['main_class'] as String?,
          combatPower: _optionalInt(json['combat_power']),
          equipment: _jsonMap(json['equipment']),
          skills: _jsonMap(json['skills']),
          maxCritRate: _optionalDouble(json['max_crit_rate']) ?? 0,
          maxCritResist: _optionalDouble(json['max_crit_resist']) ?? 0,
          statusEffectAccuracy: _optionalDouble(json['status_effect_acc']) ?? 0,
          alternateCharacters: _alternateCharacters(
            json['alternate_characters'],
          ),
        );
      },
    );
  }

  @override
  Future<ProfileSettings> fetchProfileSettings() {
    return _apiClient.get<ProfileSettings>(
      ApiPaths.guildSettings,
      decode: (data) {
        final json = _payloadJson(data);
        return ProfileSettings(
          allowCombatPowerEdit: _optionalBool(
            json['allowMemberCombatPowerEdit'] ??
                json['allow_member_combat_power_edit'],
          ),
        );
      },
    );
  }

  @override
  Future<String?> register(RegistrationRequest request) {
    return _apiClient.post<String?>(
      ApiPaths.register,
      data: request.toJson(),
      decode: (data) {
        final json = _payloadJson(data);
        final inviteCode = json['inviteCode']?.toString().trim() ?? '';
        return inviteCode.isEmpty ? null : inviteCode;
      },
    );
  }

  @override
  Future<void> updateMe(ProfileUpdateRequest request) {
    return _apiClient.put<void>(
      ApiPaths.me,
      data: request.toJson(),
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteMe({required String password}) {
    return _apiClient.delete<void>(
      ApiPaths.me,
      data: <String, String>{'password': password},
      decode: (_) {},
    );
  }

  static Map<String, dynamic> _asJson(Object? data) {
    if (data case final Map<String, dynamic> json) return json;
    throw const FormatException('서버 응답 형식이 올바르지 않습니다.');
  }

  static Map<String, dynamic> _payloadJson(Object? data) {
    final json = _asJson(data);
    final payload = json['data'];
    if (payload case final Map<String, dynamic> nestedJson) {
      return nestedJson;
    }
    return json;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$key 필드가 없습니다.');
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = _optionalInt(json[key]);
    if (value != null) return value;
    throw FormatException('$key 필드가 없습니다.');
  }

  static int? _optionalInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _optionalBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static double? _optionalDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static List<AlternateCharacter> _alternateCharacters(Object? value) {
    if (value is! List<dynamic>) return const <AlternateCharacter>[];
    return value.map((item) {
      final json = _asJson(item);
      return AlternateCharacter(
        id: _optionalInt(json['id']),
        characterName: json['character_name']?.toString() ?? '',
        mainClass: json['main_class']?.toString() ?? '',
      );
    }).toList();
  }

  static Map<String, dynamic> _jsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return <String, dynamic>{};
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(ref.watch(apiClientProvider));
});
