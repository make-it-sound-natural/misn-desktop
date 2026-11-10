import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/accessibility_context_mode.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/screens/home_screen.dart';
import 'package:make_it_sound_natural/screens/onboarding/onboarding_gate.dart';
import 'package:make_it_sound_natural/services/onboarding_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelMethods.channelName);

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case MethodChannelMethods.checkAccessibilityPermissions:
              return false;
            case MethodChannelMethods.requestAccessibilityPermission:
              return true;
            case MethodChannelMethods.getDefaultPrompt:
              return 'Default prompt';
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpGate(WidgetTester tester) async {
    // The Ahem test font is much wider than the system font. Use a tall
    // window so the App context step keeps its buttons on screen.
    tester.view
      ..physicalSize = const Size(1180, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingGate(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseScreenshotModeAndContinue(
    WidgetTester tester,
    String mode,
  ) async {
    await tester.tap(find.text(mode));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
  }

  void setScreenshotOnboardingState({
    Map<String, Object> extraValues = const {},
  }) {
    SharedPreferences.setMockInitialValues({
      ...extraValues,
      OnboardingService.completedKey: false,
      'onboarding_required_setup_completed': true,
      'onboarding_screenshot_context_skipped': false,
      'onboarding_accessibility_skipped': false,
      'onboarding_last_step': OnboardingStep.screenshotContext.value,
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
    });
  }

  testWidgets('shows onboarding on clean install', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpGate(tester);

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('shows home when onboarding is completed', (tester) async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.completedKey: true,
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
    });

    await pumpGate(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const Key('onboarding-screen')), findsNothing);
  });

  testWidgets('completion button stores state and opens home', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-accessibility-grant')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-skip-optional')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-complete')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(OnboardingService.completedKey), isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Off Screenshot context completes without native permission', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    final nativeMethods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeMethods.add(call.method);
          return null;
        });

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(
      nativeMethods,
      isNot(contains(MethodChannelMethods.requestScreenRecordingPermission)),
    );
  });

  testWidgets('nearby text opt-in saves App context and syncs native', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    final nativeCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          return null;
        });

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('onboarding-nearby-text-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('accessibility_context_mode'),
      AccessibilityContextMode.fieldAndNearby.value,
    );
    final syncCalls = nativeCalls.where(
      (call) => call.method == MethodChannelMethods.setAccessibilityContextMode,
    );
    expect(syncCalls.map((call) => call.arguments), [
      AccessibilityContextMode.fieldAndNearby.value,
    ]);
    // Nearby text alone never asks for Screen Recording.
    expect(
      nativeCalls.map((call) => call.method),
      isNot(contains(MethodChannelMethods.requestScreenRecordingPermission)),
    );
    expect(find.byKey(const Key('onboarding-complete')), findsOneWidget);
  });

  testWidgets('Continue without the opt-in keeps the migrated App context', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    final nativeMethods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeMethods.add(call.method);
          return null;
        });

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('accessibility_context_mode'), isNull);
    expect(
      nativeMethods,
      isNot(contains(MethodChannelMethods.setAccessibilityContextMode)),
    );
  });

  testWidgets(
    'Application Screenshot context requests permission and saves grant',
    (
      tester,
    ) async {
      setScreenshotOnboardingState();
      final requestArgs = <Object?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method ==
                MethodChannelMethods.requestScreenRecordingPermission) {
              requestArgs.add(call.arguments);
              return {'status': 'granted'};
            }
            return null;
          });

      await pumpGate(tester);
      await chooseScreenshotModeAndContinue(tester, 'Application');

      final prefs = await SharedPreferences.getInstance();
      expect(requestArgs, [ScreenshotContextMode.activeApplication.value]);
      expect(
        prefs.getString('screenshot_context_mode'),
        ScreenshotContextMode.activeApplication.value,
      );
      expect(prefs.getString('pending_screenshot_context_mode'), isNull);
    },
  );

  testWidgets('non-granted Screenshot context is saved pending, not active', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method ==
              MethodChannelMethods.requestScreenRecordingPermission) {
            return {'status': 'manualGrantRequired'};
          }
          return null;
        });

    await pumpGate(tester);
    await chooseScreenshotModeAndContinue(tester, 'Full Screen');

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('screenshot_context_mode'),
      isNot(ScreenshotContextMode.fullScreen.value),
    );
    expect(
      prefs.getString('pending_screenshot_context_mode'),
      ScreenshotContextMode.fullScreen.value,
    );
  });

  testWidgets(
    'prompt-visible Screenshot context does not show custom guide',
    (tester) async {
      setScreenshotOnboardingState();
      final methodCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls.add(call);
            if (call.method ==
                MethodChannelMethods.requestScreenRecordingPermission) {
              return {'status': 'promptMayBeVisible'};
            }
            return null;
          });

      await pumpGate(tester);
      await chooseScreenshotModeAndContinue(tester, 'Full Screen');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('screenshot_context_mode'),
        ScreenshotContextMode.off.value,
      );
      expect(
        prefs.getString('pending_screenshot_context_mode'),
        ScreenshotContextMode.fullScreen.value,
      );
      expect(
        methodCalls.any(
          (call) =>
              call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide,
        ),
        isFalse,
      );
    },
  );
  testWidgets('Skip clears a screenshot mode pending Screen Recording', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method ==
              MethodChannelMethods.requestScreenRecordingPermission) {
            return {'status': 'manualGrantRequired'};
          }
          return null;
        });

    await pumpGate(tester);
    await chooseScreenshotModeAndContinue(tester, 'Full Screen');
    await tester.tap(find.byKey(const Key('onboarding-skip-optional')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_screenshot_context_mode'), isNull);
    expect(
      prefs.getString('screenshot_context_mode'),
      ScreenshotContextMode.off.value,
    );
  });

  testWidgets('a resumed step restores the pending mode and its status', (
    tester,
  ) async {
    setScreenshotOnboardingState(
      extraValues: {
        'pending_screenshot_context_mode':
            ScreenshotContextMode.fullScreen.value,
      },
    );
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method ==
              MethodChannelMethods.checkScreenRecordingPermission) {
            return {'status': 'manualGrantRequired'};
          }
          return null;
        });

    await pumpGate(tester);

    final control = tester.widget<SegmentedButton<ScreenshotContextMode>>(
      find.byKey(const Key('onboarding-screenshot-mode-control')),
    );
    expect(control.selected, {ScreenshotContextMode.fullScreen});
    expect(
      find.textContaining('Screen Recording is not granted yet'),
      findsOneWidget,
    );
    // Resuming only checks; it never prompts or shows the helper.
    expect(
      methods,
      isNot(contains(MethodChannelMethods.requestScreenRecordingPermission)),
    );
    expect(
      methods,
      isNot(
        contains(MethodChannelMethods.presentScreenRecordingPermissionGuide),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('pending_screenshot_context_mode'),
      ScreenshotContextMode.fullScreen.value,
    );
  });

  testWidgets('Check again turns the pending mode on once granted', (
    tester,
  ) async {
    setScreenshotOnboardingState(
      extraValues: {
        'pending_screenshot_context_mode':
            ScreenshotContextMode.activeApplication.value,
      },
    );
    var granted = false;
    final syncedModes = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case MethodChannelMethods.checkScreenRecordingPermission:
              return {'status': granted ? 'granted' : 'manualGrantRequired'};
            case MethodChannelMethods.setScreenshotContextMode:
              syncedModes.add(call.arguments);
          }
          return null;
        });

    await pumpGate(tester);
    granted = true;
    await tester.tap(
      find.byKey(const Key('onboarding-screenshot-check-again')),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('screenshot_context_mode'),
      ScreenshotContextMode.activeApplication.value,
    );
    expect(prefs.getString('pending_screenshot_context_mode'), isNull);
    expect(syncedModes.last, ScreenshotContextMode.activeApplication.value);
    expect(find.text('Screenshot context is enabled.'), findsOneWidget);
  });

  testWidgets('Open Screen Recording settings shows the helper, then checks', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case MethodChannelMethods.requestScreenRecordingPermission:
            case MethodChannelMethods.checkScreenRecordingPermission:
              return {'status': 'manualGrantRequired'};
            case MethodChannelMethods.presentScreenRecordingPermissionGuide:
              return false;
          }
          return null;
        });

    await pumpGate(tester);
    await chooseScreenshotModeAndContinue(tester, 'Full Screen');
    expect(
      methods,
      isNot(
        contains(MethodChannelMethods.presentScreenRecordingPermissionGuide),
      ),
    );
    methods.clear();

    await tester.tap(
      find.byKey(const Key('onboarding-screenshot-open-settings')),
    );
    await tester.pumpAndSettle();

    expect(
      methods,
      containsAllInOrder([
        MethodChannelMethods.presentScreenRecordingPermissionGuide,
        MethodChannelMethods.checkScreenRecordingPermission,
      ]),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('pending_screenshot_context_mode'),
      ScreenshotContextMode.fullScreen.value,
    );
  });

  testWidgets('Off and Continue turn off a mode granted by Check again', (
    tester,
  ) async {
    setScreenshotOnboardingState();
    final syncedModes = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case MethodChannelMethods.requestScreenRecordingPermission:
              return {'status': 'manualGrantRequired'};
            case MethodChannelMethods.checkScreenRecordingPermission:
              return {'status': 'granted'};
            case MethodChannelMethods.setScreenshotContextMode:
              syncedModes.add(call.arguments);
          }
          return null;
        });

    await pumpGate(tester);
    await chooseScreenshotModeAndContinue(tester, 'Full Screen');
    await tester.tap(
      find.byKey(const Key('onboarding-screenshot-check-again')),
    );
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('screenshot_context_mode'),
      ScreenshotContextMode.fullScreen.value,
    );

    await chooseScreenshotModeAndContinue(tester, 'Off');

    expect(
      prefs.getString('screenshot_context_mode'),
      ScreenshotContextMode.off.value,
    );
    expect(prefs.getString('pending_screenshot_context_mode'), isNull);
    expect(syncedModes.last, ScreenshotContextMode.off.value);
    expect(find.byKey(const Key('onboarding-complete')), findsOneWidget);
  });

  testWidgets('a resumed mode on unsupported macOS is dropped', (
    tester,
  ) async {
    setScreenshotOnboardingState(
      extraValues: {
        'pending_screenshot_context_mode':
            ScreenshotContextMode.fullScreen.value,
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method ==
              MethodChannelMethods.checkScreenRecordingPermission) {
            return {'status': 'unsupported'};
          }
          return null;
        });

    await pumpGate(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_screenshot_context_mode'), isNull);
    expect(
      prefs.getString('screenshot_context_mode'),
      ScreenshotContextMode.off.value,
    );
    expect(
      find.text('Screenshot context requires macOS 14 or later.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding-screenshot-check-again')),
      findsNothing,
    );
  });
}
