import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/user_role.dart';
import '../domain/guild_invite.dart';
import '../domain/guild_settings.dart';

abstract interface class SettingsRepository {
  Future<GuildSettings> fetchSettings();

  Future<List<GuildInvite>> fetchInvites();

  Future<void> saveSettings(GuildSettings settings);

  Future<GuildInvite> createInvite(UserRole role, {String customCode = ''});
}

class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<GuildInvite>> fetchInvites() {
    return _apiClient.get<List<GuildInvite>>(
      ApiPaths.guildInvites,
      decode: (data) {
        return _asList(data)
            .map((value) {
              final json = _asJson(value);
              final code = _firstNonEmpty(json, <String>[
                'inviteCode',
                'code',
                'inviteToken',
              ]);
              final role = UserRole.fromApi(
                (json['role'] ?? json['targetRole'])?.toString(),
              );
              if (code.isEmpty ||
                  (role != UserRole.member && role != UserRole.admin)) {
                return null;
              }
              return GuildInvite(code: code, role: role);
            })
            .whereType<GuildInvite>()
            .toList();
      },
    );
  }

  @override
  Future<GuildSettings> fetchSettings() {
    return _apiClient.get<GuildSettings>(
      ApiPaths.guildSettings,
      decode: (data) {
        final json = _asJson(data);
        return GuildSettings(
          guildName:
              json['guildName']?.toString() ??
              json['guild_name']?.toString() ??
              '오딘 길드',
          allowMemberCombatPowerEdit: _bool(
            json['allowMemberCombatPowerEdit'] ??
                json['allow_member_combat_power_edit'],
            fallback: true,
          ),
        );
      },
    );
  }

  @override
  Future<void> saveSettings(GuildSettings settings) async {
    await _apiClient.put<void>(
      ApiPaths.guildSettings,
      data: <String, dynamic>{
        'guildName': settings.guildName,
        'allowMemberCombatPowerEdit': settings.allowMemberCombatPowerEdit,
      },
      decode: (_) {},
    );
  }

  @override
  Future<GuildInvite> createInvite(UserRole role, {String customCode = ''}) {
    if (role != UserRole.member && role != UserRole.admin) {
      throw ArgumentError.value(role, 'role', '가입 코드를 관리할 수 없는 역할입니다.');
    }
    final normalizedCustomCode = customCode.trim();
    return _apiClient.post<GuildInvite>(
      ApiPaths.guildInvites,
      data: <String, dynamic>{
        'targetRole': role.apiValue,
        if (normalizedCustomCode.isNotEmpty) 'customCode': normalizedCustomCode,
      },
      decode: (data) {
        final json = _asJson(data);
        final code = _firstNonEmpty(json, <String>[
          'inviteCode',
          'code',
          // Keep reading the legacy field while the API is being migrated.
          'inviteToken',
        ]);
        if (code.isEmpty) {
          throw const FormatException('가입 코드가 없습니다.');
        }
        return GuildInvite(
          code: code,
          role: UserRole.fromApi(
            (json['role'] ?? json['targetRole'])?.toString(),
          ),
        );
      },
    );
  }

  static Map<String, dynamic> _asJson(Object? value) {
    if (value is Map<String, dynamic>) {
      final nested = value['data'];
      if (nested is Map<String, dynamic>) return nested;
      return value;
    }
    throw const FormatException('설정 응답 형식이 올바르지 않습니다.');
  }

  static List<dynamic> _asList(Object? value) {
    if (value is List<dynamic>) return value;
    if (value is Map<String, dynamic>) {
      final nested = value['data'];
      if (nested is List<dynamic>) return nested;
      final invites = value['invites'];
      if (invites is List<dynamic>) return invites;
      if (value.containsKey('inviteCode') || value.containsKey('code')) {
        return <dynamic>[value];
      }
    }
    throw const FormatException('가입 코드 응답 형식이 올바르지 않습니다.');
  }

  static String _firstNonEmpty(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static bool _bool(Object? value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return ApiSettingsRepository(ref.watch(apiClientProvider));
});
