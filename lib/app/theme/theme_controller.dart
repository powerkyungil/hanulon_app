import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeVariant {
  iconPurple('icon_purple', 'Icon Purple', '앱 아이콘의 보라색과 부드러운 라벤더 배경 테마'),
  sandGold('sand_gold', 'Sand Gold', '따뜻하고 차분한 모래빛 테마'),
  darkBlue('dark_blue', 'Dark Blue', '깊은 남색과 선명한 블루 테마');

  const AppThemeVariant(this.storageValue, this.label, this.description);

  final String storageValue;
  final String label;
  final String description;

  static AppThemeVariant fromStorage(String? value) {
    return AppThemeVariant.values.firstWhere(
      (variant) => variant.storageValue == value,
      orElse: () => AppThemeVariant.iconPurple,
    );
  }
}

class ThemeController extends AsyncNotifier<AppThemeVariant> {
  static const _preferenceKey = 'app_theme_variant';

  @override
  Future<AppThemeVariant> build() async {
    final preferences = await SharedPreferences.getInstance();
    return AppThemeVariant.fromStorage(preferences.getString(_preferenceKey));
  }

  Future<void> setVariant(AppThemeVariant variant) async {
    state = AsyncData<AppThemeVariant>(variant);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, variant.storageValue);
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, AppThemeVariant>(
      ThemeController.new,
    );
