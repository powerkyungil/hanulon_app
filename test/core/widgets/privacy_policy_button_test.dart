import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/widgets/privacy_policy_button.dart';

void main() {
  testWidgets('개인정보처리방침 버튼이 공개 페이지를 연다', (tester) async {
    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyPolicyButton(
            launch: (uri) async {
              openedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('개인정보처리방침'));
    await tester.pump();

    expect(openedUri, Uri.parse(privacyPolicyUrl));
  });

  testWidgets('플랫폼 채널 연결에 실패해도 앱이 종료되지 않고 안내한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivacyPolicyButton(
            launch: (_) async => throw Exception('channel-error'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('개인정보처리방침'));
    await tester.pumpAndSettle();

    expect(find.text('개인정보처리방침 페이지를 열지 못했습니다.'), findsOneWidget);
  });
}
