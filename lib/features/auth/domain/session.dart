import 'user_role.dart';

class Session {
  const Session({
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.nickname,
    required this.role,
  });

  final String accessToken;
  final int userId;
  final String username;
  final String nickname;
  final UserRole role;

  Session copyWith({
    int? userId,
    String? username,
    String? nickname,
    UserRole? role,
  }) {
    return Session(
      accessToken: accessToken,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
    );
  }
}
