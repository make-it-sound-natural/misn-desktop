import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/services/update_service.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Set up mock method channel handlers
  void setupMockMethodChannel({
    bool automaticUpdateChecks = true,
    String? lastUpdateCheck,
    bool updateCheckSuccess = true,
    String? updateCheckError,
    String version = '1.0.0',
    String build = '1',
    String? releaseChannel,
  }) {
    const channel = MethodChannel('com.makeitsoundnatural/shortcut');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getAppVersion':
              return {
                'version': version,
                'build': build,
                ...?(releaseChannel == null
                    ? null
                    : {'releaseChannel': releaseChannel}),
              };
            case 'getLastUpdateCheck':
              return lastUpdateCheck;
            case 'getAutomaticUpdateChecks':
              return automaticUpdateChecks;
            case 'setAutomaticUpdateChecks':
              return null;
            case 'checkForUpdates':
              return {
                'success': updateCheckSuccess,
                'error': updateCheckError,
              };
            case 'checkAccessibilityPermissions':
              return true;
            case 'registerShortcut':
              return null;
            case 'getDefaultPrompt':
              return 'Default prompt';
            case 'setProvider':
            case 'setApiKey':
            case 'setOpenRouterApiKey':
            case 'setModel':
            case 'setDefaultVariant':
            case 'setCustomPrompt':
              return null;
            default:
              return null;
          }
        });
  }

  void tearDownMockMethodChannel() {
    const channel = MethodChannel('com.makeitsoundnatural/shortcut');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }

  Widget createTestApp() {
    return const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: SettingsScreen(),
    );
  }

  Future<void> openUpdates(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('settingsNav-updates')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('settingsNav-updates')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('Settings Updates Section', () {
    setUp(() {
      UpdateService().debugResetSettingsSnapshot();
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({
        'api_provider': 'openai',
        'openai_api_key': '',
        'openrouter_api_key': '',
        'openai_model': 'gpt-5.4-mini',
        'app_shortcut': AppDefaults.correctionShortcut,
        'app_shortcut_replace': AppDefaults.replaceShortcut,
        'app_shortcut_append': AppDefaults.appendShortcut,
        'default_variant': 'Balanced',
        'custom_prompt': '',
      });
      setupMockMethodChannel();
    });

    tearDown(() {
      UpdateService().debugResetSettingsSnapshot();
      tearDownMockMethodChannel();
    });

    testWidgets(
      'falls back to a valid model when stored model is removed',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'api_provider': 'openrouter',
          'openai_api_key': '',
          'openrouter_api_key': '',
          'openai_model': 'minimax/minimax-m2.7',
          'app_shortcut': AppDefaults.correctionShortcut,
          'app_shortcut_replace': AppDefaults.replaceShortcut,
          'app_shortcut_append': AppDefaults.appendShortcut,
          'default_variant': 'Balanced',
          'custom_prompt': '',
        });
        setupMockMethodChannel();

        await tester.pumpWidget(createTestApp());
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);

        // The picker spans every provider, so its value carries the owning
        // provider alongside the slug.
        final modelPicker = tester.widget<AppPopupSelect<String>>(
          find.byKey(const Key('apiProvider-modelPicker')),
        );
        expect(
          modelPicker.value,
          equals('openrouter::google/gemini-3-flash-preview'),
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('openai_model'),
          equals('google/gemini-3-flash-preview'),
        );
      },
    );

    testWidgets('displays app information with version and channel', (
      tester,
    ) async {
      setupMockMethodChannel(
        version: '1.2.3',
        build: '42',
        releaseChannel: 'nightly',
      );

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      expect(find.text('App information'), findsOneWidget);
      expect(find.text('Version 1.2.3'), findsOneWidget);
      expect(find.text('Nightly'), findsOneWidget);
      expect(find.text('Build 42 • Nightly'), findsNothing);
    });

    testWidgets('copies app diagnostics to clipboard', (tester) async {
      setupMockMethodChannel(
        version: '1.2.3-nightly.20260603.123',
        build: '77',
      );
      final clipboardWrites = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final data = call.arguments as Map<Object?, Object?>;
              clipboardWrites.add(data['text']! as String);
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      await tester.tap(find.byKey(const Key('copyAppDiagnostics-button')));
      await tester.pump();

      expect(
        clipboardWrites.single,
        [
          'Make It Sound Natural',
          'Version: 1.2.3-nightly.20260603.123',
          'Build: 77',
          'Channel: Nightly',
        ].join('\n'),
      );
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('displays Updates section title', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      expect(find.text('Updates'), findsAtLeast(1));
    });

    testWidgets('Check for Updates button is visible in idle state', (
      tester,
    ) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      expect(find.text('Check for Updates'), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);
    });

    testWidgets('Last checked shows "Never" when no previous check', (
      tester,
    ) async {
      setupMockMethodChannel();
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      expect(find.text('Last checked: Never'), findsOneWidget);
    });

    testWidgets('automatic checks toggle is visible', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      expect(find.text('Automatic checks'), findsOneWidget);
      expect(find.text('Check for updates on launch'), findsOneWidget);
      expect(
        find.byKey(const Key('automaticUpdateChecks-switch')),
        findsOneWidget,
      );
    });

    testWidgets('automatic checks first visible switch state is off', (
      tester,
    ) async {
      setupMockMethodChannel(automaticUpdateChecks: false);

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('automaticUpdateChecks-switch')),
      );
      expect(switchWidget.value, isFalse);
    });

    testWidgets('automatic checks first visible switch state is on', (
      tester,
    ) async {
      setupMockMethodChannel();

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('automaticUpdateChecks-switch')),
      );
      expect(switchWidget.value, isTrue);
    });

    testWidgets('automatic checks shows placeholder while loading', (
      tester,
    ) async {
      final automaticUpdateChecks = Completer<bool>();
      const channel = MethodChannel('com.makeitsoundnatural/shortcut');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'getAutomaticUpdateChecks':
                return automaticUpdateChecks.future;
              case 'getAppVersion':
                return {'version': '1.0.0', 'build': '1'};
              case 'getLastUpdateCheck':
                return null;
              case 'checkAccessibilityPermissions':
                return true;
              case 'getDefaultPrompt':
                return 'Default prompt';
              case 'setProvider':
              case 'setApiKey':
              case 'setOpenRouterApiKey':
              case 'setModel':
              case 'setDefaultVariant':
              case 'setCustomPrompt':
                return null;
              default:
                return null;
            }
          });

      await tester.pumpWidget(createTestApp());
      await tester.tap(find.byKey(const Key('settingsNav-updates')));
      await tester.pump();

      expect(
        find.byKey(const Key('automaticUpdateChecks-switch')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('automaticUpdateChecks-placeholder')),
        findsOneWidget,
      );

      automaticUpdateChecks.complete(false);
      await tester.pump();
      await tester.pump();

      final switchWidget = tester.widget<Switch>(
        find.byKey(const Key('automaticUpdateChecks-switch')),
      );
      expect(switchWidget.value, isFalse);
    });

    testWidgets('tapping Check button and completing shows result', (
      tester,
    ) async {
      // Set a larger surface size for this test
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      // Find and tap the Check button
      final checkButton = find.text('Check');
      expect(checkButton, findsOneWidget);

      await tester.tap(checkButton);
      // Since mock returns immediately, pump to process the result
      await tester.pump(const Duration(milliseconds: 100));

      // Should show up to date (mock returns success immediately)
      expect(find.text('Up to date'), findsOneWidget);

      // Pump through the 3-second auto-reset timer to avoid pending timer error
      await tester.pump(const Duration(seconds: 3));

      // Reset surface size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('shows "Check failed" after failed check', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      setupMockMethodChannel(
        updateCheckSuccess: false,
        updateCheckError: 'Network error',
      );
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      // Tap Check button
      await tester.tap(find.text('Check'));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error state
      expect(find.text('Check failed'), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);

      // Pump through the 3-second auto-reset timer to avoid pending timer error
      await tester.pump(const Duration(seconds: 3));

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('button resets to idle after 3 seconds', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      // Tap Check button
      await tester.tap(find.text('Check'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Up to date'), findsOneWidget);

      // Wait for auto-reset (3 seconds)
      await tester.pump(const Duration(seconds: 3));

      // Should be back to idle
      expect(find.text('Check for Updates'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('toggle switch changes automatic update setting', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      bool? lastSetValue;
      const channel = MethodChannel('com.makeitsoundnatural/shortcut');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'setAutomaticUpdateChecks':
                lastSetValue = call.arguments as bool;
                return null;
              case 'getAutomaticUpdateChecks':
                return true;
              case 'getAppVersion':
                return {'version': '1.0.0', 'build': '1'};
              case 'getLastUpdateCheck':
                return null;
              case 'checkAccessibilityPermissions':
                return true;
              case 'getDefaultPrompt':
                return 'Default prompt';
              case 'setProvider':
              case 'setApiKey':
              case 'setOpenRouterApiKey':
              case 'setModel':
              case 'setDefaultVariant':
              case 'setCustomPrompt':
                return null;
              default:
                return null;
            }
          });

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await openUpdates(tester);

      // Find the Switch widgets
      final automaticUpdateSwitch = find.byKey(
        const Key('automaticUpdateChecks-switch'),
      );
      expect(automaticUpdateSwitch, findsOneWidget);

      // Tap the first switch (automatic updates)
      await tester.tap(automaticUpdateSwitch);
      await tester.pump();

      // Verify the value was sent to native
      expect(lastSetValue, isFalse);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
