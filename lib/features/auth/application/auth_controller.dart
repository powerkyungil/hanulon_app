import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/session.dart';
import '../domain/profile_update_request.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';
import '../../push_notifications/application/push_notification_service.dart';

class AuthController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async => null;

  Future<Session?> restoreSession() async {
    state = const AsyncLoading<Session?>();
    try {
      final tokenStorage = ref.read(tokenStorageProvider);
      final token = await tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        state = const AsyncData<Session?>(null);
        return null;
      }

      final session = _sessionFromToken(token);
      if (session == null) {
        await tokenStorage.clearToken();
        state = const AsyncData<Session?>(null);
        return null;
      }

      state = AsyncData<Session?>(session);
      _registerPushTokenWithoutBlocking();
      return session;
    } catch (error, stackTrace) {
      state = AsyncError<Session?>(error, stackTrace);
      rethrow;
    }
  }

  Session? _sessionFromToken(String token) {
    final json = _jwtPayload(token);
    if (json == null) return null;

    final userId = int.tryParse(json['sub']?.toString() ?? '');
    final username = json['username']?.toString();
    final nickname = json['nickname']?.toString();
    if (userId == null ||
        username == null ||
        username.isEmpty ||
        nickname == null ||
        nickname.isEmpty) {
      return null;
    }

    final expiration = int.tryParse(json['exp']?.toString() ?? '');
    final nowInSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiration != null && expiration <= nowInSeconds) return null;

    return Session(
      accessToken: token,
      userId: userId,
      username: username,
      nickname: nickname,
      role: UserRole.fromApi(json['role']?.toString()),
    );
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

      state = AsyncData<Session?>(session);
      _registerPushTokenWithoutBlocking();
      return session;
    } catch (error, stackTrace) {
      await tokenStorage.clearToken();
      state = AsyncError<Session?>(error, stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(pushTokenLifecycleProvider).removeBeforeLogout();
    } catch (_) {
      // Token cleanup failure must not keep the user signed in locally.
    }
    await ref.read(tokenStorageProvider).clearToken();
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
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Session?>(
  AuthController.new,
);
