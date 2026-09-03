import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/presentation/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('로그인 화면에 한울ON 브랜드와 앱 아이콘을 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.iconPurple,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('login-app-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('login-brand-name')),
      findsOneWidget,
    );
    expect(find.text('길드의 일정과 참여를 한눈에'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
    expect(find.text('개인정보처리방침'), findsOneWidget);
  });
}
