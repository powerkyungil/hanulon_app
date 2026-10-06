import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/session_metadata_storage.dart';
import '../../../core/storage/token_storage.dart';
import '../../characters/application/character_target_controller.dart';
import '../../deputy/data/deputy_auth_repository.dart';
import '../../deputy/domain/deputy_character.dart';
import '../data/auth_repository.dart';
import '../domain/session.dart';
import '../domain/profile_update_request.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';
import '../../push_notifications/application/push_notification_service.dart';

class AuthController extends AsyncNotifier<Session?> {
  bool _persistSessionMetadata = false;

  @override
  Future<Session?> build() async => null;

  Future<Session?> restoreSession() async {
    state = const AsyncLoading<Session?>();
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      final token = await tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        await _clearSessionMetadata();
        state = const AsyncData<Session?>(null);
        return null;
      }

      final sessionMetadata = await _readSessionMetadata();
      final session = _sessionFromToken(token, metadata: sessionMetadata);
      if (session == null) {
        await tokenStorage.clearToken();
        await _clearSessionMetadata();
        state = const AsyncData<Session?>(null);
        return null;
      }

      _persistSessionMetadata = true;
      var restoredSession = session;
      if (session.isDeputy) {
        try {
          final activeCharacter = await ref
              .read(deputyAuthRepositoryProvider)
              .fetchActiveCharacter();
          restoredSession = session.copyWith(
            activeCharacter: activeCharacter,
            clearActiveCharacter: activeCharacter == null,
          );
          await _writeSessionMetadata(restoredSession);
        } catch (error) {
          if (error is ApiException &&
              error.type == ApiErrorType.unauthorized) {
            await tokenStorage.clearToken();
            await _clearSessionMetadata();
            state = const AsyncData<Session?>(null);
            return null;
          }
          rethrow;
        }
      }

      state = AsyncData<Session?>(restoredSession);
      _registerPushTokenWithoutBlocking();
      return restoredSession;
    } catch (error, stackTrace) {
      state = AsyncError<Session?>(error, stackTrace);
      rethrow;
    }
  }

  Session? _sessionFromToken(String token, {Session? metadata}) {
    final json = _jwtPayload(token);
    if (json == null) return null;

    final expiration = int.tryParse(json['exp']?.toString() ?? '');
    final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiration != null && expiration <= nowInSeconds) return null;

    final principalType = _principalType(json);
    final isDeputy =
        principalType == SessionPrincipalType.deputy ||
        (principalType == null && metadata?.isDeputy == true);
    if (isDeputy) return _deputySessionFromClaims(token, json, metadata);

    final userId =
        int.tryParse(json['sub']?.toString() ?? '') ?? metadata?.userId;
    final username = json['username']?.toString() ?? metadata?.username;
    final nickname = json['nickname']?.toString() ?? metadata?.nickname;
    if (userId == null ||
        username == null ||
        username.isEmpty ||
        nickname == null ||
        nickname.isEmpty) {
      return null;
    }
    return Session(
      accessToken: token,
      userId: userId,
      username: username,
      nickname: nickname,
      role: UserRole.fromApi(json['role']?.toString()),
    );
  }

  Session? _deputySessionFromClaims(
    String token,
    Map<String, dynamic> json,
    Session? metadata,
  ) {
    final deputyId =
        int.tryParse(
          (json['deputyId'] ?? json['deputy_id'] ?? json['sub'])?.toString() ??
              '',
        ) ??
        metadata?.deputyId;
    final username = json['username']?.toString() ?? metadata?.username;
    if (deputyId == null || username == null || username.isEmpty) return null;
    return Session(
      accessToken: token,
      userId:
          int.tryParse(json['userId']?.toString() ?? '') ??
          metadata?.userId ??
          0,
      username: username,
      nickname: json['nickname']?.toString() ?? metadata?.nickname ?? '',
      role: UserRole.deputy,
      principalType: SessionPrincipalType.deputy,
      deputyId: deputyId,
      guildId:
          int.tryParse(
            (json['guildId'] ?? json['guild_id'])?.toString() ?? '',
          ) ??
          metadata?.guildId,
      activeCharacter: metadata?.activeCharacter,
      permissions:
          _permissions(json['permissions']) ??
          metadata?.permissions ??
          const <String>[],
    );
  }

  SessionPrincipalType? _principalType(Map<String, dynamic> json) {
    final raw =
        (json['principalType'] ??
                json['principal_type'] ??
                json['accountType'] ??
                json['account_type'] ??
                json['type'] ??
                json['role'])
            ?.toString()
            .toUpperCase();
    if (raw == 'DEPUTY') return SessionPrincipalType.deputy;
    if (raw == 'USER' || raw == 'MASTER' || raw == 'ADMIN' || raw == 'MEMBER') {
      return SessionPrincipalType.user;
    }
    return null;
  }

  List<String>? _permissions(Object? value) {
    if (value is List<dynamic>) {
      return value.map((item) => item.toString()).toList();
    }
    if (value is Map<String, dynamic>) {
      return value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();
    }
    return null;
  }

  Map<String, dynamic>? _jwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      if (json is Map<String, dynamic>) {
        return json;
      }
    } catch (_) {
      // Token parsing is only used to restore the local session. The server
      // remains responsible for validating the token on authenticated calls.
    }
    return null;
  }

  Future<Session> login({
    required String username,
    required String password,
    required bool autoLogin,
  }) async {
    state = const AsyncLoading<Session?>();
    final tokenStorage = ref.read(tokenStorageProvider);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(username: username, password: password);
      await tokenStorage.writeToken(session.accessToken, persist: autoLogin);
      _persistSessionMetadata = autoLogin;
      await _clearSessionMetadata();
      ref.invalidate(selectedCharacterKeyProvider);
      ref.invalidate(selectedCharacterNameProvider);

      state = AsyncData<Session?>(session);
      _registerPushTokenWithoutBlocking();
      return session;
    } catch (error, stackTrace) {
      await tokenStorage.clearToken();
      await _clearSessionMetadata();
      state = AsyncError<Session?>(error, stackTrace);
      rethrow;
    }
  }

  Future<Session> loginAsDeputy({
    required String username,
    required String password,
    required bool autoLogin,
  }) async {
    state = const AsyncLoading<Session?>();
    final tokenStorage = ref.read(tokenStorageProvider);

    try {
      final session = await ref
          .read(deputyAuthRepositoryProvider)
          .login(username: username, password: password);
      await tokenStorage.writeToken(session.accessToken, persist: autoLogin);
      _persistSessionMetadata = autoLogin;
      await _writeSessionMetadata(session);
      ref.invalidate(selectedCharacterKeyProvider);
      ref.invalidate(selectedCharacterNameProvider);
      state = AsyncData<Session?>(session);
      _registerPushTokenWithoutBlocking();
      return session;
    } catch (error, stackTrace) {
      await tokenStorage.clearToken();
      await _clearSessionMetadata();
      state = AsyncError<Session?>(error, stackTrace);
      rethrow;
    }
  }

  Future<DeputyCharacter?> selectDeputyCharacter(String characterKey) async {
    final currentSession = state.value;
    if (currentSession == null || !currentSession.isDeputy) {
      throw const FormatException('부주 로그인 세션이 없습니다.');
    }
    await ref
        .read(deputyAuthRepositoryProvider)
        .updateActiveCharacter(characterKey);
    final activeCharacter = await ref
        .read(deputyAuthRepositoryProvider)
        .fetchActiveCharacter();
    final updated = currentSession.copyWith(
      activeCharacter: activeCharacter,
      clearActiveCharacter: activeCharacter == null,
    );
    state = AsyncData<Session?>(updated);
    await _writeSessionMetadata(updated);
    return activeCharacter;
  }

  Future<void> logout() async {
    try {
      await ref.read(pushTokenLifecycleProvider).removeBeforeLogout();
    } catch (_) {
      // Token cleanup failure must not keep the user signed in locally.
    }
    await ref.read(tokenStorageProvider).clearToken();
    await _clearSessionMetadata();
    ref.invalidate(selectedCharacterKeyProvider);
    ref.invalidate(selectedCharacterNameProvider);
    state = const AsyncData<Session?>(null);
  }

  void _registerPushTokenWithoutBlocking() {
    try {
      unawaited(
        ref.read(pushTokenLifecycleProvider).registerAfterAuthentication(),
      );
    } catch (_) {
      // Firebase can be unavailable on unsupported test/runtime platforms.
    }
  }

  Future<void> deleteAccount({required String password}) async {
    await ref.read(authRepositoryProvider).deleteMe(password: password);
    await ref.read(tokenStorageProvider).clearToken();
    await _clearSessionMetadata();
    ref.invalidate(selectedCharacterKeyProvider);
    ref.invalidate(selectedCharacterNameProvider);
    state = const AsyncData<Session?>(null);
  }

  Future<UserProfile> updateProfile(ProfileUpdateRequest request) async {
    final currentSession = state.value;
    await ref.read(authRepositoryProvider).updateMe(request);
    final profile = await ref.read(authRepositoryProvider).fetchMe();
    if (currentSession != null) {
      state = AsyncData<Session?>(
        currentSession.copyWith(
          userId: profile.id,
          nickname: profile.nickname,
          role: profile.role,
        ),
      );
    }
    return profile;
  }

  void updateCurrentRole(UserRole role) {
    final currentSession = state.value;
    if (currentSession == null) return;
    state = AsyncData<Session?>(currentSession.copyWith(role: role));
  }

  Future<Session?> _readSessionMetadata() async {
    try {
      return await ref.read(sessionMetadataStorageProvider).read();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSessionMetadata(Session session) async {
    try {
      await ref
          .read(sessionMetadataStorageProvider)
          .write(session, persist: _persistSessionMetadata);
    } catch (_) {
      // Metadata is a restore hint. The access token remains the source of
      // truth when secure storage is temporarily unavailable.
    }
  }

  Future<void> _clearSessionMetadata() async {
    try {
      await ref.read(sessionMetadataStorageProvider).clear();
    } catch (_) {
      // Logout must still clear the access token if metadata cleanup fails.
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
