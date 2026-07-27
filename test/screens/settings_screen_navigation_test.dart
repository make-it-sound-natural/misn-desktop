import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings/permissions_section.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.makeitsoundnatural/shortcut'),
          (call) async => switch (call.method) {
            'checkAccessibilityPermissions' => false,
            'getAppVersion' => {'version': '1.0.0', 'build': '1'},
            _ => null,
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.makeitsoundnatural/shortcut'),
          null,
        );
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    required double width,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('permissions section is reachable from the sidebar', (
    tester,
  ) async {
    await pumpSettings(tester, width: 1200);

    await tester.tap(find.byKey(const Key('settingsNav-permissions')));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionsSettingsSection), findsOneWidget);
  });

  testWidgets('sidebar keeps its labels at the smallest allowed window', (
    tester,
  ) async {
    // The native minimum is 980pt wide, so the sidebar never has to collapse;
    // the icon-rail variant was removed rather than left unreachable.
    await pumpSettings(tester, width: 980);

    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
  });
}
