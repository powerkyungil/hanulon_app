enum UserRole {
  master('MASTER', '길드장'),
  admin('ADMIN', '운영진'),
  member('MEMBER', '길드원'),
  unknown('UNKNOWN', '알 수 없음');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  factory UserRole.fromApi(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.apiValue == value?.toUpperCase(),
      orElse: () => UserRole.unknown,
    );
  }
}
