class MemberEquipment {
  const MemberEquipment({this.value = '', this.grade = 'none'});

  final String value;
  final String grade;

  bool get isEmpty => value.trim().isEmpty;
}
