import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/services/update_service.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appChannel = MethodChannel('com.makeitsoundnatural/shortcut');
const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
const _repo = 'https://github.com/make-it-sound-natural/misn-desktop';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final launchedUrls = <String>[];
  final clipboardWrites = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockNative({
    String version = '1.2.3-nightly.20260603.1',
    String build = '77',
    String? releaseChannel,
  }) {
    messenger.setMockMethodCallHandler(_appChannel, (call) async {
      switch (call.method) {
        case 'getAppVersion':
          return {
            'version': version,
            'build': build,
            ...?(releaseChannel == null
                ? null
                : {'releaseChannel': releaseChannel}),
          };
        case 'getAutomaticUpdateChecks':
          return true;
        case 'checkAccessibilityPermissions':
          return true;
        case 'getDefaultPrompt':
          return 'Default prompt';
        default:
          return null;
      }
    });
  }

  setUp(() {
    UpdateService().debugResetSettingsSnapshot();
    SharedPreferences.setMockInitialValues({});
    launchedUrls.clear();
    clipboardWrites.clear();
    mockNative();
    messenger
      ..setMockMethodCallHandler(_urlLauncherChannel, (call) async {
        if (call.method == 'launch') {
          final args = call.arguments as Map<Object?, Object?>;
          launchedUrls.add(args['url']! as String);
          return true;
        }
        return null;
      })
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = call.arguments as Map<Object?, Object?>;
          clipboardWrites.add(data['text']! as String);
        }
        return null;
      });
  });

  tearDown(() {
    UpdateService().debugResetSettingsSnapshot();
    messenger
      ..setMockMethodCallHandler(_appChannel, null)
      ..setMockMethodCallHandler(_urlLauncherChannel, null)
      ..setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> openAbout(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsNav-about')));
    await tester.pumpAndSettle();
  }

  testWidgets('About is the last sidebar item', (tester) async {
    await openAbout(tester);

    final aboutTop = tester
        .getTopLeft(find.byKey(const Key('settingsNav-about')))
        .dy;
    final advancedTop = tester
        .getTopLeft(find.byKey(const Key('settingsNav-advanced')))
        .dy;
    expect(aboutTop, greaterThan(advancedTop));
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('shows icon, name, version, build and channel', (tester) async {
    await openAbout(tester);

    expect(find.byKey(const Key('about-appIcon')), findsOneWidget);
    expect(find.text('Make It Sound Natural'), findsOneWidget);
    expect(find.text('Version 1.2.3-nightly.20260603.1'), findsOneWidget);
    expect(find.text('Build'), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    expect(find.text('Release channel'), findsOneWidget);
    expect(find.text('Nightly'), findsOneWidget);
  });

  testWidgets('prefers the native release channel', (tester) async {
    mockNative(version: '2.0.0', releaseChannel: 'beta');
    await openAbout(tester);

    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('renders in light and dark themes', (tester) async {
    for (final theme in [
      AppTheme.light(menuFontSize: 13),
      AppTheme.dark(menuFontSize: 13),
    ]) {
      UpdateService().debugResetSettingsSnapshot();
      await openAbout(tester, theme: theme);

      expect(tester.takeException(), isNull);
      expect(find.text('Make It Sound Natural'), findsOneWidget);
      expect(find.byKey(const Key('about-whatsNew')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('copies app diagnostics to clipboard', (tester) async {
    await openAbout(tester);

    await tester.tap(find.byKey(const Key('copyAppDiagnostics-button')));
    await tester.pump();

    expect(
      clipboardWrites.single,
      [
        'Make It Sound Natural',
        'Version: 1.2.3-nightly.20260603.1',
        'Build: 77',
        'Channel: Nightly',
      ].join('\n'),
    );
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets("What's new opens the releases page", (tester) async {
    await openAbout(tester);

    await tester.tap(find.byKey(const Key('about-whatsNew')));
    await tester.pump();

    expect(launchedUrls.single, '$_repo/releases');
  });

  testWidgets('Report an issue opens a new issue prefilled with diagnostics', (
    tester,
  ) async {
    await openAbout(tester);

    await tester.tap(find.byKey(const Key('about-reportIssue')));
    await tester.pump();

    final uri = Uri.parse(launchedUrls.single);
    expect(uri.host, 'github.com');
    expect(uri.path, '/make-it-sound-natural/misn-desktop/issues/new');
    expect(
      uri.queryParameters['body'],
      [
        'Make It Sound Natural',
        'Version: 1.2.3-nightly.20260603.1',
        'Build: 77',
        'Channel: Nightly',
      ].join('\n'),
    );
  });

  testWidgets('privacy policy and license open the repository files', (
    tester,
  ) async {
    await openAbout(tester);

    await tester.tap(find.byKey(const Key('about-privacyPolicy')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('about-license')));
    await tester.pump();

    expect(launchedUrls, [
      '$_repo/blob/master/PRIVACY_POLICY.md',
      '$_repo/blob/master/LICENSE',
    ]);
  });

  testWidgets('shows a toast when a link cannot be opened', (tester) async {
    messenger.setMockMethodCallHandler(_urlLauncherChannel, (call) async {
      return false;
    });
    await openAbout(tester);

    await tester.tap(find.byKey(const Key('about-license')));
    await tester.pump();

    expect(find.text("Couldn't open the link"), findsOneWidget);
  });
}
