class SiegeRecord {
  const SiegeRecord({
    required this.userId,
    required this.nickname,
    required this.mainClass,
    required this.combatPower,
    required this.startDiamonds,
    required this.remainingDiamonds,
    required this.updatedAt,
  });

  final int userId;
  final String nickname;
  final String mainClass;
  final int combatPower;
  final int startDiamonds;
  final int remainingDiamonds;
  final DateTime? updatedAt;

  int get usedDiamonds => startDiamonds - remainingDiamonds;

  bool get hasEntry => updatedAt != null;

  SiegeRecord copyWith({
    int? startDiamonds,
    int? remainingDiamonds,
    DateTime? updatedAt,
  }) {
    return SiegeRecord(
      userId: userId,
      nickname: nickname,
      mainClass: mainClass,
      combatPower: combatPower,
      startDiamonds: startDiamonds ?? this.startDiamonds,
      remainingDiamonds: remainingDiamonds ?? this.remainingDiamonds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SiegeOverview {
  const SiegeOverview({required this.records, required this.synchronizedAt});

  final List<SiegeRecord> records;
  final DateTime synchronizedAt;

  int get totalStart =>
      records.fold<int>(0, (total, record) => total + record.startDiamonds);

  int get totalRemaining =>
      records.fold<int>(0, (total, record) => total + record.remainingDiamonds);

  int get totalUsed => totalStart - totalRemaining;

  int get enteredCount => records.where((record) => record.hasEntry).length;

  SiegeRecord? recordFor(int userId) {
    return records.where((record) => record.userId == userId).firstOrNull;
  }
}

class SiegeInput {
  const SiegeInput({
    required this.startDiamonds,
    required this.remainingDiamonds,
  });

  static const maxDiamonds = 999999999;

  final int startDiamonds;
  final int remainingDiamonds;

  int get usedDiamonds => startDiamonds - remainingDiamonds;

  String? get validationMessage {
    if (startDiamonds < 0 || remainingDiamonds < 0) {
      return '다이아는 0 이상으로 입력해 주세요.';
    }
    if (startDiamonds > maxDiamonds || remainingDiamonds > maxDiamonds) {
      return '다이아는 999,999,999 이하로 입력해 주세요.';
    }
    if (remainingDiamonds > startDiamonds) {
      return '종료 후 다이아는 시작 전 다이아보다 클 수 없습니다.';
    }
    return null;
  }

  bool get isValid => validationMessage == null;
}
