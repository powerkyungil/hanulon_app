import '../../auth/domain/user_role.dart';

class GuildInvite {
  const GuildInvite({required this.code, required this.role});

  final String code;
  final UserRole role;
}
