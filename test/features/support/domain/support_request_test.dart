import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/support/domain/support_request.dart';

void main() {
  const application = SupportApplication(
    id: 10,
    requestId: 1,
    applicantId: 8,
    memo: '',
    status: SupportApplicationStatus.applied,
    createdAt: null,
    nickname: '토르',
    occupation: '워리어',
    mainClass: '디펜더',
    combatPower: 130000,
  );
  const request = SupportRequest(
    id: 1,
    requesterId: 7,
    requestedTime: '2026-08-12 20:00~21:00',
    memo: '보스 세팅 도움',
    status: SupportRequestStatus.open,
    selectedApplicationId: null,
    createdAt: null,
    updatedAt: null,
    nickname: '프레이야',
    occupation: '소서리스',
    mainClass: '아크 메이지',
    combatPower: 142000,
    applications: <SupportApplication>[application],
  );

  test('모집중인 타인 요청에 아직 신청하지 않은 길드원만 신청할 수 있다', () {
    expect(request.canApply(9), isTrue);
    expect(request.canApply(7), isFalse);
    expect(request.canApply(8), isFalse);
  });

  test('요청자와 신청자 모두 내 활동으로 분류한다', () {
    expect(request.isRelatedTo(7), isTrue);
    expect(request.isRelatedTo(8), isTrue);
    expect(request.isRelatedTo(9), isFalse);
  });

  test('요청 시간과 메모 길이를 저장 전에 검증한다', () {
    expect(
      const SupportRequestInput(requestedTime: '', memo: '').validationMessage,
      '손지원 시간을 선택해 주세요.',
    );
    expect(
      SupportRequestInput(
        requestedTime: '2026-08-12 종일',
        memo: '가' * 501,
      ).validationMessage,
      '메모는 500자 이내로 입력해 주세요.',
    );
  });
}
