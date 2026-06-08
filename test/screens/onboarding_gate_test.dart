import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
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

  void setScreenshotOnboardingState() {
    SharedPreferences.setMockInitialValues({
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
      await tester.tap(find.text('Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();

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
    await tester.tap(find.text('Full Screen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

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
      await tester.tap(find.text('Full Screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();

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
}
