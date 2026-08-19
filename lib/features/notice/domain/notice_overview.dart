import 'boss_control_chapter.dart';
import 'notice_article.dart';

class NoticeOverview {
  const NoticeOverview({
    required this.rules,
    required this.priceGuides,
    required this.bossControls,
  });

  final List<NoticeArticle> rules;
  final List<NoticeArticle> priceGuides;
  final List<BossControlChapter> bossControls;

  NoticeOverview copyWith({
    List<NoticeArticle>? rules,
    List<NoticeArticle>? priceGuides,
    List<BossControlChapter>? bossControls,
  }) {
    return NoticeOverview(
      rules: rules ?? this.rules,
      priceGuides: priceGuides ?? this.priceGuides,
      bossControls: bossControls ?? this.bossControls,
    );
  }
}
