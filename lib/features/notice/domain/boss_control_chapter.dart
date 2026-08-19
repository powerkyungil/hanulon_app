class BossControlChapter {
  const BossControlChapter({required this.chapter, required this.bosses});

  final String chapter;
  final List<BossControl> bosses;
}

class BossControl {
  const BossControl({required this.name, required this.status});

  final String name;
  final String status;

  String get statusLabel {
    return switch (status) {
      'CONTROL' => '통제',
      'ALLY_ONLY' => '동맹 한정',
      _ => '통제 없음',
    };
  }
}
