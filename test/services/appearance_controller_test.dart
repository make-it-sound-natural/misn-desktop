import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads preferences from settings service', () async {
    final service = SettingsService();
    await service.setAppearancePreferences(
      const AppearancePreferences(
        schemaVersion: 1,
        themeMode: AppearanceThemeMode.dark,
        menuFontSize: 16,
        editorFontSize: 18,
      ),
    );
    final controller = AppearanceController(settingsService: service);

    expect(controller.state, AppearanceControllerState.initial);
    await controller.load();

    expect(controller.state, AppearanceControllerState.ready);
    expect(controller.preferences.themeMode, AppearanceThemeMode.dark);
    expect(controller.preferences.menuFontSize, 16);
    expect(controller.preferences.editorFontSize, 18);
  });

  test('persists updates and notifies listeners', () async {
    final service = SettingsService();
    final controller = AppearanceController(settingsService: service);
    await controller.load();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(AppearanceThemeMode.light);
    await controller.setMenuFontSize(17);
    await controller.setEditorFontSize(20);

    final saved = await service.getAppearancePreferences();
    expect(saved.themeMode, AppearanceThemeMode.light);
    expect(saved.menuFontSize, 17);
    expect(saved.editorFontSize, 20);
    expect(controller.state, AppearanceControllerState.ready);
    expect(notifications, greaterThanOrEqualTo(6));
  });

  test('resets to defaults', () async {
    final controller = AppearanceController(settingsService: SettingsService());
    await controller.load();
    await controller.setThemeMode(AppearanceThemeMode.dark);

    await controller.reset();

    expect(controller.state, AppearanceControllerState.ready);
    expect(controller.preferences, const AppearancePreferences.defaults());
  });

  test('moves to failed when persistence throws', () async {
    final controller = AppearanceController(
      settingsService: _ThrowingSettingsService(),
    );

    await controller.load();

    expect(controller.state, AppearanceControllerState.failed);
  });
}

class _ThrowingSettingsService extends SettingsService {
  @override
  Future<AppearancePreferences> getAppearancePreferences() {
    throw Exception('load failed');
  }
}
