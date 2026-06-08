import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelMethods.channelName);
  final methodCalls = <MethodCall>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_shortcut': 'cmd+shift+a',
      'app_shortcut_replace': 'cmd+shift+b',
      'app_shortcut_append': 'cmd+shift+c',
    });
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          if (call.method == 'getAutomaticUpdateChecks') return true;
          if (call.method == 'getLastUpdateCheck') return null;
          if (call.method == 'getAppVersion') {
            return {'version': '1.0.0', 'build': '1'};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpShortcuts(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(menuFontSize: AppDefaults.menuFontSize),
        darkTheme: AppTheme.dark(menuFontSize: AppDefaults.menuFontSize),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsNav-shortcuts')));
    await tester.pumpAndSettle();
  }

  testWidgets('resets shortcuts to defaults', (tester) async {
    await pumpShortcuts(tester);

    expect(find.text('Reset Shortcuts'), findsWidgets);

    await tester.tap(find.byKey(const Key('shortcuts-reset')));
    await tester.pumpAndSettle();

    expect(find.text('Shortcuts reset to default'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_shortcut'), AppDefaults.correctionShortcut);
    expect(
      prefs.getString('app_shortcut_replace'),
      AppDefaults.replaceShortcut,
    );
    expect(prefs.getString('app_shortcut_append'), AppDefaults.appendShortcut);

    expect(
      methodCalls.where(
        (call) => call.method == MethodChannelMethods.updateShortcut,
      ),
      isNotEmpty,
    );
    expect(
      methodCalls.where(
        (call) => call.method == MethodChannelMethods.updateReplaceShortcut,
      ),
      isNotEmpty,
    );
    expect(
      methodCalls.where(
        (call) => call.method == MethodChannelMethods.updateAppendShortcut,
      ),
      isNotEmpty,
    );
  });
}
