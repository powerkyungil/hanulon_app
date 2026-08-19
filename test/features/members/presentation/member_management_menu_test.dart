import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/app_theme.dart';
import 'package:odin_guild_app/features/auth/application/auth_controller.dart';
import 'package:odin_guild_app/features/auth/domain/alternate_character.dart';
import 'package:odin_guild_app/features/auth/domain/session.dart';
import 'package:odin_guild_app/features/auth/domain/user_role.dart';
import 'package:odin_guild_app/features/members/domain/guild_member.dart';
import 'package:odin_guild_app/features/members/domain/member_equipment.dart';
import 'package:odin_guild_app/features/members/presentation/widgets/member_management_menu.dart';

void main() {
  testWidgets('길드장은 일반 길드원 메뉴에서 길드장 위임을 선택할 수 있다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_MasterAuthController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.darkBlue,
          home: const Scaffold(body: MemberManagementMenu(member: _member)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('길드원 관리'));
    await tester.pumpAndSettle();

    expect(find.text('길드장 위임'), findsOneWidget);
  });
}

class _MasterAuthController extends AuthController {
  @override
  Future<Session?> build() async {
    return const Session(
      accessToken: 'test-token',
      userId: 1,
      username: 'master',
      nickname: '길드장',
      role: UserRole.master,
    );
  }
}

const _member = GuildMember(
  id: 2,
  role: UserRole.member,
  nickname: '길드원',
  occupation: '전사',
  mainClass: '워리어',
  combatPower: 100000,
  maxCritRate: 0,
  maxCritResist: 0,
  statusEffectAccuracy: 0,
  equipment: <String, MemberEquipment>{},
  activeSkills: <String, String>{},
  passiveSkills: <String, String>{},
  alternateCharacters: <AlternateCharacter>[],
);
