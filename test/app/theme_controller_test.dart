import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/app/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('저장된 테마가 없으면 Icon Purple을 기본으로 사용한다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final variant = await container.read(themeControllerProvider.future);

    expect(variant, AppThemeVariant.iconPurple);
  });

  test('선택한 Sand Gold 테마를 기기에 저장한다', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeControllerProvider.future);

    await container
        .read(themeControllerProvider.notifier)
        .setVariant(AppThemeVariant.sandGold);

    expect(
      container.read(themeControllerProvider).value,
      AppThemeVariant.sandGold,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_theme_variant'), 'sand_gold');
  });
}
