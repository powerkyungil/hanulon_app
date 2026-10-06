import 'user_role.dart';
import '../../deputy/domain/deputy_character.dart';

enum SessionPrincipalType { user, deputy }

class Session {
  const Session({
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.nickname,
    required this.role,
    this.principalType = SessionPrincipalType.user,
    this.deputyId,
    this.guildId,
    this.activeCharacter,
    this.permissions = const <String>[],
  });

  final String accessToken;
  final int userId;
  final String username;
  final String nickname;
  final UserRole role;
  final SessionPrincipalType principalType;
  final int? deputyId;
  final int? guildId;
  final DeputyCharacter? activeCharacter;
  final List<String> permissions;

  bool get isDeputy => principalType == SessionPrincipalType.deputy;

  int? get effectiveUserId => isDeputy ? activeCharacter?.ownerUserId : userId;

  String? get activeCharacterKey => activeCharacter?.characterKey;

  bool hasPermission(String permission) {
    if (!isDeputy || permissions.isEmpty) return true;
    final normalized = permission.trim().toUpperCase();
    return permissions.any((item) => item.trim().toUpperCase() == normalized);
  }

  Session copyWith({
    int? userId,
    String? username,
    String? nickname,
    UserRole? role,
    SessionPrincipalType? principalType,
    int? deputyId,
    int? guildId,
    DeputyCharacter? activeCharacter,
    bool clearActiveCharacter = false,
    List<String>? permissions,
  }) {
    return Session(
      accessToken: accessToken,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
      principalType: principalType ?? this.principalType,
      deputyId: deputyId ?? this.deputyId,
      guildId: guildId ?? this.guildId,
      activeCharacter: clearActiveCharacter
          ? null
          : activeCharacter ?? this.activeCharacter,
      permissions: permissions ?? this.permissions,
    );
  }
}
