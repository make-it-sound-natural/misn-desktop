import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/onboarding_setup_state.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/screens/onboarding/onboarding_screen.dart';

void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    OnboardingSetupState initialState = const OnboardingSetupState.initial(),
    ValueChanged<OnboardingSetupState>? onStateChanged,
    VoidCallback? onCompleted,
    Future<bool> Function()? checkAccessibility,
    Future<bool> Function()? requestAccessibility,
    Future<ScreenRecordingPermissionStatus> Function(
      ScreenshotContextMode mode,
    )?
    onScreenshotContextSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(
          initialState: initialState,
          onStateChanged: onStateChanged ?? (_) {},
          onCompleted: onCompleted ?? () {},
          checkAccessibility: checkAccessibility ?? () async => false,
          requestAccessibility: requestAccessibility ?? () async => false,
          onScreenshotContextSelected:
              onScreenshotContextSelected ??
              (_) async => ScreenRecordingPermissionStatus.granted,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts at provider step', (tester) async {
    await pumpOnboarding(tester);

    expect(find.byKey(const Key('onboarding-screen')), findsOneWidget);
    expect(find.text('Set up Make It Sound Natural'), findsOneWidget);
    expect(find.text('AI Provider'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('continues through required step', (tester) async {
    final states = <OnboardingSetupState>[];
    await pumpOnboarding(tester, onStateChanged: states.add);

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Accessibility'), findsOneWidget);
    expect(states.last.lastStep, OnboardingStep.accessibility);

    await tester.tap(find.byKey(const Key('onboarding-accessibility-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Screenshot context'), findsOneWidget);
    expect(states.last.requiredSetupCompleted, isTrue);
    expect(states.last.lastStep, OnboardingStep.screenshotContext);
  });

  const accessibilityState = OnboardingSetupState(
    completed: false,
    requiredSetupCompleted: false,
    screenshotContextSkipped: false,
    accessibilitySkipped: false,
    lastStep: OnboardingStep.accessibility,
  );

  testWidgets('shows explanation before Accessibility request', (tester) async {
    final calls = <String>[];
    await pumpOnboarding(
      tester,
      initialState: accessibilityState,
      checkAccessibility: () async {
        calls.add('check');
        return false;
      },
      requestAccessibility: () async {
        calls.add('request');
        return false;
      },
    );

    expect(
      find.textContaining('read and replace selected text'),
      findsOneWidget,
    );
    expect(calls, <String>['check']);

    await tester.tap(find.byKey(const Key('onboarding-accessibility-grant')));
    await tester.pumpAndSettle();

    expect(calls, <String>['check', 'request']);
  });

  testWidgets('granted Accessibility advances to Screenshot context', (
    tester,
  ) async {
    final states = <OnboardingSetupState>[];
    await pumpOnboarding(
      tester,
      initialState: accessibilityState,
      onStateChanged: states.add,
      checkAccessibility: () async => false,
      requestAccessibility: () async => true,
    );

    await tester.tap(find.byKey(const Key('onboarding-accessibility-grant')));
    await tester.pumpAndSettle();

    expect(find.text('Screenshot context'), findsOneWidget);
    expect(states.last.requiredSetupCompleted, isTrue);
  });

  testWidgets('still missing Accessibility shows warning and skip option', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      initialState: accessibilityState,
      checkAccessibility: () async => false,
      requestAccessibility: () async => false,
    );

    await tester.tap(find.byKey(const Key('onboarding-accessibility-grant')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('will not work until permission is granted'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding-accessibility-skip')),
      findsOneWidget,
    );
  });

  testWidgets('skips optional screenshot context and completes', (
    tester,
  ) async {
    final states = <OnboardingSetupState>[];
    var completed = false;
    await pumpOnboarding(
      tester,
      initialState: const OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: true,
        screenshotContextSkipped: false,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.screenshotContext,
      ),
      onStateChanged: states.add,
      onCompleted: () => completed = true,
    );

    await tester.tap(find.byKey(const Key('onboarding-skip-optional')));
    await tester.pumpAndSettle();

    expect(states.last.screenshotContextSkipped, isTrue);
    expect(find.text('Finish setup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-complete')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('renders Screenshot context choices with privacy copy', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      initialState: const OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: true,
        screenshotContextSkipped: false,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.screenshotContext,
      ),
    );

    expect(find.text('Screenshot context'), findsOneWidget);
    expect(
      find.textContaining('screenshots may include sensitive'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding-screenshot-mode-off')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding-screenshot-mode-application')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('onboarding-screenshot-mode-full-screen')),
      findsOneWidget,
    );
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Application'), findsOneWidget);
    expect(find.text('Full Screen'), findsOneWidget);
  });

  testWidgets('keeps Screen Recording request idle when Off continues', (
    tester,
  ) async {
    final states = <OnboardingSetupState>[];
    final requestedModes = <ScreenshotContextMode>[];
    await pumpOnboarding(
      tester,
      initialState: const OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: true,
        screenshotContextSkipped: false,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.screenshotContext,
      ),
      onStateChanged: states.add,
      onScreenshotContextSelected: (mode) async {
        requestedModes.add(mode);
        return ScreenRecordingPermissionStatus.granted;
      },
    );

    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(requestedModes, isEmpty);
    expect(states.last.screenshotContextSkipped, isTrue);
    expect(states.last.lastStep, OnboardingStep.done);
  });

  testWidgets(
    'passes Application mode to Screen Recording handoff on continue',
    (
      tester,
    ) async {
      final states = <OnboardingSetupState>[];
      final requestedModes = <ScreenshotContextMode>[];
      await pumpOnboarding(
        tester,
        initialState: const OnboardingSetupState(
          completed: false,
          requiredSetupCompleted: true,
          screenshotContextSkipped: false,
          accessibilitySkipped: false,
          lastStep: OnboardingStep.screenshotContext,
        ),
        onStateChanged: states.add,
        onScreenshotContextSelected: (mode) async {
          requestedModes.add(mode);
          return ScreenRecordingPermissionStatus.granted;
        },
      );

      await tester.tap(find.text('Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();

      expect(requestedModes, [ScreenshotContextMode.activeApplication]);
      expect(states.last.screenshotContextSkipped, isFalse);
      expect(states.last.lastStep, OnboardingStep.done);
    },
  );

  testWidgets(
    'passes Full Screen mode to Screen Recording handoff on continue',
    (
      tester,
    ) async {
      final requestedModes = <ScreenshotContextMode>[];
      await pumpOnboarding(
        tester,
        initialState: const OnboardingSetupState(
          completed: false,
          requiredSetupCompleted: true,
          screenshotContextSkipped: false,
          accessibilitySkipped: false,
          lastStep: OnboardingStep.screenshotContext,
        ),
        onScreenshotContextSelected: (mode) async {
          requestedModes.add(mode);
          return ScreenRecordingPermissionStatus.granted;
        },
      );

      await tester.tap(find.text('Full Screen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-continue')));
      await tester.pumpAndSettle();

      expect(requestedModes, [ScreenshotContextMode.fullScreen]);
    },
  );

  testWidgets('shows Screenshot context handoff status after non-Off request', (
    tester,
  ) async {
    await pumpOnboarding(
      tester,
      initialState: const OnboardingSetupState(
        completed: false,
        requiredSetupCompleted: true,
        screenshotContextSkipped: false,
        accessibilitySkipped: false,
        lastStep: OnboardingStep.screenshotContext,
      ),
      onScreenshotContextSelected: (_) async {
        return ScreenRecordingPermissionStatus.manualGrantRequired;
      },
    );

    await tester.tap(find.text('Application'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('onboarding-screenshot-status')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Screen Recording permission is still needed'),
      findsOneWidget,
    );
  });
}
