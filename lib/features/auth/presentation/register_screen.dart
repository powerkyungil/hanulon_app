import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/widgets/privacy_policy_button.dart';
import '../data/auth_repository.dart';
import '../domain/character_options.dart';
import '../domain/registration_mode.dart';
import '../domain/registration_request.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({this.inviteCode = '', super.key});

  final String inviteCode;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCode = TextEditingController();
  final _guildName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _nickname = TextEditingController();
  final _combatPower = TextEditingController();
  late final Map<String, TextEditingController> _equipmentControllers;
  late final Map<String, String> _equipmentGrades;
  late final Map<String, String> _activeSkills;
  late final Map<String, String> _passiveSkills;

  String? _occupation;
  String? _mainClass;
  String? _errorMessage;
  RegistrationMode _registrationMode = RegistrationMode.createGuild;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _inviteCode.text = widget.inviteCode;
    _registrationMode = widget.inviteCode.trim().isEmpty
        ? RegistrationMode.createGuild
        : RegistrationMode.joinGuild;
    _equipmentControllers = <String, TextEditingController>{
      for (final part in CharacterOptions.equipmentParts)
        part: TextEditingController(),
    };
    _equipmentGrades = <String, String>{
      for (final part in CharacterOptions.equipmentParts) part: 'none',
    };
    _activeSkills = <String, String>{
      for (final name in CharacterOptions.skillNames) name: 'X',
    };
    _passiveSkills = <String, String>{
      for (final name in CharacterOptions.skillNames) name: 'X',
    };
  }

  @override
  void dispose() {
    _inviteCode.dispose();
    _guildName.dispose();
    _username.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _nickname.dispose();
    _combatPower.dispose();
    for (final controller in _equipmentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_occupation == null || _mainClass == null) {
      setState(() => _errorMessage = '직업과 주클래스를 선택해 주세요.');
      return;
    }

    final registrationMode = _registrationMode;
    FocusScope.of(context).unfocus();
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    final equipment = <String, dynamic>{
      for (final part in CharacterOptions.equipmentParts)
        part: <String, String>{
          'val': _equipmentControllers[part]!.text.trim(),
          'color': _equipmentGrades[part]!,
        },
    };
    final skills = <String, dynamic>{
      'active': _activeSkills,
      'passive': _passiveSkills,
    };

    try {
      final generatedInviteCode = await ref
          .read(authRepositoryProvider)
          .register(
            RegistrationRequest(
              mode: registrationMode,
              inviteCode: _inviteCode.text.trim(),
              guildName: _guildName.text.trim(),
              username: _username.text.trim(),
              password: _password.text,
              nickname: _nickname.text.trim(),
              occupation: _occupation!,
              mainClass: _mainClass!,
              combatPower: int.parse(_combatPower.text),
              equipment: equipment,
              skills: skills,
            ),
          );
      if (!mounted) return;
      if (registrationMode == RegistrationMode.createGuild &&
          generatedInviteCode != null) {
        await _showCreatedGuildDialog(generatedInviteCode);
        if (!mounted) return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              registrationMode == RegistrationMode.createGuild
                  ? '길드가 생성되었습니다. 마스터 계정으로 로그인해 주세요.'
                  : '가입이 완료되었습니다. 로그인해 주세요.',
            ),
          ),
        );
      }
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error, registrationMode));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showCreatedGuildDialog(String inviteCode) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CreatedGuildInviteDialog(
        inviteCode: inviteCode,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: inviteCode));
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('가입 코드를 복사했습니다.')));
        },
        onContinue: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  String _messageFor(Object error, RegistrationMode registrationMode) {
    if (error is ApiException) {
      if (error.code == 'INVITE_CODE_INVALID' ||
          error.code == 'INVALID_INVITE_CODE' ||
          error.message == 'Invalid token.') {
        if (registrationMode == RegistrationMode.createGuild) {
          return '새 길드 생성 요청이 이전 서버로 전송되었습니다. 앱의 API 주소를 최신 길드 API로 다시 연결해 주세요.';
        }
        return '가입 코드가 올바르지 않거나 현재 길드에서 사용 중이지 않습니다.';
      }
      if (error.message == 'Username exists.') {
        return '이미 사용 중인 아이디입니다.';
      }
      if (error.code == 'GUILD_NAME_EXISTS') {
        return '이미 사용 중인 길드 이름입니다.';
      }
      return error.message;
    }
    return '가입 정보를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.space2,
            AppSpacing.screenHorizontal,
            AppSpacing.space8,
          ),
          children: <Widget>[
            Text(
              _registrationMode == RegistrationMode.createGuild
                  ? '새 길드 정보와 계정·캐릭터 정보를 입력해 주세요.'
                  : '마스터가 안내한 고정 가입 코드와 계정·캐릭터 정보를 입력해 주세요.',
              style: AppTextStyles.body.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.space5),
            const Text('가입 방식', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<RegistrationMode>(
                segments: const <ButtonSegment<RegistrationMode>>[
                  ButtonSegment<RegistrationMode>(
                    value: RegistrationMode.joinGuild,
                    icon: Icon(Icons.groups_outlined),
                    label: Text('기존 길드 가입'),
                  ),
                  ButtonSegment<RegistrationMode>(
                    value: RegistrationMode.createGuild,
                    icon: Icon(Icons.add_business_outlined),
                    label: Text('새 길드 생성'),
                  ),
                ],
                selected: <RegistrationMode>{_registrationMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  if (selection.length != 1) return;
                  _selectRegistrationMode(selection.single);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            if (_registrationMode == RegistrationMode.createGuild) ...<Widget>[
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.space2),
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: scheme.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Expanded(
                      child: Text(
                        '길드를 생성하면 이 계정이 길드장이 되고 6자리 가입 코드가 자동 생성됩니다.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.space4),
              AppTextField(
                label: '길드 이름',
                controller: _guildName,
                hintText: '예: 오딘 길드',
                prefixIcon: Icons.flag_outlined,
                textInputAction: TextInputAction.next,
                maxLength: 40,
                validator: _required('길드 이름'),
              ),
            ] else ...<Widget>[
              const Text('가입 코드', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.space2),
              Text(
                '일반 길드원은 마스터가 현재 사용하는 고정 가입 코드를 입력해야 가입할 수 있어요.',
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.space3),
              AppTextField(
                label: '가입 코드',
                controller: _inviteCode,
                hintText: '예: ODIN-7K4P',
                prefixIcon: Icons.key_outlined,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                ],
                maxLength: 32,
                validator: _required('가입 코드'),
              ),
            ],
            const SizedBox(height: AppSpacing.space6),
            const Text('계정 정보', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: '아이디',
              controller: _username,
              autofillHints: const <String>[AutofillHints.newUsername],
              textInputAction: TextInputAction.next,
              validator: _required('아이디'),
            ),
            const SizedBox(height: AppSpacing.space4),
            AppTextField(
              label: '비밀번호',
              controller: _password,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
                if (value.length < 6) return '비밀번호는 6자 이상 입력해 주세요.';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space4),
            AppTextField(
              label: '비밀번호 확인',
              controller: _passwordConfirm,
              obscureText: true,
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  value != _password.text ? '입력한 비밀번호가 서로 다릅니다.' : null,
            ),
            const SizedBox(height: AppSpacing.space8),
            const Text('캐릭터 정보', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.space3),
            AppTextField(
              label: '닉네임',
              controller: _nickname,
              textInputAction: TextInputAction.next,
              validator: _required('닉네임'),
            ),
            const SizedBox(height: AppSpacing.space4),
            AppTextField(
              label: '전투력',
              controller: _combatPower,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || int.tryParse(value) == null) {
                  return '전투력을 숫자로 입력해 주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.space4),
            _DropdownField(
              label: '직업',
              value: _occupation,
              items: CharacterOptions.classesByOccupation.keys.toList(),
              onChanged: (value) {
                setState(() {
                  _occupation = value;
                  _mainClass = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.space4),
            _DropdownField(
              label: '주클래스',
              value: _mainClass,
              items: _occupation == null
                  ? const <String>[]
                  : CharacterOptions.classesByOccupation[_occupation]!,
              onChanged: _occupation == null
                  ? null
                  : (value) => setState(() => _mainClass = value),
            ),
            const SizedBox(height: AppSpacing.space8),
            _EquipmentSection(
              controllers: _equipmentControllers,
              grades: _equipmentGrades,
              onGradeChanged: (part, grade) {
                setState(() => _equipmentGrades[part] = grade);
              },
            ),
            const SizedBox(height: AppSpacing.space4),
            _SkillSection(
              activeSkills: _activeSkills,
              passiveSkills: _passiveSkills,
              onChanged: () => setState(() {}),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space4),
              Text(
                _errorMessage!,
                style: AppTextStyles.label.copyWith(color: palette.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.space6),
            const Center(child: PrivacyPolicyButton()),
            const SizedBox(height: AppSpacing.space2),
            AppButton(
              label: '가입 완료',
              onPressed: _submit,
              isBusy: _isBusy,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String label) {
    return (value) =>
        value == null || value.trim().isEmpty ? '$label을(를) 입력해 주세요.' : null;
  }

  void _selectRegistrationMode(RegistrationMode mode) {
    if (_registrationMode == mode) return;
    setState(() {
      _registrationMode = mode;
      _errorMessage = null;
    });
  }
}

class CreatedGuildInviteDialog extends StatelessWidget {
  const CreatedGuildInviteDialog({
    required this.inviteCode,
    required this.onCopy,
    required this.onContinue,
    super.key,
  });

  final String inviteCode;
  final VoidCallback onCopy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('길드가 생성되었습니다'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('길드원에게 아래 가입 코드를 공유해 주세요.'),
          const SizedBox(height: AppSpacing.space3),
          SelectableText(
            inviteCode,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionTitle.copyWith(letterSpacing: 2),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('코드 복사'),
        ),
        FilledButton(onPressed: onContinue, child: const Text('로그인하기')),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.space2),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          hint: Text(onChanged == null ? '직업을 먼저 선택해 주세요' : '선택해 주세요'),
          items: items
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? '$label을(를) 선택해 주세요.' : null,
        ),
      ],
    );
  }
}

class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({
    required this.controllers,
    required this.grades,
    required this.onGradeChanged,
  });

  final Map<String, TextEditingController> controllers;
  final Map<String, String> grades;
  final void Function(String part, String grade) onGradeChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('장비 정보', style: AppTextStyles.cardTitle),
        subtitle: const Text('13부위 · 선택 입력', style: AppTextStyles.caption),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: CharacterOptions.equipmentParts.map((part) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 92,
                  child: DropdownButtonFormField<String>(
                    initialValue: grades[part],
                    isExpanded: true,
                    items: CharacterOptions.equipmentGrades.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onGradeChanged(part, value);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.space2),
                Expanded(
                  child: TextFormField(
                    controller: controllers[part],
                    decoration: InputDecoration(
                      labelText: part,
                      hintText: '강화/이름',
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SkillSection extends StatelessWidget {
  const _SkillSection({
    required this.activeSkills,
    required this.passiveSkills,
    required this.onChanged,
  });

  final Map<String, String> activeSkills;
  final Map<String, String> passiveSkills;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('스킬 정보', style: AppTextStyles.cardTitle),
        subtitle: const Text('액티브·패시브 강화 상태', style: AppTextStyles.caption),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: <Widget>[
          _SkillGroup(title: '액티브', values: activeSkills, onChanged: onChanged),
          const SizedBox(height: AppSpacing.space4),
          _SkillGroup(
            title: '패시브',
            values: passiveSkills,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({
    required this.title,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final Map<String, String> values;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: AppTextStyles.bodyStrong),
        const SizedBox(height: AppSpacing.space2),
        ...CharacterOptions.skillNames.map((name) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.space2),
            child: DropdownButtonFormField<String>(
              initialValue: values[name],
              decoration: InputDecoration(labelText: name),
              items: CharacterOptions.skillLevels
                  .map(
                    (level) => DropdownMenuItem<String>(
                      value: level,
                      child: Text(level),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  values[name] = value;
                  onChanged();
                }
              },
            ),
          );
        }),
      ],
    );
  }
}
