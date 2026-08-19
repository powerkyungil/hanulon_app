import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../domain/siege_record.dart';

abstract interface class SiegeRepository {
  Future<List<SiegeRecord>> fetchRecords();

  Future<void> saveMine(SiegeInput input);

  Future<void> saveMember(int userId, SiegeInput input);

  Future<void> resetAll();
}

class ApiSiegeRepository implements SiegeRepository {
  const ApiSiegeRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<SiegeRecord>> fetchRecords() {
    return _apiClient.get<List<SiegeRecord>>(
      ApiPaths.siege,
      decode: (data) {
        final records = _listPayload(
          data,
          '공성전 현황 응답 형식이 올바르지 않습니다.',
        ).map(_decodeRecord).toList();
        records.sort((a, b) => b.combatPower.compareTo(a.combatPower));
        return records;
      },
    );
  }

  @override
  Future<void> saveMine(SiegeInput input) {
    return _apiClient.put<void>(
      ApiPaths.siegeMe,
      data: _inputJson(input),
      decode: (_) {},
    );
  }

  @override
  Future<void> saveMember(int userId, SiegeInput input) {
    return _apiClient.put<void>(
      ApiPaths.siegeMember(userId),
      data: _inputJson(input),
      decode: (_) {},
    );
  }

  @override
  Future<void> resetAll() {
    return _apiClient.delete<void>(ApiPaths.siegeAll, decode: (_) {});
  }

  static Map<String, int> _inputJson(SiegeInput input) => <String, int>{
    'currentDiamonds': input.startDiamonds,
    'remainingDiamonds': input.remainingDiamonds,
  };

  static SiegeRecord _decodeRecord(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('공성전 길드원 항목 형식이 올바르지 않습니다.');
    }
    return SiegeRecord(
      userId: _int(data['userId'] ?? data['id'] ?? data['user_id']),
      nickname: data['nickname']?.toString() ?? '',
      mainClass:
          data['mainClass']?.toString() ?? data['main_class']?.toString() ?? '',
      combatPower: _int(data['combatPower'] ?? data['combat_power']),
      startDiamonds: _int(data['currentDiamonds'] ?? data['current_diamonds']),
      remainingDiamonds: _int(
        data['remainingDiamonds'] ?? data['remaining_diamonds'],
      ),
      updatedAt: _date(data['updatedAt'] ?? data['updated_at']),
    );
  }

  static List<dynamic> _listPayload(Object? data, String message) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic> && data['data'] is List<dynamic>) {
      return data['data'] as List<dynamic>;
    }
    throw FormatException(message);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final milliseconds = int.tryParse(raw);
    if (milliseconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
    }
    return DateTime.tryParse(raw)?.toLocal();
  }
}

final siegeRepositoryProvider = Provider<SiegeRepository>((ref) {
  return ApiSiegeRepository(ref.watch(apiClientProvider));
});
