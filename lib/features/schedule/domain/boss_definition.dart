class BossDefinition {
  const BossDefinition({
    required this.id,
    required this.type,
    required this.region,
    required this.boss,
    required this.cooldownHours,
    this.timeText,
    this.days = const <String>[],
    this.color,
    this.sortOrder = 0,
  });

  final int id;
  final String type;
  final String region;
  final String boss;
  final double cooldownHours;
  final String? timeText;
  final List<String> days;
  final String? color;
  final int sortOrder;

  bool get isFixed => type == '고정';

  String get label =>
      isFixed ? '$boss · ${timeText ?? '-'} · 고정' : '$boss · $region · $type';
}
