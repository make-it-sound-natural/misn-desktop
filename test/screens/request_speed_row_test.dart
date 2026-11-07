import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/request_speed.dart';
import 'package:make_it_sound_natural/screens/settings/request_speed_row.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelMethods.channelName);
  const pickerKey = Key('apiProvider-speedPicker');
  late List<MethodCall> methodCalls;
  late List<String?> savedAtNativeCall;
  var nativeFails = false;

  void setupSettings({
    String provider = AppDefaults.openAiProvider,
    String model = 'gpt-6.1-sol',
    RequestSpeed speed = RequestSpeed.standard,
  }) {
    SharedPreferences.setMockInitialValues({
      'api_provider': provider,
      'openai_model': model,
      'request_speed': speed.name,
    });
  }

  Future<void> pumpRow(
    WidgetTester tester, {
    String provider = AppDefaults.openAiProvider,
    String model = 'gpt-6.1-sol',
    Locale locale = const Locale('en'),
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark
            ? AppTheme.dark(menuFontSize: AppDefaults.menuFontSizeMax)
            : AppTheme.light(menuFontSize: AppDefaults.menuFontSizeMax),
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RequestSpeedRow(provider: provider, model: model),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    nativeFails = false;
    methodCalls = [];
    savedAtNativeCall = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          final prefs = await SharedPreferences.getInstance();
          savedAtNativeCall.add(prefs.getString('request_speed'));
          if (nativeFails) {
            throw PlatformException(code: 'SAVE_FAILED');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const scenarios = [
    (
      name: 'description',
      provider: AppDefaults.openAiProvider,
      model: 'gpt-6.1-sol',
      speed: RequestSpeed.standard,
    ),
    (
      name: 'runs at',
      provider: AppDefaults.openAiProvider,
      model: 'gpt-6-luna',
      speed: RequestSpeed.ultrafast,
    ),
    (
      name: 'unavailable',
      provider: AppDefaults.openRouterProvider,
      model: 'google/gemini-3-flash-preview',
      speed: RequestSpeed.ultrafast,
    ),
  ];
  for (final locale in AppLocalizations.supportedLocales) {
    for (final dark in [false, true]) {
      for (final scenario in scenarios) {
        testWidgets(
          'speed row fits $locale, dark=$dark, ${scenario.name}, large text',
          (tester) async {
            setupSettings(
              provider: scenario.provider,
              model: scenario.model,
              speed: scenario.speed,
            );
            final semantics = tester.ensureSemantics();
            await tester.binding.setSurfaceSize(const Size(660, 600));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await pumpRow(
              tester,
              provider: scenario.provider,
              model: scenario.model,
              locale: locale,
              dark: dark,
            );
            final context = tester.element(find.byType(RequestSpeedRow));
            final l10n = AppLocalizations.of(context)!;
            final subtitle = switch (scenario.name) {
              'runs at' => l10n.requestSpeedRunsAt(
                scenario.model,
                l10n.requestSpeedFast,
              ),
              'unavailable' => l10n.requestSpeedUnavailable,
              _ => l10n.requestSpeedDescription,
            };
            expect(find.text(subtitle), findsOneWidget);
            expect(
              find.bySemanticsLabel(RegExp(l10n.requestSpeed)),
              findsWidgets,
            );
            expect(
              tester
                  .getSemantics(find.byKey(pickerKey))
                  .getSemanticsData()
                  .hint,
              subtitle,
            );
            await tester.tap(find.byKey(pickerKey));
            await tester.pumpAndSettle();
            final options = scenario.name == 'unavailable'
                ? findsNothing
                : findsOneWidget;
            expect(
              find.widgetWithText(
                PopupMenuItem<RequestSpeed>,
                l10n.requestSpeedFastOption,
              ),
              options,
            );
            expect(
              find.widgetWithText(
                PopupMenuItem<RequestSpeed>,
                l10n.requestSpeedUltrafastOption,
              ),
              options,
            );
            expect(tester.takeException(), isNull);
            semantics.dispose();
          },
        );
      }
    }
  }

  testWidgets('marks Standard as the default and lists prices', (
    tester,
  ) async {
    setupSettings();
    await pumpRow(tester);
    await tester.tap(find.byKey(pickerKey));
    await tester.pumpAndSettle();
    expect(find.text('Standard (default)'), findsNWidgets(2));
    expect(find.text('Fast · 2× price'), findsOneWidget);
    expect(find.text('Ultrafast · 6× price'), findsOneWidget);
  });

  testWidgets('saving a speed pushes it to native before persisting', (
    tester,
  ) async {
    setupSettings();
    await pumpRow(tester);
    const options = {
      RequestSpeed.fast: 'Fast · 2× price',
      RequestSpeed.ultrafast: 'Ultrafast · 6× price',
      RequestSpeed.standard: 'Standard (default)',
    };
    var previous = RequestSpeed.standard;
    for (final entry in options.entries) {
      await tester.tap(find.byKey(pickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value).last);
      await tester.pumpAndSettle();
      expect(methodCalls.last.method, MethodChannelMethods.setRequestSpeed);
      expect(methodCalls.last.arguments, entry.key.name);
      expect(savedAtNativeCall.last, previous.name);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('request_speed'), entry.key.name);
      previous = entry.key;
    }
  });

  testWidgets(
    'shows the downgraded level for a model without the chosen tier',
    (
      tester,
    ) async {
      setupSettings(model: 'gpt-6-luna', speed: RequestSpeed.ultrafast);
      final semantics = tester.ensureSemantics();
      await pumpRow(tester, model: 'gpt-6-luna');
      const subtitle = 'gpt-6-luna runs at Fast';
      expect(find.text(subtitle), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(pickerKey)).getSemanticsData().hint,
        subtitle,
      );
      semantics.dispose();
    },
  );

  testWidgets('custom Anthropic model at Ultrafast shows Fast', (tester) async {
    const model = 'custom-claude-model';
    setupSettings(
      provider: AppDefaults.anthropicProvider,
      model: model,
      speed: RequestSpeed.ultrafast,
    );
    final semantics = tester.ensureSemantics();
    await pumpRow(
      tester,
      provider: AppDefaults.anthropicProvider,
      model: model,
    );
    const subtitle = '$model runs at Fast';
    expect(find.text(subtitle), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(pickerKey)).getSemanticsData().hint,
      subtitle,
    );
    semantics.dispose();
  });

  testWidgets('updates the subtitle when the model changes', (tester) async {
    setupSettings(model: 'gpt-6-luna', speed: RequestSpeed.ultrafast);
    await pumpRow(tester, model: 'gpt-6-luna');
    expect(find.text('gpt-6-luna runs at Fast'), findsOneWidget);
    await pumpRow(tester);
    expect(find.text('gpt-6-luna runs at Fast'), findsNothing);
    expect(
      find.text('Faster tiers answer sooner and cost more.'),
      findsOneWidget,
    );
  });

  testWidgets('is disabled with an availability note for OpenRouter and custom '
      'providers', (tester) async {
    for (final provider in [AppDefaults.openRouterProvider, 'custom']) {
      setupSettings(provider: provider);
      await pumpRow(tester, provider: provider);
      expect(
        find.text('Available for OpenAI and Anthropic'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AppPopupSelect<RequestSpeed>>(find.byKey(pickerKey))
            .enabled,
        isFalse,
      );
      await tester.tap(find.byKey(pickerKey));
      await tester.pumpAndSettle();
      expect(find.text('Fast · 2× price'), findsNothing);
      expect(methodCalls, isEmpty);
    }
  });

  testWidgets('reports a native failure without saving', (tester) async {
    setupSettings();
    nativeFails = true;
    await pumpRow(tester);
    await tester.tap(find.byKey(pickerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fast · 2× price'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save speed. Try again.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('request_speed'), RequestSpeed.standard.name);
    final picker = tester.widget<AppPopupSelect<RequestSpeed>>(
      find.byKey(pickerKey),
    );
    expect(picker.value, RequestSpeed.standard);
    expect(picker.enabled, isTrue);
  });
}
