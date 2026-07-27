import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelMethods.channelName);
  final methodCalls = <MethodCall>[];
  var permissionStatus = 'granted';
  var guideResult = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    methodCalls.clear();
    permissionStatus = 'granted';
    guideResult = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          if (call.method == MethodChannelMethods.getDefaultPrompt) return '';
          if (call.method ==
              MethodChannelMethods.requestScreenRecordingPermission) {
            return {'status': permissionStatus};
          }
          if (call.method ==
              MethodChannelMethods.checkScreenRecordingPermission) {
            return {'status': permissionStatus};
          }
          if (call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide) {
            return guideResult;
          }
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

  Future<void> pumpWritingSettings(WidgetTester tester) async {
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

    await tester.tap(find.byKey(const Key('settingsNav-writing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('screenshotContextModeField')), findsOneWidget);
  }

  Future<void> pumpDarkWritingSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(menuFontSize: AppDefaults.menuFontSize),
        darkTheme: AppTheme.dark(menuFontSize: AppDefaults.menuFontSize),
        themeMode: ThemeMode.dark,
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsNav-writing')));
    await tester.pumpAndSettle();
  }

  Future<void> selectFullScreen(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('screenshotContextModeField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full Screen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Writing settings saves screenshot mode when permission granted',
    (
      tester,
    ) async {
      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'fullScreen');
      expect(prefs.getString('pending_screenshot_context_mode'), isNull);
      expect(
        methodCalls.any(
          (call) =>
              call.method ==
                  MethodChannelMethods.requestScreenRecordingPermission &&
              call.arguments == 'fullScreen',
        ),
        isTrue,
      );
      expect(
        methodCalls.any(
          (call) =>
              call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide,
        ),
        isFalse,
      );
      expect(
        methodCalls.any(
          (call) =>
              call.method == MethodChannelMethods.setScreenshotContextMode &&
              call.arguments == 'fullScreen',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'Writing settings keeps off when manual guide is dismissed',
    (tester) async {
      permissionStatus = 'manualGrantRequired';
      guideResult = false;

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'off');
      expect(prefs.getString('pending_screenshot_context_mode'), 'fullScreen');
      expect(
        find.descendant(
          of: find.byKey(const Key('screenshotContextModeField')),
          matching: find.text('Off'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('screenshotContextModeField')),
          matching: find.text('Full Screen'),
        ),
        findsNothing,
      );
      expect(
        methodCalls.any(
          (call) =>
              call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide,
        ),
        isTrue,
      );
      expect(
        methodCalls.any(
          (call) =>
              call.method == MethodChannelMethods.setScreenshotContextMode &&
              call.arguments == 'off',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'Writing settings saves requested mode when manual guide succeeds',
    (tester) async {
      permissionStatus = 'manualGrantRequired';
      guideResult = true;

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'fullScreen');
      expect(prefs.getString('pending_screenshot_context_mode'), isNull);
      expect(
        methodCalls.any(
          (call) =>
              call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide,
        ),
        isTrue,
      );
    },
  );

  testWidgets('Writing settings keeps off when screenshot mode unsupported', (
    tester,
  ) async {
    permissionStatus = 'unsupported';

    await pumpWritingSettings(tester);
    await selectFullScreen(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('screenshot_context_mode'), 'off');
    expect(prefs.getString('pending_screenshot_context_mode'), isNull);
    expect(
      methodCalls.any(
        (call) =>
            call.method ==
            MethodChannelMethods.presentScreenRecordingPermissionGuide,
      ),
      isFalse,
    );
  });

  testWidgets(
    'Writing settings does not show guide when macOS prompt may be visible',
    (tester) async {
      permissionStatus = 'promptMayBeVisible';

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'off');
      expect(prefs.getString('pending_screenshot_context_mode'), 'fullScreen');
      expect(
        methodCalls.any(
          (call) =>
              call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide,
        ),
        isFalse,
      );
      expect(
        methodCalls.any(
          (call) =>
              call.method == MethodChannelMethods.setScreenshotContextMode &&
              call.arguments == 'off',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'Writing settings shows guide after native prompt is no longer active',
    (tester) async {
      permissionStatus = 'manualGrantRequired';
      guideResult = false;

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final guideCalls = methodCalls
          .where(
            (call) =>
                call.method ==
                MethodChannelMethods.presentScreenRecordingPermissionGuide,
          )
          .toList();
      expect(guideCalls, hasLength(1));
      expect(
        guideCalls.single.arguments,
        containsPair('openSettingsOnAppear', true),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'off');
      expect(prefs.getString('pending_screenshot_context_mode'), 'fullScreen');
    },
  );

  testWidgets(
    'Writing settings tells helper the app is already listed',
    (tester) async {
      permissionStatus = 'manualGrantRequired';
      guideResult = false;

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final guideCall = methodCalls.singleWhere(
        (call) =>
            call.method ==
            MethodChannelMethods.presentScreenRecordingPermissionGuide,
      );
      expect(guideCall.arguments, containsPair('manualAddRequired', false));
      expect(
        guideCall.arguments,
        containsPair(
          'message',
          'Enable Make It Sound Natural in Screen Recording, then check again.',
        ),
      );
    },
  );

  testWidgets(
    'Writing settings leaves default variant unchanged when permission missing',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'default_variant': 'formal',
        'screenshot_context_mode': 'off',
      });
      permissionStatus = 'manualGrantRequired';
      guideResult = false;

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('default_variant'), 'formal');
      expect(prefs.getString('screenshot_context_mode'), 'off');
      expect(prefs.getString('pending_screenshot_context_mode'), 'fullScreen');
    },
  );

  testWidgets(
    'Writing settings stores pending mode when permission remains missing',
    (
      tester,
    ) async {
      permissionStatus = 'manualGrantRequired';
      guideResult = false;

      await pumpWritingSettings(tester);
      await selectFullScreen(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'off');
      expect(prefs.getString('pending_screenshot_context_mode'), 'fullScreen');
      expect(
        find.descendant(
          of: find.byKey(const Key('screenshotContextModeField')),
          matching: find.text('Off'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('will turn on after Screen Recording is granted'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Writing settings restores pending mode after restart when granted',
    (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'screenshot_context_mode': 'off',
        'pending_screenshot_context_mode': 'fullScreen',
      });
      permissionStatus = 'granted';

      await pumpWritingSettings(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'fullScreen');
      expect(prefs.getString('pending_screenshot_context_mode'), isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('screenshotContextModeField')),
          matching: find.text('Full Screen'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Writing settings keeps pending mode after restart when still missing',
    (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'screenshot_context_mode': 'off',
        'pending_screenshot_context_mode': 'activeApplication',
      });
      permissionStatus = 'manualGrantRequired';

      await pumpWritingSettings(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('screenshot_context_mode'), 'off');
      expect(
        prefs.getString('pending_screenshot_context_mode'),
        'activeApplication',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('screenshotContextModeField')),
          matching: find.text('Off'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Writing settings preserves existing active mode when granted', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'screenshot_context_mode': 'activeApplication',
    });
    permissionStatus = 'granted';

    await pumpWritingSettings(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('screenshotContextModeField')),
        matching: find.text('Application'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Writing pop-up selects use readable dark colors', (
    tester,
  ) async {
    await pumpDarkWritingSettings(tester);

    final selects = find.byType(AppPopupSelect<String>);
    expect(selects, findsWidgets);

    // The control reads its fill from the scheme, which maps to the dark
    // field token; asserting the rendered decoration catches a regression in
    // either direction.
    final container = tester.widget<Container>(
      find
          .descendant(of: selects.first, matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.darkField);
  });
}
