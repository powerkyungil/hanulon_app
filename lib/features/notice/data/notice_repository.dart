import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../domain/boss_control_chapter.dart';
import '../domain/notice_article.dart';
import '../domain/notice_overview.dart';

abstract interface class NoticeRepository {
  Future<NoticeOverview> fetchOverview();

  Future<void> createArticle(NoticeArticleType type, NoticeArticleInput input);

  Future<void> updateArticle(
    NoticeArticleType type,
    int id,
    NoticeArticleInput input,
  );

  Future<void> deleteArticle(NoticeArticleType type, int id);

  Future<void> reorderRules(List<int> ids);

  Future<void> updateBossControl({
    required String chapter,
    required String boss,
    required String status,
  });
}

class ApiNoticeRepository implements NoticeRepository {
  const ApiNoticeRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<NoticeOverview> fetchOverview() async {
    final responses = await Future.wait<Object>(<Future<Object>>[
      _apiClient.get<List<NoticeArticle>>(
        ApiPaths.noticeRules,
        decode: _decodeArticles,
      ),
      _apiClient.get<List<NoticeArticle>>(
        ApiPaths.noticePriceGuides,
        decode: _decodeArticles,
      ),
      _apiClient.get<List<BossControlChapter>>(
        ApiPaths.noticeBossControls,
        decode: _decodeBossControls,
      ),
    ]);
    return NoticeOverview(
      rules: responses[0] as List<NoticeArticle>,
      priceGuides: responses[1] as List<NoticeArticle>,
      bossControls: responses[2] as List<BossControlChapter>,
    );
  }

  @override
  Future<void> createArticle(NoticeArticleType type, NoticeArticleInput input) {
    return _apiClient.post<void>(
      _collectionPath(type),
      data: input.toJson(),
      decode: (_) {},
    );
  }

  @override
  Future<void> updateArticle(
    NoticeArticleType type,
    int id,
    NoticeArticleInput input,
  ) {
    return _apiClient.put<void>(
      _articlePath(type, id),
      data: input.toJson(),
      decode: (_) {},
    );
  }

  @override
  Future<void> deleteArticle(NoticeArticleType type, int id) {
    return _apiClient.delete<void>(_articlePath(type, id), decode: (_) {});
  }

  @override
  Future<void> reorderRules(List<int> ids) {
    return _apiClient.put<void>(
      ApiPaths.noticeRuleOrder,
      data: <String, List<int>>{'ids': ids},
      decode: (_) {},
    );
  }

  @override
  Future<void> updateBossControl({
    required String chapter,
    required String boss,
    required String status,
  }) {
    return _apiClient.put<void>(
      ApiPaths.noticeBossControls,
      data: <String, String>{
        'chapter': chapter,
        'boss': boss,
        'status': status,
      },
      decode: (_) {},
    );
  }

  static String _collectionPath(NoticeArticleType type) {
    return switch (type) {
      NoticeArticleType.rule => ApiPaths.noticeRules,
      NoticeArticleType.priceGuide => ApiPaths.noticePriceGuides,
    };
  }

  static String _articlePath(NoticeArticleType type, int id) {
    return switch (type) {
      NoticeArticleType.rule => ApiPaths.noticeRule(id),
      NoticeArticleType.priceGuide => ApiPaths.noticePriceGuide(id),
    };
  }

  static List<NoticeArticle> _decodeArticles(Object? data) {
    final payload = _payload(data);
    if (payload is! List<dynamic>) return const <NoticeArticle>[];
    return payload.map((value) {
      final json = _asJson(value);
      return NoticeArticle(
        id: _requiredInt(json['id']),
        title: json['title'] as String? ?? '제목 없음',
        content: json['content'] as String? ?? '',
        color: json['color'] as String? ?? '#4F6EF7',
        updatedAt: _dateTime(json['updatedAt'] ?? json['updated_at']),
        sortOrder: _int(json['sortOrder'] ?? json['sort_order']),
      );
    }).toList();
  }

  static List<BossControlChapter> _decodeBossControls(Object? data) {
    final chapters = _asJson(_payload(data))['chapters'];
    if (chapters is! List<dynamic>) return const <BossControlChapter>[];
    return chapters.map((value) {
      final json = _asJson(value);
      final bosses = json['bosses'];
      return BossControlChapter(
        chapter: json['chapter'] as String? ?? '기타',
        bosses: bosses is List<dynamic>
            ? bosses.map((bossValue) {
                final boss = _asJson(bossValue);
                return BossControl(
                  name: boss['name'] as String? ?? '알 수 없음',
                  status: boss['status'] as String? ?? 'NONE',
                );
              }).toList()
            : const <BossControl>[],
      );
    }).toList();
  }

  static Map<String, dynamic> _asJson(Object? data) {
    if (data case final Map<String, dynamic> json) return json;
    throw const FormatException('공지 응답 형식이 올바르지 않습니다.');
  }

  static Object? _payload(Object? data) {
    if (data case final Map<String, dynamic> json
        when json.containsKey('data')) {
      return json['data'];
    }
    return data;
  }

  static int _requiredInt(Object? value) {
    if (value is int) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    throw const FormatException('공지 ID가 없습니다.');
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _dateTime(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is! String || value.trim().isEmpty) return null;
    final raw = value.trim();
    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final hasTimeZone =
        normalized.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(normalized);
    return DateTime.tryParse(
      hasTimeZone ? normalized : '${normalized}Z',
    )?.toUtc();
  }
}

final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return ApiNoticeRepository(ref.watch(apiClientProvider));
});
