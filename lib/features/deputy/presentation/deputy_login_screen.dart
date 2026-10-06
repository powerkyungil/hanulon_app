import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/application/auth_controller.dart';

class DeputyLoginScreen extends ConsumerStatefulWidget {
  const DeputyLoginScreen({super.key});

  @override
  ConsumerState<DeputyLoginScreen> createState() => _DeputyLoginScreenState();
}

class _DeputyLoginScreenState extends ConsumerState<DeputyLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _autoLogin = true;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .loginAsDeputy(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            autoLogin: _autoLogin,
          );
      if (!mounted) return;
      context.go(
        session.activeCharacter == null ? '/deputy/characters' : '/home',
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      if (error.type == ApiErrorType.unauthorized) {
        return '부주 아이디 또는 비밀번호를 확인해 주세요.';
      }
      return error.message;
    }
    if (error is FormatException) return error.message;
    return '부주 로그인 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.space4,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.space8,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _DeputyBrand(palette: palette, scheme: scheme),
                        const SizedBox(height: AppSpacing.space6),
                        AppCard(
                          emphasized: true,
                          padding: const EdgeInsets.all(AppSpacing.space6),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                const Text(
                                  '부주 계정 로그인',
                                  style: AppTextStyles.sectionTitle,
                                ),
                                const SizedBox(height: AppSpacing.space1),
                                Text(
                                  '길드 공용 계정으로 참여 기능을 이용합니다.',
                                  style: AppTextStyles.label.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.space6),
                                AppTextField(
                                  label: '부주 아이디',
                                  controller: _usernameController,
                                  hintText: '부주 아이디를 입력해 주세요',
                                  prefixIcon: Icons.badge_outlined,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? '아이디를 입력해 주세요.'
                                      : null,
                                ),
                                const SizedBox(height: AppSpacing.space4),
                                AppTextField(
                                  label: '비밀번호',
                                  controller: _passwordController,
                                  hintText: '비밀번호를 입력해 주세요',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? '비밀번호를 입력해 주세요.'
                                      : null,
                                  onSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: AppSpacing.space3),
                                if (_errorMessage != null) ...<Widget>[
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTextStyles.label.copyWith(
                                        color: palette.danger,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space2),
                                ],
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('자동 로그인'),
                                  value: _autoLogin,
                                  onChanged: (value) =>
                                      setState(() => _autoLogin = value),
                                ),
                                const SizedBox(height: AppSpacing.space3),
                                AppButton(
                                  label: '부주로 로그인',
                                  onPressed: _submit,
                                  isBusy: _isBusy,
                                  expand: true,
                                ),
                                const SizedBox(height: AppSpacing.space2),
                                TextButton.icon(
                                  onPressed: () => context.go('/login'),
                                  icon: const Icon(Icons.person_outline),
                                  label: const Text('일반 회원 로그인으로 돌아가기'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeputyBrand extends StatelessWidget {
  const _DeputyBrand({required this.palette, required this.scheme});

  final AppThemePalette palette;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.sheet),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.space5),
            child: Icon(Icons.badge_rounded, size: 42, color: scheme.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Text(
          '공용 부주 계정',
          style: AppTextStyles.display.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          '선택한 캐릭터로 길드 참여를 도와요',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
