import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme_palette.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/permissions/role_guard.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/user_role.dart';
import '../../application/members_controller.dart';
import '../../domain/guild_member.dart';

enum _MemberAction { changeRole, transferMaster, resetPassword, remove }

class MemberManagementMenu extends ConsumerStatefulWidget {
  const MemberManagementMenu({
    required this.member,
    this.popAfterRemove = false,
    super.key,
  });

  final GuildMember member;
  final bool popAfterRemove;

  @override
  ConsumerState<MemberManagementMenu> createState() =>
      _MemberManagementMenuState();
}

class _MemberManagementMenuState extends ConsumerState<MemberManagementMenu> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final currentRole = ref.watch(authControllerProvider).value?.role;
    if (currentRole == null) return const SizedBox.shrink();

    final canChangeRole =
        RoleGuard.canManageMemberRoles(currentRole) &&
        widget.member.role != UserRole.master;
    final canTransferMaster =
        RoleGuard.canTransferGuildMaster(currentRole) &&
        (widget.member.role == UserRole.member ||
            widget.member.role == UserRole.admin);
    final canResetPassword =
        RoleGuard.canResetMemberPassword(currentRole) &&
        (widget.member.role != UserRole.master ||
            currentRole == UserRole.master);
    final canRemove =
        RoleGuard.canRemoveMember(currentRole) &&
        widget.member.role != UserRole.master;
    if (!canChangeRole &&
        !canTransferMaster &&
        !canResetPassword &&
        !canRemove) {
      return const SizedBox.shrink();
    }

    if (_isBusy) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.space3),
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<_MemberAction>(
      tooltip: '길드원 관리',
      onSelected: _handleAction,
      itemBuilder: (context) => <PopupMenuEntry<_MemberAction>>[
        if (canChangeRole)
          const PopupMenuItem<_MemberAction>(
            value: _MemberAction.changeRole,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('역할 변경'),
            ),
          ),
        if (canTransferMaster)
          const PopupMenuItem<_MemberAction>(
            value: _MemberAction.transferMaster,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.workspace_premium_outlined),
              title: Text('길드장 위임'),
            ),
          ),
        if (canResetPassword)
          const PopupMenuItem<_MemberAction>(
            value: _MemberAction.resetPassword,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.password_rounded),
              title: Text('비밀번호 초기화'),
            ),
          ),
        if (canRemove)
          PopupMenuItem<_MemberAction>(
            value: _MemberAction.remove,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.appPalette.danger,
              ),
              title: Text(
                '길드에서 강퇴',
                style: TextStyle(color: context.appPalette.danger),
              ),
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert_rounded),
    );
  }

  Future<void> _handleAction(_MemberAction action) async {
    switch (action) {
      case _MemberAction.changeRole:
        await _changeRole();
      case _MemberAction.transferMaster:
        await _transferMaster();
      case _MemberAction.resetPassword:
        await _resetPassword();
      case _MemberAction.remove:
        await _removeMember();
    }
  }

  Future<void> _changeRole() async {
    final nextRole = await showModalBottomSheet<UserRole>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            AppSpacing.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('역할 변경', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '${widget.member.nickname}님의 역할을 선택해 주세요.',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: AppSpacing.space4),
              for (final role in const <UserRole>[
                UserRole.member,
                UserRole.admin,
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    role == UserRole.admin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline_rounded,
                  ),
                  title: Text(role.label),
                  subtitle: Text(
                    role == UserRole.admin
                        ? '일정과 공지 등 운영 기능을 관리합니다.'
                        : '일반 길드원 권한으로 이용합니다.',
                  ),
                  trailing: widget.member.role == role
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(role),
                ),
            ],
          ),
        ),
      ),
    );
    if (nextRole == null || nextRole == widget.member.role || !mounted) return;
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${nextRole.label}(으)로 변경할까요?',
      message: '${widget.member.nickname}님의 앱 사용 권한이 즉시 변경됩니다.',
      confirmLabel: '역할 변경',
    );
    if (!confirmed) return;
    await _run(
      () => ref
          .read(membersControllerProvider.notifier)
          .changeRole(widget.member, nextRole),
      '${widget.member.nickname}님의 역할을 변경했습니다.',
    );
  }

  Future<void> _resetPassword() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '비밀번호를 초기화할까요?',
      message:
          '${widget.member.nickname}님의 비밀번호가 1234로 변경됩니다. 로그인 후 새 비밀번호로 변경하도록 안내해 주세요.',
      confirmLabel: '1234로 초기화',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      () => ref
          .read(membersControllerProvider.notifier)
          .resetPassword(widget.member),
      '비밀번호를 1234로 초기화했습니다.',
    );
  }

  Future<void> _transferMaster() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${widget.member.nickname}님에게 길드장을 위임할까요?',
      message:
          '위임하면 ${widget.member.nickname}님이 새 길드장이 되고, 내 계정은 일반 길드원으로 변경됩니다. 길드 설정과 가입 코드 관리 권한도 함께 넘어갑니다.',
      confirmLabel: '길드장 위임',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      () => ref
          .read(membersControllerProvider.notifier)
          .transferGuildMaster(widget.member),
      '${widget.member.nickname}님에게 길드장을 위임했습니다.',
    );
  }

  Future<void> _removeMember() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '${widget.member.nickname}님을 강퇴할까요?',
      message: '캐릭터, 컬렉션, 그룹, 공성전과 참여 데이터가 영구 삭제되며 되돌릴 수 없습니다.',
      confirmLabel: '영구 강퇴',
      destructive: true,
    );
    if (!confirmed) return;
    await _run(
      () => ref
          .read(membersControllerProvider.notifier)
          .removeMember(widget.member),
      '${widget.member.nickname}님을 길드에서 강퇴했습니다.',
    );
    if (mounted && widget.popAfterRemove && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : '길드원 정보를 변경하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
