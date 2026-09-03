import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../application/settings_controller.dart';
import '../domain/guild_invite.dart';
import '../domain/guild_settings.dart';

class MasterSettingsScreen extends ConsumerStatefulWidget {
  const MasterSettingsScreen({super.key});

  @override
  ConsumerState<MasterSettingsScreen> createState() =>
      _MasterSettingsScreenState();
}

class _MasterSettingsScreenState extends ConsumerState<MasterSettingsScreen> {
  final _guildName = TextEditingController();
  final _customInviteCode = TextEditingController();
  bool _allowCombatPowerEdit = true;
  bool _didApplySettings = false;
  bool _didStartInviteLoad = false;
  bool _isSaving = false;
  bool _isGeneratingInvite = false;
  bool _isLoadingInvites = true;
  UserRole _inviteRole = UserRole.member;
  Map<UserRole, GuildInvite> _invitesByRole = <UserRole, GuildInvite>{};
  GuildInvite? _invite;
  String? _formError;
  String? _inviteError;

  @override
  void dispose() {
    _guildName.dispose();
    _customInviteCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!RoleGuard.canManageGuildSettings(
      session.value?.role ?? UserRole.unknown,
    )) {
      return Scaffold(
        appBar: AppBar(title: const Text('마스터 설정')),
        body: const EmptyView(
          title: '길드장 전용 메뉴예요',
          message: '길드 설정과 가입 코드 관리는 길드장만 할 수 있습니다.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('마스터 설정')),
      body: settings.when(
        loading: () => const _SettingsLoadingView(),
        error: (error, _) => ErrorView(
          message: '길드 설정을 불러오지 못했습니다.',
          onRetry: () {
            _didApplySettings = false;
            ref.invalidate(settingsControllerProvider);
          },
        ),
        data: (settings) {
          if (!_didApplySettings) {
            _guildName.text = settings.guildName;
            _allowCombatPowerEdit = settings.allowMemberCombatPowerEdit;
            _didApplySettings = true;
          }
          if (!_didStartInviteLoad) {
            _didStartInviteLoad = true;
            Future<void>.microtask(_loadInvites);
          }
          return _buildContent();
        },
      ),
    );
  }

  Widget _buildContent() {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.space2,
        AppSpacing.screenHorizontal,
        AppSpacing.space8,
      ),
      children: <Widget>[
        AppCard(
          emphasized: true,
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.space3),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: scheme.primary,
                    size: 27,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('길드 운영 설정', style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      '길드 기준과 가입 권한을 안전하게 관리하세요',
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusTag(
                label: '길드장 전용',
                foregroundColor: palette.warning,
                backgroundColor: palette.warningSoft,
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        Text('길드 기본 설정', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.space3),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                label: '길드 이름',
                controller: _guildName,
                hintText: '오딘 길드',
              ),
              const SizedBox(height: AppSpacing.space3),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space3,
                    vertical: AppSpacing.space1,
                  ),
                  title: const Text(
                    '길드원 전투력 수정 허용',
                    style: AppTextStyles.bodyStrong,
                  ),
                  subtitle: Text(
                    _allowCombatPowerEdit
                        ? '길드원이 내 정보에서 전투력을 직접 변경할 수 있습니다.'
                        : '내 정보의 전투력 입력이 잠기며 서버도 기존 값을 유지합니다.',
                    style: AppTextStyles.caption,
                  ),
                  value: _allowCombatPowerEdit,
                  onChanged: (value) {
                    setState(() => _allowCombatPowerEdit = value);
                  },
                ),
              ),
              if (_formError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  _formError!,
                  style: AppTextStyles.label.copyWith(color: palette.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.space4),
              FilledButton(
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('길드 설정 저장'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space6),
        Text('고정 가입 코드 관리', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.space3),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('가입시킬 길드원의 역할을 선택하세요', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '가입 코드는 만료되지 않고 계속 사용할 수 있습니다. 코드를 변경하면 기존 코드는 즉시 사용할 수 없게 됩니다.',
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<UserRole>(
                  segments: const <ButtonSegment<UserRole>>[
                    ButtonSegment<UserRole>(
                      value: UserRole.member,
                      icon: Icon(Icons.person_add_alt_1_outlined),
                      label: Text('일반 길드원'),
                    ),
                    ButtonSegment<UserRole>(
                      value: UserRole.admin,
                      icon: Icon(Icons.admin_panel_settings_outlined),
                      label: Text('운영진'),
                    ),
                  ],
                  selected: <UserRole>{_inviteRole},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    setState(() {
                      _inviteRole = selection.first;
                      _invite = _invitesByRole[selection.first];
                      _inviteError = null;
                      _customInviteCode.text = _invite?.code ?? '';
                    });
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              if (_isLoadingInvites) ...<Widget>[
                Text(
                  '현재 가입 코드를 불러오는 중입니다.',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
              ],
              AppTextField(
                label: '가입 코드',
                controller: _customInviteCode,
                hintText: '예: A1B2C3 · 비워두면 새 6자리 코드 생성',
                prefixIcon: Icons.edit_outlined,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                ],
                maxLength: 32,
                onChanged: (_) {
                  setState(() {
                    _invite = _hasInviteChanges
                        ? null
                        : _invitesByRole[_inviteRole];
                    _inviteError = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.space3),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSaveInvite ? _saveInvite : null,
                  icon: _isGeneratingInvite
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_inviteSaveButtonLabel),
                ),
              ),
              if (!_isLoadingInvites &&
                  _invitesByRole[_inviteRole] != null &&
                  !_hasInviteChanges) ...<Widget>[
                const SizedBox(height: AppSpacing.space2),
                Text(
                  '코드를 수정하면 저장 버튼이 활성화됩니다.',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_inviteRole == UserRole.admin) ...<Widget>[
                const SizedBox(height: AppSpacing.space3),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: palette.warning,
                        ),
                        const SizedBox(width: AppSpacing.space2),
                        Expanded(
                          child: Text(
                            '운영진은 일정과 공지 등 길드 운영 기능을 관리할 수 있습니다.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_inviteError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.space3),
                Text(
                  _inviteError!,
                  style: AppTextStyles.label.copyWith(color: palette.danger),
                ),
              ],
              if (_invite != null) ...<Widget>[
                const SizedBox(height: AppSpacing.space4),
                _InviteResult(invite: _invite!, onCopy: _copyInvite),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    final guildName = _guildName.text.trim();
    if (guildName.isEmpty) {
      setState(() => _formError = '길드 이름을 입력해 주세요.');
      return;
    }
    setState(() {
      _isSaving = true;
      _formError = null;
    });
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .save(
            GuildSettings(
              guildName: guildName,
              allowMemberCombatPowerEdit: _allowCombatPowerEdit,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('길드 설정을 저장했습니다.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadInvites() async {
    try {
      final invites = await ref
          .read(settingsControllerProvider.notifier)
          .fetchInvites();
      if (!mounted) return;
      final invitesByRole = <UserRole, GuildInvite>{
        for (final invite in invites) invite.role: invite,
      };
      setState(() {
        _invitesByRole = invitesByRole;
        _invite = invitesByRole[_inviteRole];
        _customInviteCode.text = _invite?.code ?? '';
        _isLoadingInvites = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingInvites = false;
        _inviteError = _messageFor(error);
      });
    }
  }

  bool get _hasInviteChanges {
    final currentCode = _invitesByRole[_inviteRole]?.code ?? '';
    return currentCode.toUpperCase() !=
        _customInviteCode.text.trim().toUpperCase();
  }

  bool get _canSaveInvite {
    return !_isLoadingInvites &&
        !_isGeneratingInvite &&
        (_invitesByRole[_inviteRole] == null || _hasInviteChanges);
  }

  String get _inviteSaveButtonLabel {
    if (_isGeneratingInvite) return '가입 코드 저장 중';
    if (_invitesByRole[_inviteRole] == null) {
      return '${_inviteRole.label} 가입 코드 생성';
    }
    return _hasInviteChanges ? '가입 코드 변경 저장' : '가입 코드 저장';
  }

  Future<void> _saveInvite() async {
    final customCode = _customInviteCode.text.trim();
    if (customCode.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_-]{4,32}$').hasMatch(customCode)) {
      setState(() {
        _invite = null;
        _inviteError = '커스텀 코드는 영문, 숫자, -, _ 조합으로 4~32자 입력해 주세요.';
      });
      return;
    }
    final currentCode = _invitesByRole[_inviteRole]?.code;
    if (currentCode != null &&
        currentCode.toUpperCase() != customCode.toUpperCase()) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: '가입 코드를 변경할까요?',
        message:
            '기존 코드 $currentCode는 즉시 사용할 수 없게 됩니다. 새 코드를 알고 있는 사용자만 가입할 수 있습니다.',
        confirmLabel: '코드 변경',
        destructive: true,
      );
      if (!confirmed) return;
    }
    setState(() => _isGeneratingInvite = true);
    setState(() => _inviteError = null);
    try {
      final invite = await ref
          .read(settingsControllerProvider.notifier)
          .createInvite(_inviteRole, customCode: customCode);
      if (!mounted) return;
      setState(() {
        _invitesByRole[_inviteRole] = invite;
        _invite = invite;
        _customInviteCode.text = invite.code;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가입 코드를 저장했습니다.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _inviteError = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isGeneratingInvite = false);
    }
  }

  Future<void> _copyInvite() async {
    final invite = _invite;
    if (invite == null) return;
    await Clipboard.setData(ClipboardData(text: invite.code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('가입 코드를 복사했습니다.')));
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }
}

class _InviteResult extends StatelessWidget {
  const _InviteResult({required this.invite, required this.onCopy});

  final GuildInvite invite;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.primarySoft.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('현재 가입 코드', style: AppTextStyles.bodyStrong),
                ),
                StatusTag(
                  label: invite.role.label,
                  foregroundColor: scheme.primary,
                  backgroundColor: palette.primarySoft,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            SelectableText(
              invite.code,
              style: AppTextStyles.bodyStrong.copyWith(
                color: scheme.primary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '만료 없음 · 변경 전까지 계속 사용 · 코드 입력으로 가입',
                    style: AppTextStyles.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('코드 복사'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLoadingView extends StatelessWidget {
  const _SettingsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
      children: const <Widget>[
        AppCard(child: SizedBox(height: 86)),
        SizedBox(height: AppSpacing.space4),
        AppCard(child: SizedBox(height: 250)),
        SizedBox(height: AppSpacing.space4),
        AppCard(child: SizedBox(height: 220)),
      ],
    );
  }
}
