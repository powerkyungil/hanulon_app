import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../auth/domain/alternate_character.dart';
import '../../auth/domain/character_options.dart';
import '../../auth/domain/user_role.dart';
import '../domain/guild_member.dart';
import '../domain/member_equipment.dart';

abstract interface class MemberRepository {
  Future<List<GuildMember>> fetchMembers();

  Future<void> changeRole(int memberId, UserRole role);

  Future<void> transferGuildMaster(int memberId);

  Future<void> resetPassword(int memberId);

  Future<void> removeMember(int memberId);
}

class ApiMemberRepository implements MemberRepository {
  const ApiMemberRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<GuildMember>> fetchMembers() {
    return _apiClient.get<List<GuildMember>>(
      ApiPaths.members,
      decode: (data) {
        return _memberList(data)
            .map(_decodeMember)
            .where((member) => member.nickname.trim().isNotEmpty)
            .toList();
      },
    );
  }

  @override
  Future<void> changeRole(int memberId, UserRole role) {
    if (role != UserRole.member && role != UserRole.admin) {
      throw ArgumentError.value(role, 'role', '변경할 수 없는 역할입니다.');
    }
    return _apiClient.put<void>(
      ApiPaths.memberRole(memberId),
      data: <String, String>{'role': role.apiValue},
      decode: (_) {},
    );
  }

  @override
  Future<void> transferGuildMaster(int memberId) {
    if (memberId <= 0) {
      throw ArgumentError.value(memberId, 'memberId', '위임할 길드원이 올바르지 않습니다.');
    }
    return _apiClient.put<void>(
      ApiPaths.transferGuildMaster,
      data: <String, int>{'targetUserId': memberId},
      decode: (_) {},
    );
  }

  @override
  Future<void> resetPassword(int memberId) {
    return _apiClient.put<void>(
      ApiPaths.memberPasswordReset(memberId),
      decode: (_) {},
    );
  }

  @override
  Future<void> removeMember(int memberId) {
    return _apiClient.delete<void>(ApiPaths.member(memberId), decode: (_) {});
  }

  static GuildMember _decodeMember(dynamic data) {
    final json = _asJson(data);
    final equipmentJson = _jsonMap(json['equipment']);
    final skillsJson = _jsonMap(json['skills']);
    return GuildMember(
      id: _int(json['id']),
      role: UserRole.fromApi(json['role']?.toString()),
      nickname: json['nickname']?.toString() ?? '',
      occupation: json['occupation']?.toString() ?? '',
      mainClass: _string(json, 'mainClass', 'main_class'),
      combatPower: _int(_value(json, 'combatPower', 'combat_power')),
      maxCritRate: _double(_value(json, 'maxCritRate', 'max_crit_rate')),
      maxCritResist: _double(_value(json, 'maxCritResist', 'max_crit_resist')),
      statusEffectAccuracy: _double(
        _value(json, 'statusEffectAcc', 'status_effect_acc'),
      ),
      equipment: <String, MemberEquipment>{
        for (final part in CharacterOptions.equipmentParts)
          part: _equipment(equipmentJson[part]),
      },
      activeSkills: _skills(skillsJson['active']),
      passiveSkills: _skills(skillsJson['passive']),
      alternateCharacters: _alternates(
        _value(json, 'alternateCharacters', 'alternate_characters'),
      ),
    );
  }

  static List<dynamic> _memberList(Object? value) {
    if (value is List<dynamic>) return value;
    if (value is Map<String, dynamic> && value['data'] is List<dynamic>) {
      return value['data'] as List<dynamic>;
    }
    throw const FormatException('길드원 응답 형식이 올바르지 않습니다.');
  }

  static Object? _value(
    Map<String, dynamic> json,
    String camelCaseKey,
    String legacyKey,
  ) {
    return json.containsKey(camelCaseKey)
        ? json[camelCaseKey]
        : json[legacyKey];
  }

  static String _string(
    Map<String, dynamic> json,
    String camelCaseKey,
    String legacyKey,
  ) {
    return _value(json, camelCaseKey, legacyKey)?.toString() ?? '';
  }

  static MemberEquipment _equipment(Object? value) {
    if (value is Map<String, dynamic>) {
      final grade = value['color']?.toString() ?? 'none';
      return MemberEquipment(
        value: value['val']?.toString() ?? '',
        grade: CharacterOptions.equipmentGrades.containsKey(grade)
            ? grade
            : 'none',
      );
    }
    return MemberEquipment(value: value?.toString() ?? '');
  }

  static Map<String, String> _skills(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    return <String, String>{
      for (final name in CharacterOptions.skillNames)
        name: CharacterOptions.skillLevels.contains(json[name]?.toString())
            ? json[name]!.toString()
            : 'X',
    };
  }

  static List<AlternateCharacter> _alternates(Object? value) {
    if (value is! List<dynamic>) return const <AlternateCharacter>[];
    return value.map((item) {
      final json = _asJson(item);
      return AlternateCharacter(
        id: _nullableInt(json['id']),
        characterName: _string(json, 'characterName', 'character_name'),
        mainClass: _string(json, 'mainClass', 'main_class'),
      );
    }).toList();
  }

  static Map<String, dynamic> _jsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _asJson(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('길드원 항목 형식이 올바르지 않습니다.');
  }

  static int _int(Object? value) => _nullableInt(value) ?? 0;

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return ApiMemberRepository(ref.watch(apiClientProvider));
});
