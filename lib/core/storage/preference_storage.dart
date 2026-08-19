import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceStorage {
  static const _savedUsernameKey = 'saved_username';
  static const _saveUsernameKey = 'save_username';
  static const _autoLoginKey = 'auto_login';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<String?> readSavedUsername() async {
    final preferences = await _preferences;
    return preferences.getString(_savedUsernameKey);
  }

  Future<bool> readSaveUsername() async {
    final preferences = await _preferences;
    return preferences.getBool(_saveUsernameKey) ?? false;
  }

  Future<bool> readAutoLogin() async {
    final preferences = await _preferences;
    return preferences.getBool(_autoLoginKey) ?? true;
  }

  Future<void> saveLoginPreferences({
    required String username,
    required bool saveUsername,
    required bool autoLogin,
  }) async {
    final preferences = await _preferences;
    await preferences.setBool(_saveUsernameKey, saveUsername);
    await preferences.setBool(_autoLoginKey, autoLogin);
    if (saveUsername) {
      await preferences.setString(_savedUsernameKey, username);
    } else {
      await preferences.remove(_savedUsernameKey);
    }
  }
}

final preferenceStorageProvider = Provider<PreferenceStorage>(
  (ref) => PreferenceStorage(),
);
