import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/time/server_clock.dart';
import '../domain/boss_schedule.dart';
import '../domain/boss_definition.dart';
import '../domain/fixed_schedule_builder.dart';
import '../domain/ocr_result.dart';
import '../domain/schedule_overview.dart';
import '../domain/schedule_participant.dart';

abstract interface class ScheduleRepository {
  Future<ScheduleOverview> fetchOverview();

  Future<List<BossDefinition>> fetchBossDefinitions();

  Future<void> createSchedules(List<BossSchedule> schedules);

  Future<void> saveParticipationTargets(Set<int> bossDefinitionIds);

  Future<void> createBoss(BossDefinition definition);

  Future<void> deleteBoss(int id);

  Future<void> reorderBosses(List<BossDefinition> definitions);

  Future<void> resetBosses();

  Future<List<OcrTemplate>> fetchOcrTemplates();

  Future<OcrAnalysis> analyzeScreenshot({
    required Uint8List bytes,
    required int templateId,
    required String contentType,
  });

  Future<void> cut(BossSchedule schedule);

  Future<void> mung(BossSchedule schedule);

  Future<void> deleteSchedule(int id);

  Future<void> deleteAll();

  Future<bool> toggleParticipation(BossSchedule schedule);
}

abstract interface class CharacterAwareScheduleRepository {
  Future<ScheduleOverview> fetchOverviewForCharacter({String? characterKey});

  Future<bool> toggleParticipationForCharacter(
    BossSchedule schedule, {
    String? characterKey,
  });
}

class ApiScheduleRepository
    implements ScheduleRepository, CharacterAwareScheduleRepository {
  const ApiScheduleRepository(this._apiClient, this._clock);

  final ApiClient _apiClient;
  final ServerClock _clock;

  @override
  Future<ScheduleOverview> fetchOverview() => fetchOverviewForCharacter();

  @override
  Future<ScheduleOverview> fetchOverviewForCharacter({String? characterKey}) {
    return _fetchOverview(characterKey: characterKey);
  }

  Future<ScheduleOverview> _fetchOverview({String? characterKey}) async {
    final responses = await Future.wait<Object>(<Future<Object>>[
      _apiClient.get<List<BossSchedule>>(
        ApiPaths.schedules,
        decode: _decodeSchedules,
      ),
      _apiClient.get<_ParticipationTargetResponse>(
        ApiPaths.participationTargets,
        decode: _decodeParticipationTargets,
      ),
      _apiClient.get<_ScheduleParticipantResponse>(
        ApiPaths.participants,
        decode: _decodeParticipants,
      ),
      _apiClient.get<Set<String>>(
        ApiPaths.participationStates,
        decode: _decodeStringSet,
      ),
      _apiClient.get<int>(ApiPaths.serverTime, decode: _decodeServerTime),
      _apiClient.get<List<BossDefinition>>(
        ApiPaths.customBosses,
        decode: _decodeBossDefinitions,
      ),
    ]);

    final serverTime = responses[4] as int;
    _clock.synchronize(serverEpochMilliseconds: serverTime);
    final schedules = responses[0] as List<BossSchedule>;
    final definitions = responses[5] as List<BossDefinition>;
    _resolveScheduleDefinitionIds(schedules, definitions);
    final fixedSchedules = FixedScheduleBuilder.build(
      definitions: definitions,
      nowMilliseconds: serverTime,
    );
    for (final fixed in fixedSchedules) {
      final alreadyExists = schedules.any(
        (item) =>
            item.type == fixed.type &&
            item.region == fixed.region &&
            item.boss == fixed.boss &&
            item.spawnTime == fixed.spawnTime,
      );
      if (!alreadyExists) schedules.add(fixed);
    }
    schedules.sort((a, b) => a.spawnTime.compareTo(b.spawnTime));
    final participantResponse = responses[2] as _ScheduleParticipantResponse;
    return ScheduleOverview(
      schedules: schedules,
      participationTargetBossDefinitionIds:
          (responses[1] as _ParticipationTargetResponse).resolveIds(
            definitions,
          ),
      participantsByVoteKey: participantResponse.namesByVoteKey,
      closedVoteKeys: responses[3] as Set<String>,
      synchronizedAt: _clock.now(),
      participantDetailsByVoteKey: participantResponse.detailsByVoteKey,
    );
  }

  @override
  Future<List<BossDefinition>> fetchBossDefinitions() {
    return _apiClient.get<List<BossDefinition>>(
      ApiPaths.customBosses,
      decode: _decodeBossDefinitions,
    );
  }

  @override
  Future<void> saveParticipationTargets(Set<int> bossDefinitionIds) {
    return _apiClient.put<void>(
      ApiPaths.participationTargets,
      data: <String, dynamic>{
        'bossDefinitionIds': bossDefinitionIds.toList()..sort(),
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> createBoss(BossDefinition definition) {
    return _apiClient.post<void>(
      ApiPaths.customBosses,
      data: <String, dynamic>{
        'type': definition.type,
        'region': definition.region,
        'boss': definition.boss,
        'cooldownHours': definition.cooldownHours,
        'timeText': definition.timeText,
        'days': definition.days,
        'color': definition.color,
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteBoss(int id) {
    return _apiClient.delete<void>(
      '${ApiPaths.customBosses}/$id',
      decode: (_) {},
    );
  }

  @override
  Future<void> reorderBosses(List<BossDefinition> definitions) {
    return _apiClient.put<void>(
      ApiPaths.customBossesReorder,
      data: <String, dynamic>{
        'bossIds': definitions.map((item) => item.id).toList(),
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> resetBosses() {
    return _apiClient.post<void>(ApiPaths.resetBosses, decode: (_) {});
  }

  @override
  Future<List<OcrTemplate>> fetchOcrTemplates() async {
    try {
      final response = await _apiClient.raw.get<Object?>(ApiPaths.ocrTemplates);
      final json = _asJson(response.data);
      final templates = json['templates'];
      if (templates is! List<dynamic>) return const <OcrTemplate>[];
      return templates.map((value) {
        final item = _asJson(value);
        return OcrTemplate(
          id: _requiredInt(item['id']),
          name: item['name']?.toString() ?? '템플릿',
        );
      }).toList();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<OcrAnalysis> analyzeScreenshot({
    required Uint8List bytes,
    required int templateId,
    required String contentType,
  }) async {
    try {
      final response = await _apiClient.raw.post<Object?>(
        ApiPaths.ocrBossSchedule,
        data: bytes,
        options: Options(
          contentType: contentType,
          headers: <String, String>{'X-OCR-TEMPLATE-ID': templateId.toString()},
        ),
      );
      final json = _asJson(response.data);
      final images = json['images'];
      final fields = <OcrField>[];
      if (images is List<dynamic>) {
        for (final image in images) {
          final imageJson = _asJson(image);
          final rawFields = imageJson['fields'];
          if (rawFields is! List<dynamic>) continue;
          for (final rawField in rawFields) {
            final field = _asJson(rawField);
            fields.add(
              OcrField(
                name:
                    field['name']?.toString() ??
                    field['fieldName']?.toString() ??
                    '인식 항목',
                text:
                    field['inferText']?.toString() ??
                    field['value']?.toString() ??
                    '',
              ),
            );
          }
        }
      }
      return OcrAnalysis(fields: fields);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<void> createSchedules(List<BossSchedule> schedules) {
    return _apiClient.post<void>(
      ApiPaths.schedules,
      data: <String, dynamic>{
        'schedules': schedules
            .map(
              (item) => <String, dynamic>{
                'type': item.type,
                'region': item.region,
                'boss': item.boss,
                'bossDefinitionId': item.bossDefinitionId,
                'spawnTime': item.spawnTime,
              },
            )
            .toList(),
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> cut(BossSchedule schedule) {
    return _apiClient.post<void>(
      ApiPaths.schedulesCut,
      data: <String, dynamic>{
        'type': schedule.type,
        'region': schedule.region,
        'boss': schedule.boss,
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> mung(BossSchedule schedule) {
    return _apiClient.post<void>(
      ApiPaths.schedulesMung,
      data: <String, dynamic>{
        'type': schedule.type,
        'region': schedule.region,
        'boss': schedule.boss,
        'currentSpawnTime': schedule.spawnTime,
      },
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteSchedule(int id) {
    return _apiClient.delete<void>('${ApiPaths.schedules}/$id', decode: (_) {});
  }

  @override
  Future<void> deleteAll() {
    return _apiClient.delete<void>(ApiPaths.schedulesAll, decode: (_) {});
  }

  @override
  Future<bool> toggleParticipation(BossSchedule schedule) {
    return toggleParticipationForCharacter(schedule);
  }

  @override
  Future<bool> toggleParticipationForCharacter(
    BossSchedule schedule, {
    String? characterKey,
  }) {
    return _apiClient.put<bool>(
      '${ApiPaths.participants}/${Uri.encodeComponent(schedule.boss)}',
      data: <String, dynamic>{
        'type': schedule.type,
        'region': schedule.region,
        'spawnTime': schedule.spawnTime,
        if (characterKey != null) 'characterKey': characterKey,
      },
      decode: (data) {
        final json = _asJson(data);
        final payload = json['data'];
        final response = payload is Map<String, dynamic> ? payload : json;
        return response['joined'] == true;
      },
    );
  }

  static List<BossSchedule> _decodeSchedules(Object? data) {
    return _listPayload(data, '일정 응답 형식이 올바르지 않습니다.').map((value) {
      final json = _asJson(value);
      return BossSchedule(
        id: _optionalInt(json['id']),
        bossDefinitionId: _optionalInt(
          json['bossDefinitionId'] ?? json['boss_definition_id'],
        ),
        type: json['type'] as String? ?? '공통',
        region: json['region'] as String? ?? '공통',
        boss: json['boss'] as String? ?? '알 수 없는 보스',
        spawnTime: _requiredInt(json['spawnTime']),
        isMung:
            json['isMung'] == true || _requiredInt(json['is_mung'] ?? 0) == 1,
        isFixed: json['isFixed'] == true || json['type'] == '고정',
      );
    }).toList()..sort((a, b) => a.spawnTime.compareTo(b.spawnTime));
  }

  static List<BossDefinition> _decodeBossDefinitions(Object? data) {
    return _listPayload(data, '보스 목록 형식이 올바르지 않습니다.').map((value) {
      final json = _asJson(value);
      final rawDays = json['days'];
      final days = rawDays is List<dynamic>
          ? rawDays
                .map((day) => day.toString().trim())
                .where((day) => day.isNotEmpty)
                .toList()
          : rawDays
                    ?.toString()
                    .split(',')
                    .map((day) => day.trim())
                    .where((day) => day.isNotEmpty)
                    .toList() ??
                const <String>[];
      return BossDefinition(
        id: _requiredInt(json['id']),
        type: json['type'] as String? ?? '공통',
        region: json['region'] as String? ?? '공통',
        boss: json['boss'] as String? ?? '알 수 없는 보스',
        cooldownHours:
            _optionalDouble(json['cooldownHours'] ?? json['cooldown']) ?? 0,
        timeText: json['timeText']?.toString() ?? json['timeStr']?.toString(),
        days: days,
        color: json['color']?.toString(),
        sortOrder: _optionalInt(json['sortOrder'] ?? json['sort_order']) ?? 0,
      );
    }).toList();
  }

  static Set<String> _decodeStringSet(Object? data) {
    return _listPayload(
      data,
      '참여 상태 응답 형식이 올바르지 않습니다.',
    ).map((value) => value.toString()).toSet();
  }

  static _ParticipationTargetResponse _decodeParticipationTargets(
    Object? data,
  ) {
    final payload = _envelopeData(data);
    if (payload is List<dynamic>) {
      return _ParticipationTargetResponse.fromValues(payload);
    }
    final json = _asJson(payload);
    final values = json['bossDefinitionIds'] ?? json['bosses'];
    if (values is! List<dynamic>) {
      throw const FormatException('참여 보스 설정 응답 형식이 올바르지 않습니다.');
    }
    return _ParticipationTargetResponse.fromValues(values);
  }

  static void _resolveScheduleDefinitionIds(
    List<BossSchedule> schedules,
    List<BossDefinition> definitions,
  ) {
    for (var index = 0; index < schedules.length; index++) {
      final schedule = schedules[index];
      if (schedule.bossDefinitionId != null) continue;
      final matches = definitions
          .where(
            (definition) =>
                definition.type == schedule.type &&
                definition.region == schedule.region &&
                definition.boss == schedule.boss,
          )
          .toList();
      if (matches.length == 1) {
        schedules[index] = schedule.withBossDefinitionId(matches.single.id);
      }
    }
  }

  static _ScheduleParticipantResponse _decodeParticipants(Object? data) {
    final payload = _envelopeData(data);
    final json = _asJson(payload);
    final namesByVoteKey = <String, List<String>>{};
    final detailsByVoteKey = <String, List<ScheduleParticipant>>{};
    for (final entry in json.entries) {
      final names = <String>[];
      final details = <ScheduleParticipant>[];
      final values = entry.value is List<dynamic>
          ? entry.value as List<dynamic>
          : const <dynamic>[];
      for (final value in values) {
        if (value is Map<String, dynamic>) {
          final participant = ScheduleParticipant(
            userId: _optionalInt(value['userId'] ?? value['user_id']),
            nickname: value['nickname']?.toString() ?? '',
            characterType: _nullableString(
              value['characterType'] ?? value['character_type'],
            ),
            characterKey: _nullableString(
              value['characterKey'] ?? value['character_key'],
            ),
            characterName: _nullableString(
              value['characterName'] ??
                  value['character_name'] ??
                  value['targetCharacterName'] ??
                  value['target_character_name'],
            ),
          );
          details.add(participant);
          names.add(participant.displayName);
        } else {
          final nickname = value.toString();
          details.add(ScheduleParticipant(userId: null, nickname: nickname));
          names.add(nickname);
        }
      }
      namesByVoteKey[entry.key] = names;
      detailsByVoteKey[entry.key] = details;
    }
    return _ScheduleParticipantResponse(
      namesByVoteKey: namesByVoteKey,
      detailsByVoteKey: detailsByVoteKey,
    );
  }

  static Map<String, dynamic> _asJson(Object? data) {
    if (data case final Map<String, dynamic> json) return json;
    throw const FormatException('서버 응답 형식이 올바르지 않습니다.');
  }

  static Object? _envelopeData(Object? data) {
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return data['data'];
    }
    return data;
  }

  static List<dynamic> _listPayload(Object? data, String message) {
    final payload = _envelopeData(data);
    if (payload is List<dynamic>) return payload;
    throw FormatException(message);
  }

  static int _decodeServerTime(Object? data) {
    final json = _asJson(_envelopeData(data));
    return _requiredInt(json['epochMs'] ?? json['serverTime']);
  }

  static int _requiredInt(Object? value) {
    final parsed = _optionalInt(value);
    if (parsed != null) return parsed;
    throw const FormatException('숫자 필드가 없습니다.');
  }

  static int? _optionalInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _optionalDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _ScheduleParticipantResponse {
  const _ScheduleParticipantResponse({
    required this.namesByVoteKey,
    required this.detailsByVoteKey,
  });

  final Map<String, List<String>> namesByVoteKey;
  final Map<String, List<ScheduleParticipant>> detailsByVoteKey;
}

class _ParticipationTargetResponse {
  const _ParticipationTargetResponse({
    required this.bossDefinitionIds,
    required this.legacyBossNames,
  });

  final Set<int> bossDefinitionIds;
  final Set<String> legacyBossNames;

  factory _ParticipationTargetResponse.fromValues(List<dynamic> values) {
    final bossDefinitionIds = <int>{};
    final legacyBossNames = <String>{};
    for (final value in values) {
      if (value is int) {
        bossDefinitionIds.add(value);
        continue;
      }
      final parsed = int.tryParse(value.toString());
      if (parsed != null) {
        bossDefinitionIds.add(parsed);
      } else {
        final name = value.toString().trim();
        if (name.isNotEmpty) legacyBossNames.add(name);
      }
    }
    return _ParticipationTargetResponse(
      bossDefinitionIds: bossDefinitionIds,
      legacyBossNames: legacyBossNames,
    );
  }

  Set<int> resolveIds(List<BossDefinition> definitions) {
    final resolved = Set<int>.of(bossDefinitionIds);
    for (final name in legacyBossNames) {
      final matches = definitions.where(
        (definition) => definition.boss == name,
      );
      if (matches.length == 1) resolved.add(matches.single.id);
    }
    return resolved;
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ApiScheduleRepository(
    ref.watch(apiClientProvider),
    ref.watch(serverClockProvider),
  );
});

final bossDefinitionsProvider = FutureProvider<List<BossDefinition>>((ref) {
  return ref.watch(scheduleRepositoryProvider).fetchBossDefinitions();
});
