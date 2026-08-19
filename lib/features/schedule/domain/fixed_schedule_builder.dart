import 'boss_definition.dart';
import 'boss_schedule.dart';

abstract final class FixedScheduleBuilder {
  static const _dayLabels = <int, String>{
    DateTime.monday: '월',
    DateTime.tuesday: '화',
    DateTime.wednesday: '수',
    DateTime.thursday: '목',
    DateTime.friday: '금',
    DateTime.saturday: '토',
    DateTime.sunday: '일',
  };

  static List<BossSchedule> build({
    required List<BossDefinition> definitions,
    required int nowMilliseconds,
  }) {
    final seoulNow = DateTime.fromMillisecondsSinceEpoch(
      nowMilliseconds,
      isUtc: true,
    ).add(const Duration(hours: 9));
    final schedules = <BossSchedule>[];

    for (var offset = 0; offset <= 1; offset++) {
      final date = DateTime.utc(
        seoulNow.year,
        seoulNow.month,
        seoulNow.day + offset,
      );
      final dayLabel = _dayLabels[date.weekday];
      for (final definition in definitions.where((item) => item.isFixed)) {
        if (definition.days.isNotEmpty && !definition.days.contains(dayLabel)) {
          continue;
        }
        final parts = _parseTime(definition.timeText);
        if (parts == null) continue;
        final spawnTime = DateTime.utc(
          date.year,
          date.month,
          date.day,
          parts.$1 - 9,
          parts.$2,
          parts.$3,
        ).millisecondsSinceEpoch;
        if (spawnTime <
            nowMilliseconds - const Duration(minutes: 30).inMilliseconds) {
          continue;
        }
        schedules.add(
          BossSchedule(
            id: null,
            bossDefinitionId: definition.id,
            type: '고정',
            region: definition.region,
            boss: definition.boss,
            spawnTime: spawnTime,
            isMung: false,
            isFixed: true,
          ),
        );
      }
    }
    return schedules;
  }

  static (int, int, int)? _parseTime(String? value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(value?.trim() ?? '');
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = int.tryParse(match.group(3) ?? '') ?? 0;
    if (hour > 23 || minute > 59 || second > 59) return null;
    return (hour, minute, second);
  }
}
