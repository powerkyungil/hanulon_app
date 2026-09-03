import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/presentation/register_screen.dart';

void main() {
  testWidgets('코드 없는 회원가입은 새 길드 생성으로 시작하고 기존 가입도 선택할 수 있다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkBlue,
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('가입 코드'), findsNothing);
    expect(find.text('길드 이름'), findsOneWidget);

    await tester.tap(find.text('기존 길드 가입'));
    await tester.pumpAndSettle();

    expect(find.text('길드 이름'), findsNothing);
    expect(find.text('가입 코드'), findsWidgets);

    await tester.tap(find.text('새 길드 생성'));
    await tester.pumpAndSettle();

    expect(find.text('길드 이름'), findsOneWidget);
    expect(find.text('가입 코드'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('개인정보처리방침'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('개인정보처리방침'), findsOneWidget);
  });

  testWidgets('초대 코드가 있는 회원가입은 기존 길드 가입으로 시작한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkBlue,
          home: const RegisterScreen(inviteCode: 'ODIN-7K4P'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('가입 코드'), findsWidgets);
    expect(find.text('길드 이름'), findsNothing);
  });

  testWidgets('길드 생성 완료 팝업에 자동 생성된 가입 코드를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkBlue,
        home: CreatedGuildInviteDialog(
          inviteCode: 'A1B2C3',
          onCopy: () {},
          onContinue: () {},
        ),
      ),
    );

    expect(find.text('길드가 생성되었습니다'), findsOneWidget);
    expect(find.text('A1B2C3'), findsOneWidget);
    expect(find.text('코드 복사'), findsOneWidget);
    expect(find.text('로그인하기'), findsOneWidget);
  });
}
