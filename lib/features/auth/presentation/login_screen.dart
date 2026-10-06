import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/storage/preference_storage.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/privacy_policy_button.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _saveUsername = false;
  bool _autoLogin = true;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadPreferences);
  }

  Future<void> _loadPreferences() async {
    final storage = ref.read(preferenceStorageProvider);
    final values = await Future.wait<Object?>(<Future<Object?>>[
      storage.readSavedUsername(),
      storage.readSaveUsername(),
      storage.readAutoLogin(),
    ]);
    if (!mounted) return;
    setState(() {
      _usernameController.text = values[0] as String? ?? '';
      _saveUsername = values[1] as bool;
      _autoLogin = values[2] as bool;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      await ref
          .read(authControllerProvider.notifier)
          .login(
            username: username,
            password: _passwordController.text,
            autoLogin: _autoLogin,
          );
      await ref
          .read(preferenceStorageProvider)
          .saveLoginPreferences(
            username: username,
            saveUsername: _saveUsername,
            autoLogin: _autoLogin,
          );

      if (!mounted) return;
      context.go('/home');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      if (error.type == ApiErrorType.unauthorized) {
        return '아이디 또는 비밀번호를 확인해 주세요.';
      }
      return error.message;
    }
    if (error is FormatException) return error.message;
    return '로그인 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Align(
                          alignment: Alignment.centerRight,
                          child: _LoginThemeToggle(),
                        ),
                        const SizedBox(height: AppSpacing.space2),
                        const _LoginBrand(),
                        const SizedBox(height: AppSpacing.space6),
                        AppCard(
                          emphasized: true,
                          padding: const EdgeInsets.all(AppSpacing.space6),
                          child: AutofillGroup(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  const Text(
                                    '로그인',
                                    style: AppTextStyles.sectionTitle,
                                  ),
                                  const SizedBox(height: AppSpacing.space1),
                                  Text(
                                    '한울ON 길드 계정으로 계속해 주세요.',
                                    style: AppTextStyles.label.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.space6),
                                  AppTextField(
                                    label: '아이디',
                                    controller: _usernameController,
                                    hintText: '아이디를 입력해 주세요',
                                    prefixIcon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const <String>[
                                      AutofillHints.username,
                                    ],
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
                                    autofillHints: const <String>[
                                      AutofillHints.password,
                                    ],
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
                                  Wrap(
                                    spacing: AppSpacing.space3,
                                    runSpacing: AppSpacing.space1,
                                    children: <Widget>[
                                      _LoginOption(
                                        label: '아이디 저장',
                                        value: _saveUsername,
                                        onChanged: (value) {
                                          setState(() => _saveUsername = value);
                                        },
                                      ),
                                      _LoginOption(
                                        label: '자동 로그인',
                                        value: _autoLogin,
                                        onChanged: (value) {
                                          setState(() => _autoLogin = value);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.space5),
                                  AppButton(
                                    label: '로그인',
                                    onPressed: _submit,
                                    isBusy: _isBusy,
                                    expand: true,
                                  ),
                                  const SizedBox(height: AppSpacing.space2),
                                  TextButton.icon(
                                    onPressed: () => context.push('/register'),
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    ),
                                    label: const Text('처음이신가요? 회원가입'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        context.push('/deputy-login'),
                                    icon: const Icon(Icons.badge_outlined),
                                    label: const Text('부주 계정으로 로그인'),
                                  ),
                                  const PrivacyPolicyButton(),
                                ],
                              ),
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

class _LoginBrand extends StatelessWidget {
  const _LoginBrand();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;

    return Column(
      children: <Widget>[
        Semantics(
          image: true,
          label: '한울ON 앱 아이콘',
          child: Container(
            key: const ValueKey<String>('login-app-icon'),
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadii.sheet),
              border: Border.all(color: palette.cardBorder),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        Text.rich(
          key: const ValueKey<String>('login-brand-name'),
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '한울',
                style: AppTextStyles.display.copyWith(color: scheme.onSurface),
              ),
              TextSpan(
                text: 'ON',
                style: AppTextStyles.display.copyWith(color: scheme.primary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space1),
        Text(
          '길드의 일정과 참여를 한눈에',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LoginThemeToggle extends ConsumerWidget {
  const _LoginThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant =
        ref.watch(themeControllerProvider).value ?? AppThemeVariant.iconPurple;
    final next = switch (variant) {
      AppThemeVariant.iconPurple => AppThemeVariant.sandGold,
      AppThemeVariant.sandGold => AppThemeVariant.darkBlue,
      AppThemeVariant.darkBlue => AppThemeVariant.iconPurple,
    };
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;

    return Tooltip(
      message: '${next.label} 테마로 변경',
      child: IconButton.filledTonal(
        onPressed: () =>
            ref.read(themeControllerProvider.notifier).setVariant(next),
        icon: const Icon(Icons.palette_outlined),
        style: IconButton.styleFrom(
          backgroundColor: palette.primarySoft,
          foregroundColor: scheme.primary,
        ),
      ),
    );
  }
}

class _LoginOption extends StatelessWidget {
  const _LoginOption({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 32,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
