import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notice_repository.dart';
import '../domain/notice_article.dart';
import '../domain/notice_overview.dart';

class NoticeController extends AsyncNotifier<NoticeOverview> {
  @override
  Future<NoticeOverview> build() {
    return ref.read(noticeRepositoryProvider).fetchOverview();
  }

  Future<void> refreshOverview() async {
    state = AsyncData(await ref.read(noticeRepositoryProvider).fetchOverview());
  }

  Future<void> saveArticle({
    required NoticeArticleType type,
    required NoticeArticleInput input,
    int? articleId,
  }) async {
    final repository = ref.read(noticeRepositoryProvider);
    if (articleId == null) {
      await repository.createArticle(type, input);
    } else {
      await repository.updateArticle(type, articleId, input);
    }
    await refreshOverview();
  }

  Future<void> deleteArticle(NoticeArticleType type, int id) async {
    await ref.read(noticeRepositoryProvider).deleteArticle(type, id);
    await refreshOverview();
  }

  Future<void> moveRule(int index, int offset) async {
    final current = state.value;
    if (current == null) return;
    final target = index + offset;
    if (target < 0 || target >= current.rules.length) return;

    final reordered = List<NoticeArticle>.of(current.rules);
    final rule = reordered.removeAt(index);
    reordered.insert(target, rule);
    state = AsyncData(current.copyWith(rules: reordered));

    try {
      await ref
          .read(noticeRepositoryProvider)
          .reorderRules(reordered.map((item) => item.id).toList());
      await refreshOverview();
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> cycleBossControl({
    required String chapter,
    required String boss,
    required String currentStatus,
  }) async {
    const order = <String>['NONE', 'ALLY_ONLY', 'CONTROL'];
    final currentIndex = order.indexOf(currentStatus);
    final nextStatus = order[(currentIndex < 0 ? 0 : currentIndex + 1) % 3];
    await ref
        .read(noticeRepositoryProvider)
        .updateBossControl(chapter: chapter, boss: boss, status: nextStatus);
    await refreshOverview();
  }
}

final noticeOverviewProvider =
    AsyncNotifierProvider<NoticeController, NoticeOverview>(
      NoticeController.new,
    );
