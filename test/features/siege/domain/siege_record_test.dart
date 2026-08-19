import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/siege/domain/siege_record.dart';

void main() {
  test('전체 시작 전·종료 후·사용 다이아를 계산한다', () {
    final overview = SiegeOverview(
      records: <SiegeRecord>[
        SiegeRecord(
          userId: 1,
          nickname: '프레이야',
          mainClass: '아크 메이지',
          combatPower: 150000,
          startDiamonds: 1000,
          remainingDiamonds: 400,
          updatedAt: DateTime(2026, 8, 11),
        ),
        const SiegeRecord(
          userId: 2,
          nickname: '토르',
          mainClass: '디펜더',
          combatPower: 130000,
          startDiamonds: 500,
          remainingDiamonds: 100,
          updatedAt: null,
        ),
      ],
      synchronizedAt: DateTime(2026, 8, 11),
    );

    expect(overview.totalStart, 1500);
    expect(overview.totalRemaining, 500);
    expect(overview.totalUsed, 1000);
    expect(overview.enteredCount, 1);
  });

  test('종료 후 다이아가 시작 전보다 크면 저장할 수 없다', () {
    const input = SiegeInput(startDiamonds: 100, remainingDiamonds: 120);

    expect(input.isValid, isFalse);
    expect(input.validationMessage, contains('클 수 없습니다'));
  });

  test('음수와 과도하게 큰 다이아를 거부한다', () {
    const negative = SiegeInput(startDiamonds: -1, remainingDiamonds: 0);
    const tooLarge = SiegeInput(
      startDiamonds: SiegeInput.maxDiamonds + 1,
      remainingDiamonds: 0,
    );

    expect(negative.validationMessage, contains('0 이상'));
    expect(tooLarge.validationMessage, contains('999,999,999 이하'));
  });
}
