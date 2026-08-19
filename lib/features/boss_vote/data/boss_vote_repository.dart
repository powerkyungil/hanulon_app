import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../domain/manual_vote_input.dart';
import '../domain/vote_boss.dart';
import '../domain/vote_participant.dart';

abstract interface class BossVoteRepository {
  Future<List<VoteBoss>> fetchVoteBosses();

  Future<void> createManualVote(ManualVoteInput input);

  Future<bool> toggleParticipation(VoteBoss voteBoss);
}

class ApiBossVoteRepository implements BossVoteRepository {
  const ApiBossVoteRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<VoteBoss>> fetchVoteBosses() {
    return _apiClient.get<List<VoteBoss>>(
      ApiPaths.voteBosses,
      decode: (data) => _listPayload(data).map((value) {
        final json = _asJson(value);
        return VoteBoss(
          id: _optionalInt(json['id']),
          voteKey: json['voteKey'] as String? ?? '',
          type: json['type'] as String? ?? '공통',
          region: json['region'] as String? ?? '공통',
          boss: json['boss'] as String? ?? '알 수 없는 보스',
          spawnTime: _requiredInt(json['spawnTime']),
          participants: _participants(json['participants']),
          joined: json['joined'] == true,
          isClosed: json['isClosed'] == true,
          isBlessed: json['isBlessed'] == true,
          isManual: json['isManual'] == true,
          isHistory: json['isHistory'] == true,
        );
      }).toList()..sort((a, b) => a.spawnTime.compareTo(b.spawnTime)),
    );
  }

  @override
  Future<void> createManualVote(ManualVoteInput input) {
    return _apiClient.post<void>(
      ApiPaths.voteBossesManual,
      data: input.toJson(),
      decode: (_) {},
    );
  }

  @override
  Future<bool> toggleParticipation(VoteBoss voteBoss) {
    return _apiClient.put<bool>(
      ApiPaths.voteParticipation(voteBoss.voteKey),
      data: <String, dynamic>{
        'boss': voteBoss.boss,
        'spawnTime': voteBoss.spawnTime,
      },
      decode: (data) {
        final json = _asJson(data);
        final payload = json['data'];
        final response = payload is Map<String, dynamic> ? payload : json;
        return response['joined'] == true;
      },
    );
  }

  static List<dynamic> _listPayload(Object? data) {
    if (data is List<dynamic>) return data;
    if (data is Map<String, dynamic> && data['data'] is List<dynamic>) {
      return data['data'] as List<dynamic>;
    }
    throw const FormatException('투표 목록 형식이 올바르지 않습니다.');
  }

  static List<VoteParticipant> _participants(Object? value) {
    if (value is! List<dynamic>) return const <VoteParticipant>[];
    return value.map((item) {
      final json = _asJson(item);
      return VoteParticipant(
        userId: _requiredInt(json['userId']),
        nickname: json['nickname'] as String? ?? '알 수 없음',
      );
    }).toList();
  }

  static Map<String, dynamic> _asJson(Object? data) {
    if (data case final Map<String, dynamic> json) return json;
    throw const FormatException('서버 응답 형식이 올바르지 않습니다.');
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
}

final bossVoteRepositoryProvider = Provider<BossVoteRepository>((ref) {
  return ApiBossVoteRepository(ref.watch(apiClientProvider));
});
