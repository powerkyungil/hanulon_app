import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/permissions/deputy_permission.dart';
import '../../../core/permissions/role_guard.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../application/deputy_account_controller.dart';
import '../domain/deputy_account.dart';

class DeputyAccountsScreen extends ConsumerStatefulWidget {
  const DeputyAccountsScreen({super.key});

  @override
  ConsumerState<DeputyAccountsScreen> createState() =>
      _DeputyAccountsScreenState();
}

class _DeputyAccountsScreenState extends ConsumerState<DeputyAccountsScreen> {
  final Set<String> _busyActions = <String>{};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).value;
    final role = session?.role ?? UserRole.unknown;
    if (session?.isDeputy == true || !RoleGuard.canManageDeputyAccounts(role)) {
      return Scaffold(
        appBar: AppBar(title: const Text('부주 계정 관리')),
        body: const ErrorView(
          title: '권한 안내',
          message: 'MASTER 또는 ADMIN 일반 회원만 부주 계정을 관리할 수 있습니다.',
        ),
      );
    }

    final state = ref.watch(deputyAccountControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('부주 계정 관리'),
        actions: <Widget>[
          IconButton(
            tooltip: '새로고침',
            onPressed: _busyActions.isEmpty
                ? () => ref
                      .read(deputyAccountControllerProvider.notifier)
                      .refreshAccounts()
                : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: '부주 계정 생성',
            onPressed: _busyActions.isEmpty ? _openCreateSheet : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          title: isDeputyFeatureForbidden(error) ? '권한 안내' : '문제가 발생했어요',
          message: _messageFor(error),
          onRetry: () => ref.invalidate(deputyAccountControllerProvider),
        ),
        data: _buildList,
      ),
    );
  }

  Widget _buildList(List<DeputyAccount> accounts) {
    if (accounts.isEmpty) {
      return const EmptyView(
        title: '등록된 부주 계정이 없어요',
        message: '오른쪽 위 + 버튼으로 길드 공용 계정을 만들어 보세요.',
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(deputyAccountControllerProvider.notifier).refreshAccounts(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space4,
          AppSpacing.screenHorizontal,
          AppSpacing.space8,
        ),
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.space3),
        itemBuilder: (context, index) {
          final account = accounts[index];
          return _AccountCard(
            account: account,
            busy: _busyActions.any((key) => key.startsWith('${account.id}:')),
            onResetPassword: () => _resetPassword(account),
            onToggleActive: () => _toggleActive(account),
          );
        },
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final input = await showModalBottomSheet<_DeputyAccountInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _DeputyAccountForm(),
    );
    if (input == null || !mounted) return;
    await _run('create', () async {
      await ref
          .read(deputyAccountControllerProvider.notifier)
          .createAccount(
            username: input.username,
            password: input.password,
            nickname: input.nickname,
          );
      _showMessage('부주 계정을 만들었습니다.');
    });
  }

  Future<void> _resetPassword(DeputyAccount account) async {
    final password = await _showPasswordDialog(
      title: '${account.nickname} 비밀번호 재설정',
      confirmLabel: '비밀번호 저장',
    );
    if (password == null || !mounted) return;
    await _run('${account.id}:password', () async {
      await ref
          .read(deputyAccountControllerProvider.notifier)
          .resetPassword(account.id, password);
      _showMessage('비밀번호를 재설정했습니다. 기존 부주 세션은 다시 로그인해야 할 수 있습니다.');
    });
  }

  Future<void> _toggleActive(DeputyAccount account) async {
    final next = !account.isActive;
    final confirmed = await showAppConfirmDialog(
      context,
      title: next ? '부주 계정을 활성화할까요?' : '부주 계정을 비활성화할까요?',
      message: next
          ? '${account.nickname} 계정으로 다시 로그인할 수 있습니다.'
          : '기존 세션이 무효화될 수 있습니다. 계정 삭제 대신 비활성화합니다.',
      confirmLabel: next ? '활성화' : '비활성화',
      destructive: !next,
    );
    if (!confirmed || !mounted) return;
    await _run('${account.id}:active', () async {
      await ref
          .read(deputyAccountControllerProvider.notifier)
          .setActive(account.id, next);
      _showMessage(
        next ? '부주 계정을 활성화했습니다.' : '부주 계정을 비활성화했습니다. 기존 세션은 다시 로그인해야 할 수 있습니다.',
      );
    });
  }

  Future<String?> _showPasswordDialog({
    required String title,
    required String confirmLabel,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: '새 비밀번호'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text;
              if (value.trim().isNotEmpty) Navigator.of(context).pop(value);
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busyActions.add(key));
    try {
      await action();
    } catch (error) {
      if (mounted) _showMessage(_messageFor(error), isError: true);
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? context.appPalette.danger : null,
      ),
    );
  }

  static String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return '부주 계정 요청을 처리하지 못했습니다.';
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.busy,
    required this.onResetPassword,
    required this.onToggleActive,
  });

  final DeputyAccount account;
  final bool busy;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final scheme = Theme.of(context).colorScheme;
    final character = account.activeCharacter;
    final characterKey = account.activeCharacterKey;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: palette.primarySoft,
                foregroundColor: scheme.primary,
                child: const Icon(Icons.badge_outlined),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(account.nickname, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.space1),
                    Text(account.username, style: AppTextStyles.label),
                  ],
                ),
              ),
              StatusTag(
                label: account.isActive ? '활성' : '비활성',
                foregroundColor: account.isActive
                    ? palette.success
                    : scheme.onSurfaceVariant,
                backgroundColor: account.isActive
                    ? palette.successSoft
                    : palette.surfaceSubtle,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          Text('현재 선택 캐릭터', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.space1),
          Text(
            character == null
                ? characterKey ?? '선택하지 않음'
                : '${character.displayName} · ${character.ownerNickname}',
            style: AppTextStyles.bodyStrong,
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onResetPassword,
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('비밀번호 재설정'),
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onToggleActive,
                  icon: Icon(
                    account.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  label: Text(account.isActive ? '비활성화' : '활성화'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeputyAccountInput {
  const _DeputyAccountInput({
    required this.username,
    required this.password,
    required this.nickname,
  });

  final String username;
  final String password;
  final String nickname;
}

class _DeputyAccountForm extends StatefulWidget {
  const _DeputyAccountForm();

  @override
  State<_DeputyAccountForm> createState() => _DeputyAccountFormState();
}

class _DeputyAccountFormState extends State<_DeputyAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        0,
        AppSpacing.screenHorizontal,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space5,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('부주 계정 생성', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space4),
            AppTextField(
              label: '아이디',
              controller: _username,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '아이디를 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: '표시 닉네임',
              controller: _nickname,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '표시 닉네임을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: '비밀번호',
              controller: _password,
              obscureText: true,
              validator: (value) =>
                  value == null || value.isEmpty ? '비밀번호를 입력해 주세요.' : null,
            ),
            const SizedBox(height: AppSpacing.space4),
            AppButton(
              label: '계정 만들기',
              expand: true,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                Navigator.of(context).pop(
                  _DeputyAccountInput(
                    username: _username.text.trim(),
                    password: _password.text,
                    nickname: _nickname.text.trim(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
