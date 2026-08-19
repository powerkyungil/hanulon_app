class AlternateCharacter {
  const AlternateCharacter({
    this.id,
    required this.characterName,
    required this.mainClass,
  });

  final int? id;
  final String characterName;
  final String mainClass;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'character_name': characterName,
      'main_class': mainClass,
    };
  }
}
