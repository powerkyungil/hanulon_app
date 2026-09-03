import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/status_tag.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../domain/alternate_character.dart';
import '../domain/character_options.dart';
import '../domain/profile_settings.dart';
import '../domain/profile_update_request.dart';
import '../domain/user_profile.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _nickname = TextEditingController();
  final _combatPower = TextEditingController();
  final _newPassword = TextEditingController();
  final _maxCritRate = TextEditingController();
  final _maxCritResist = TextEditingController();
  final _statusEffectAccuracy = TextEditingController();
  final _alternateName = TextEditingController();
  late final Map<String, TextEditingController> _equipmentControllers;
  late final Map<String, String> _equipmentGrades;
  late final Map<String, String> _activeSkills;
  late final Map<String, String> _passiveSkills;

  UserProfile? _profile;
  ProfileSettings _settings = const ProfileSettings(allowCombatPowerEdit: true);
  String? _occupation;
  String? _mainClass;
  String? _alternateMainClass;
  String _skillTab = 'active';
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
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
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final profile = await repository.fetchMe();
      ProfileSettings settings;
      try {
        settings = await repository.fetchProfileSettings();
      } catch (_) {
        settings = const ProfileSettings(allowCombatPowerEdit: true);
      }
      if (!mounted) return;
      _settings = settings;
      _apply(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _apply(UserProfile profile) {
    _profile = profile;
    final session = ref.read(authControllerProvider).value;
    _username.text = profile.username ?? session?.username ?? '';
    _nickname.text = profile.nickname;
    _combatPower.text = _formatInteger(profile.combatPower ?? 0);
    _maxCritRate.text = _formatDecimal(profile.maxCritRate);
    _maxCritResist.text = _formatDecimal(profile.maxCritResist);
    _statusEffectAccuracy.text = _formatDecimal(profile.statusEffectAccuracy);
    _occupation =
        CharacterOptions.classesByOccupation.containsKey(profile.occupation)
        ? profile.occupation
        : null;
    final classOptions = CharacterOptions.classesByOccupation[_occupation];
    _mainClass = classOptions?.contains(profile.mainClass) ?? false
        ? profile.mainClass
        : null;

    final alternate = profile.alternateCharacters.firstOrNull;
    _alternateName.text = alternate?.characterName ?? '';
    _alternateMainClass =
        CharacterOptions.allMainClasses.contains(alternate?.mainClass)
        ? alternate?.mainClass
        : null;

    for (final part in CharacterOptions.equipmentParts) {
      final item = profile.equipment[part];
      if (item is Map<String, dynamic>) {
        _equipmentControllers[part]!.text = item['val']?.toString() ?? '';
        final grade = item['color']?.toString() ?? 'none';
        _equipmentGrades[part] =
            CharacterOptions.equipmentGrades.containsKey(grade)
            ? grade
            : 'none';
      } else {
        _equipmentControllers[part]!.text = item?.toString() ?? '';
        _equipmentGrades[part] = 'none';
      }
    }
    _applySkills(profile.skills['active'], _activeSkills);
    _applySkills(profile.skills['passive'], _passiveSkills);
  }

  void _applySkills(Object? raw, Map<String, String> target) {
    final values = raw is Map<String, dynamic>
        ? raw
        : const <String, dynamic>{};
    for (final name in CharacterOptions.skillNames) {
      final level = values[name]?.toString() ?? 'X';
      target[name] = CharacterOptions.skillLevels.contains(level) ? level : 'X';
    }
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_occupation == null || _mainClass == null) {
      setState(() => _errorMessage = '직업과 주클래스를 선택해 주세요.');
      return;
    }
    final alternateName = _alternateName.text.trim();
    final hasAlternateName = alternateName.isNotEmpty;
    final hasAlternateClass = _alternateMainClass != null;
    if (hasAlternateName != hasAlternateClass) {
      setState(() => _errorMessage = '부계정의 캐릭터명과 주클래스를 모두 입력해 주세요.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
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
      'active': Map<String, String>.from(_activeSkills),
      'passive': Map<String, String>.from(_passiveSkills),
    };
    final alternateCharacters = hasAlternateName
        ? <AlternateCharacter>[
            AlternateCharacter(
              characterName: alternateName,
              mainClass: _alternateMainClass!,
            ),
          ]
        : const <AlternateCharacter>[];

    try {
      final updated = await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            ProfileUpdateRequest(
              nickname: _nickname.text.trim(),
              occupation: _occupation!,
              mainClass: _mainClass!,
              combatPower: _settings.allowCombatPowerEdit
                  ? _parseInteger(_combatPower.text)
                  : profile.combatPower ?? 0,
              equipment: equipment,
              skills: skills,
              maxCritRate: _parseDecimal(_maxCritRate.text),
              maxCritResist: _parseDecimal(_maxCritResist.text),
              statusEffectAccuracy: _parseDecimal(_statusEffectAccuracy.text),
              alternateCharacters: alternateCharacters,
              password: _newPassword.text,
            ),
          );
      if (!mounted) return;
      setState(() {
        _apply(updated);
        _newPassword.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내 정보를 저장했습니다.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    if (_isSaving || _isDeleting) return;

    final password = await _showDeleteAccountDialog(context);
    if (password == null || !mounted) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: password);
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _messageFor(error));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    return '내 정보를 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';
  }

  String _formatInteger(int value) =>
      NumberFormat.decimalPattern().format(value);

  int _parseInteger(String value) =>
      int.tryParse(value.replaceAll(',', '')) ?? 0;

  String _formatDecimal(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  double _parseDecimal(String value) => double.tryParse(value.trim()) ?? 0;

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _combatPower.dispose();
    _newPassword.dispose();
    _maxCritRate.dispose();
    _maxCritResist.dispose();
    _statusEffectAccuracy.dispose();
    _alternateName.dispose();
    for (final controller in _equipmentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 정보 설정')),
      body: _buildBody(),
      bottomNavigationBar: _profile == null || _isLoading
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
                AppSpacing.screenHorizontal,
                AppSpacing.space3,
              ),
              child: FilledButton(
                onPressed: _isSaving || _isDeleting ? null : _save,
                child: _isSaving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('변경사항 저장'),
              ),
            ),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.appPalette;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profile == null) {
      return ErrorView(
        message: _errorMessage ?? '내 정보를 불러오지 못했습니다.',
        onRetry: _load,
      );
    }

    final session = ref.watch(authControllerProvider).value;
    final characterSummary = <String?>[
      _profile!.occupation,
      _profile!.mainClass,
    ].whereType<String>().join(' · ');
    return Form(
      key: _formKey,
      child: ListView(
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
                CircleAvatar(
                  radius: 30,
                  backgroundColor: palette.primarySoft,
                  foregroundColor: scheme.primary,
                  child: const Icon(Icons.person_rounded, size: 30),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _profile!.nickname,
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        characterSummary.isEmpty
                            ? '직업과 주클래스를 설정해 주세요'
                            : characterSummary,
                        style: AppTextStyles.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space2),
                      StatusTag(
                        label: session?.role.label ?? _profile!.role.label,
                        foregroundColor: scheme.primary,
                        backgroundColor: palette.primarySoft,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('전투력', style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    Text(
                      _formatInteger(_profile!.combatPower ?? 0),
                      style: AppTextStyles.cardTitle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          _SectionCard(
            icon: Icons.lock_outline_rounded,
            title: '계정 정보',
            subtitle: '아이디 확인 및 비밀번호 변경',
            initiallyExpanded: true,
            children: <Widget>[
              AppTextField(
                label: '아이디',
                controller: _username,
                readOnly: true,
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: AppSpacing.space4),
              AppTextField(
                label: '새 비밀번호',
                controller: _newPassword,
                hintText: '변경할 때만 입력해 주세요',
                obscureText: true,
                autofillHints: const <String>[AutofillHints.newPassword],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          _SectionCard(
            icon: Icons.manage_accounts_outlined,
            title: '캐릭터 정보',
            subtitle: '닉네임, 클래스, 전투력과 주요 능력치',
            initiallyExpanded: true,
            children: <Widget>[
              AppTextField(
                label: '닉네임',
                controller: _nickname,
                validator: (value) => value == null || value.trim().isEmpty
                    ? '닉네임을 입력해 주세요.'
                    : null,
              ),
              const SizedBox(height: AppSpacing.space4),
              _ProfileDropdown(
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
              _ProfileDropdown(
                label: '주클래스',
                value: _mainClass,
                items: _occupation == null
                    ? const <String>[]
                    : CharacterOptions.classesByOccupation[_occupation]!,
                onChanged: _occupation == null
                    ? null
                    : (value) => setState(() => _mainClass = value),
              ),
              const SizedBox(height: AppSpacing.space4),
              AppTextField(
                label: '전투력',
                controller: _combatPower,
                enabled: _settings.allowCombatPowerEdit,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  const _ThousandsSeparatorFormatter(),
                ],
                validator: (value) => value == null || value.trim().isEmpty
                    ? '전투력을 입력해 주세요.'
                    : null,
              ),
              if (!_settings.allowCombatPowerEdit) ...<Widget>[
                const SizedBox(height: AppSpacing.space2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: palette.warning,
                    ),
                    const SizedBox(width: AppSpacing.space2),
                    Expanded(
                      child: Text(
                        '현재 길드 설정상 전투력 수정이 제한되어 있습니다.',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.space5),
              Text('주요 능력치', style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.space3),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DecimalField(
                      label: '최고 치명타 확률',
                      controller: _maxCritRate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: _DecimalField(
                      label: '최고 치명타 저항',
                      controller: _maxCritResist,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              _DecimalField(
                label: '상태이상/충격 적중',
                controller: _statusEffectAccuracy,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          _SectionCard(
            icon: Icons.switch_account_outlined,
            title: '부계정 정보',
            subtitle: _alternateName.text.isEmpty
                ? '부계정 캐릭터 1개를 등록할 수 있어요'
                : '${_alternateName.text} · ${_alternateMainClass ?? '클래스 미선택'}',
            children: <Widget>[
              AppTextField(
                label: '캐릭터명',
                controller: _alternateName,
                hintText: '부계정 캐릭터명',
                maxLength: 30,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.space4),
              _ProfileDropdown(
                label: '주클래스',
                value: _alternateMainClass,
                items: CharacterOptions.allMainClasses,
                isRequired: false,
                onChanged: (value) {
                  setState(() => _alternateMainClass = value);
                },
              ),
              const SizedBox(height: AppSpacing.space2),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _alternateName.clear();
                      _alternateMainClass = null;
                    });
                  },
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  label: const Text('입력 지우기'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          _EquipmentSection(
            controllers: _equipmentControllers,
            grades: _equipmentGrades,
            onGradeChanged: (part, grade) {
              setState(() => _equipmentGrades[part] = grade);
            },
            onValueChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.space3),
          _SkillSection(
            selectedTab: _skillTab,
            activeSkills: _activeSkills,
            passiveSkills: _passiveSkills,
            onTabChanged: (value) => setState(() => _skillTab = value),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.space6),
          _AccountDeletionCard(
            isDeleting: _isDeleting,
            onDelete: _deleteAccount,
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.space4),
            AppCard(
              borderColor: palette.danger.withValues(alpha: 0.4),
              child: Row(
                children: <Widget>[
                  Icon(Icons.error_outline_rounded, color: palette.danger),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.label.copyWith(
                        color: palette.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<String?> _showDeleteAccountDialog(BuildContext context) async {
  var password = '';
  var acknowledged = false;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final canDelete = password.isNotEmpty && acknowledged;
          return AlertDialog(
            title: const Text('회원 탈퇴'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text('계정과 개인 캐릭터·활동 데이터가 서버에서 영구 삭제되며 복구할 수 없습니다.'),
                  const SizedBox(height: AppSpacing.space4),
                  TextField(
                    key: const ValueKey<String>('account-delete-password'),
                    obscureText: true,
                    autofillHints: const <String>[AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: '현재 비밀번호',
                      hintText: '본인 확인을 위해 입력해 주세요',
                    ),
                    onChanged: (value) {
                      setDialogState(() => password = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  CheckboxListTile(
                    key: const ValueKey<String>('account-delete-acknowledge'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: acknowledged,
                    title: const Text('모든 개인 데이터가 영구 삭제되는 것에 동의합니다.'),
                    onChanged: (value) {
                      setDialogState(() => acknowledged = value ?? false);
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const ValueKey<String>('account-delete-confirm'),
                onPressed: canDelete
                    ? () => Navigator.of(dialogContext).pop(password)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPalette.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('영구 삭제'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AccountDeletionCard extends StatelessWidget {
  const _AccountDeletionCard({
    required this.isDeleting,
    required this.onDelete,
  });

  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return AppCard(
      borderColor: palette.danger.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.person_off_outlined, color: palette.danger),
              const SizedBox(width: AppSpacing.space2),
              Text('계정 관리', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '탈퇴하면 계정과 개인 데이터가 즉시 영구 삭제되며 되돌릴 수 없습니다.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.space4),
          OutlinedButton.icon(
            key: const ValueKey<String>('account-delete-button'),
            onPressed: isDeleting ? null : onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.danger,
              side: BorderSide(color: palette.danger),
            ),
            icon: isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: Text(isDeleting ? '탈퇴 처리 중' : '회원 탈퇴'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon),
        title: Text(title, style: AppTextStyles.cardTitle),
        subtitle: Text(subtitle, style: AppTextStyles.caption),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.space4,
          AppSpacing.space2,
          AppSpacing.space4,
          AppSpacing.space5,
        ),
        children: children,
      ),
    );
  }
}

class _ProfileDropdown extends StatelessWidget {
  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isRequired = true,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.space2),
        DropdownButtonFormField<String>(
          key: ValueKey<String?>('$label:$value'),
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
          validator: isRequired && onChanged != null
              ? (value) => value == null ? '$label을(를) 선택해 주세요.' : null
              : null,
        ),
      ],
    );
  }
}

class _DecimalField extends StatelessWidget {
  const _DecimalField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        return double.tryParse(value) == null ? '숫자를 입력해 주세요.' : null;
      },
    );
  }
}

class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({
    required this.controllers,
    required this.grades,
    required this.onGradeChanged,
    required this.onValueChanged,
  });

  final Map<String, TextEditingController> controllers;
  final Map<String, String> grades;
  final void Function(String part, String grade) onGradeChanged;
  final VoidCallback onValueChanged;

  @override
  Widget build(BuildContext context) {
    final completed = controllers.values
        .where((item) => item.text.isNotEmpty)
        .length;
    return _SectionCard(
      icon: Icons.shield_outlined,
      title: '장비 정보',
      subtitle: '13부위 · $completed개 입력됨',
      children: CharacterOptions.equipmentParts.map((part) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text(part, style: AppTextStyles.label)),
                  SizedBox(
                    width: 112,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>('equipment:$part:${grades[part]}'),
                      initialValue: grades[part],
                      isDense: true,
                      items: CharacterOptions.equipmentGrades.entries
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.key,
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _gradeColor(context, entry.key),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(entry.value),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onGradeChanged(part, value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space2),
              TextFormField(
                controller: controllers[part],
                onChanged: (_) => onValueChanged(),
                decoration: const InputDecoration(hintText: '장비 이름 또는 강화 수치'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Color _gradeColor(BuildContext context, String grade) {
    final palette = context.appPalette;
    return switch (grade) {
      'hero' => palette.bossFixed,
      'legend' => palette.warning,
      'mythic' => palette.danger,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }
}

class _SkillSection extends StatelessWidget {
  const _SkillSection({
    required this.selectedTab,
    required this.activeSkills,
    required this.passiveSkills,
    required this.onTabChanged,
    required this.onChanged,
  });

  final String selectedTab;
  final Map<String, String> activeSkills;
  final Map<String, String> passiveSkills;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final values = selectedTab == 'active' ? activeSkills : passiveSkills;
    final learned = <String>[
      ...activeSkills.values,
      ...passiveSkills.values,
    ].where((level) => level != 'X').length;
    return _SectionCard(
      icon: Icons.auto_awesome_outlined,
      title: '스킬 정보',
      subtitle: '액티브·패시브 · $learned개 습득',
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment(value: 'active', label: Text('액티브')),
              ButtonSegment(value: 'passive', label: Text('패시브')),
            ],
            selected: <String>{selectedTab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onTabChanged(selection.first),
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        ...CharacterOptions.skillNames.map((name) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>('$selectedTab:$name:${values[name]}'),
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

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  const _ThousandsSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = NumberFormat.decimalPattern().format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
