import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/data/auth_repository.dart';
import 'package:odin_guild_app/features/auth/domain/profile_settings.dart';
import 'package:odin_guild_app/features/auth/domain/profile_update_request.dart';
import 'package:odin_guild_app/features/auth/domain/registration_request.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_profile.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/auth/presentation/profile_screen.dart';

void main() {
  testWidgets('회원 탈퇴는 비밀번호와 영구 삭제 동의를 모두 요구한다', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.iconPurple,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey<String>('account-delete-button'),
    );
    await tester.scrollUntilVisible(
      deleteButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    final confirm = find.byKey(
      const ValueKey<String>('account-delete-confirm'),
    );
    expect(find.text('회원 탈퇴'), findsWidgets);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-delete-password')),
      'current-password',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-delete-acknowledge')),
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> deleteMe({required String password}) async {}

  @override
  Future<UserProfile> fetchMe() async {
    return const UserProfile(
      id: 7,
      username: 'freya',
      nickname: '프레이야',
      occupation: '워리어',
      mainClass: '디펜더',
      combatPower: 130000,
      role: UserRole.member,
    );
  }

  @override
  Future<ProfileSettings> fetchProfileSettings() async {
    return const ProfileSettings(allowCombatPowerEdit: true);
  }

  @override
  Future<Session> login({required String username, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<String?> register(RegistrationRequest request) async => null;

  @override
  Future<void> updateMe(ProfileUpdateRequest request) async {}
}
