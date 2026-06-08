import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppearanceController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = AppearanceController();
    await controller.load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          (call) async {
            if (call.method == 'getAutomaticUpdateChecks') return true;
            if (call.method == 'getLastUpdateCheck') return null;
            if (call.method == 'getAppVersion') {
              return {'version': '1.0.0', 'build': '1'};
            }
            return null;
          },
        );
  });

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          null,
        );
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppearanceScope(
        controller: controller,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens Appearance settings from sidebar', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settingsNav-appearance')));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Menu font size'), findsOneWidget);
    expect(find.text('Editor font size'), findsOneWidget);
    expect(find.text('Reset Appearance'), findsWidgets);
  });

  testWidgets('persists theme and font sizes', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.byKey(const Key('settingsNav-appearance')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appearanceTheme-dark')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('appearance-menuFontSize')),
      '17',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('appearance-editorFontSize')),
      '19',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppDefaults.appearancePreferencesKey);
    expect(raw, contains('dark'));
    expect(raw, contains('17'));
    expect(raw, contains('19'));
  });
}
