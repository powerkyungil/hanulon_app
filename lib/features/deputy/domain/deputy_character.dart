class DeputyCharacter {
  const DeputyCharacter({
    required this.characterKey,
    required this.characterType,
    required this.ownerUserId,
    required this.ownerNickname,
    required this.characterName,
    required this.mainClass,
    required this.combatPower,
  });

  final String characterKey;
  final String characterType;
  final int ownerUserId;
  final String ownerNickname;
  final String characterName;
  final String mainClass;
  final int combatPower;

  bool get isAlternate => characterType.toUpperCase() == 'ALTERNATE';

  String get typeLabel => isAlternate ? '부캐' : '본캐';

  String get displayName => characterName.trim().isEmpty
      ? ownerNickname.trim().isEmpty
            ? '이름 없는 캐릭터'
            : ownerNickname
      : characterName;

  factory DeputyCharacter.fromJson(Map<String, dynamic> json) {
    final characterType = _string(json, 'characterType', 'character_type');
    final ownerUserId = _int(
      json['ownerUserId'] ?? json['owner_user_id'] ?? json['userId'],
    );
    final normalizedType = characterType.isEmpty ? 'MAIN' : characterType;
    final characterKey =
        _firstNonEmpty(json, <String>['characterKey']) ??
        '$normalizedType:$ownerUserId';
    return DeputyCharacter(
      characterKey: characterKey,
      characterType: normalizedType,
      ownerUserId: ownerUserId,
      ownerNickname:
          _firstNonEmpty(json, <String>[
            'ownerNickname',
            'owner_nickname',
            'nickname',
          ]) ??
          '',
      characterName:
          _firstNonEmpty(json, <String>[
            'characterName',
            'character_name',
            'name',
          ]) ??
          '',
      mainClass:
          _firstNonEmpty(json, <String>['mainClass', 'main_class']) ?? '',
      combatPower: _int(json['combatPower'] ?? json['combat_power']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'characterKey': characterKey,
      'characterType': characterType,
      'ownerUserId': ownerUserId,
      'ownerNickname': ownerNickname,
      'characterName': characterName,
      'mainClass': mainClass,
      'combatPower': combatPower,
    };
  }

  static String _string(
    Map<String, dynamic> json,
    String camelCaseKey,
    String snakeCaseKey,
  ) {
    return json[camelCaseKey]?.toString().trim().isNotEmpty == true
        ? json[camelCaseKey].toString().trim()
        : json[snakeCaseKey]?.toString().trim() ?? '';
  }

  static String? _firstNonEmpty(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
