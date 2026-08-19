enum SupportRequestStatus {
  open('OPEN', '모집중'),
  matched('MATCHED', '매칭완료'),
  done('DONE', '완료'),
  canceled('CANCELED', '취소');

  const SupportRequestStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  factory SupportRequestStatus.fromApi(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return values.firstWhere(
      (status) => status.apiValue == normalized,
      orElse: () => SupportRequestStatus.open,
    );
  }
}

enum SupportApplicationStatus {
  applied('APPLIED'),
  selected('SELECTED');

  const SupportApplicationStatus(this.apiValue);

  final String apiValue;

  factory SupportApplicationStatus.fromApi(Object? value) {
    return value?.toString().toUpperCase() == 'SELECTED'
        ? SupportApplicationStatus.selected
        : SupportApplicationStatus.applied;
  }
}

class SupportApplication {
  const SupportApplication({
    required this.id,
    required this.requestId,
    required this.applicantId,
    required this.memo,
    required this.status,
    required this.createdAt,
    required this.nickname,
    required this.occupation,
    required this.mainClass,
    required this.combatPower,
  });

  final int id;
  final int requestId;
  final int applicantId;
  final String memo;
  final SupportApplicationStatus status;
  final DateTime? createdAt;
  final String nickname;
  final String occupation;
  final String mainClass;
  final int combatPower;

  bool get isSelected => status == SupportApplicationStatus.selected;
}

class SupportRequest {
  const SupportRequest({
    required this.id,
    required this.requesterId,
    required this.requestedTime,
    required this.memo,
    required this.status,
    required this.selectedApplicationId,
    required this.createdAt,
    required this.updatedAt,
    required this.nickname,
    required this.occupation,
    required this.mainClass,
    required this.combatPower,
    required this.applications,
  });

  final int id;
  final int requesterId;
  final String requestedTime;
  final String memo;
  final SupportRequestStatus status;
  final int? selectedApplicationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String nickname;
  final String occupation;
  final String mainClass;
  final int combatPower;
  final List<SupportApplication> applications;

  bool isRequester(int userId) => requesterId == userId;

  SupportApplication? applicationFor(int userId) {
    for (final application in applications) {
      if (application.applicantId == userId) return application;
    }
    return null;
  }

  bool hasApplied(int userId) => applicationFor(userId) != null;

  bool canApply(int userId) {
    return status == SupportRequestStatus.open &&
        !isRequester(userId) &&
        !hasApplied(userId);
  }

  bool isRelatedTo(int userId) => isRequester(userId) || hasApplied(userId);
}

class SupportOverview {
  const SupportOverview({required this.requests, required this.synchronizedAt});

  final List<SupportRequest> requests;
  final DateTime synchronizedAt;

  int countFor(SupportRequestStatus status) =>
      requests.where((request) => request.status == status).length;

  int relatedCount(int userId) =>
      requests.where((request) => request.isRelatedTo(userId)).length;
}

class SupportRequestInput {
  const SupportRequestInput({required this.requestedTime, required this.memo});

  final String requestedTime;
  final String memo;

  String? get validationMessage {
    if (requestedTime.trim().isEmpty) return '손지원 시간을 선택해 주세요.';
    if (requestedTime.trim().length > 80) return '손지원 시간은 80자 이내로 입력해 주세요.';
    if (memo.trim().length > 500) return '메모는 500자 이내로 입력해 주세요.';
    return null;
  }
}
