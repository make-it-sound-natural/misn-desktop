import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings/reasoning_effort_row.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    required String provider,
    required String model,
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
          body: ReasoningEffortRow(provider: provider, model: model),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in AppLocalizations.supportedLocales) {
    for (final dark in [false, true]) {
      testWidgets('reasoning row fits $locale, dark=$dark, large text', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final semantics = tester.ensureSemantics();
        // Available settings width at the app's minimum window size.
        await tester.binding.setSurfaceSize(const Size(660, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpRow(
          tester,
          provider: AppDefaults.openAiProvider,
          model: 'gpt-6-luna',
          locale: locale,
          dark: dark,
        );
        final context = tester.element(find.byType(ReasoningEffortRow));
        final l10n = AppLocalizations.of(context)!;
        expect(find.text(l10n.reasoningDescription), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(l10n.reasoningEffort)),
          findsWidgets,
        );
        final control = find.byKey(const Key('apiProvider-reasoningPicker'));
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(find.text(l10n.reasoningNone), findsOneWidget);
        expect(find.text(l10n.reasoningHigh), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('reasoning runs-at-low note fits $locale, dark=$dark', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'reasoning_effort': 'none'});
        final semantics = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(660, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpRow(
          tester,
          provider: AppDefaults.openAiProvider,
          model: 'gpt-6.1-sol',
          locale: locale,
          dark: dark,
        );
        final context = tester.element(find.byType(ReasoningEffortRow));
        final l10n = AppLocalizations.of(context)!;
        expect(
          find.text(l10n.reasoningRunsAtLow('gpt-6.1-sol')),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.byKey(const Key('apiProvider-reasoningPicker')),
              )
              .getSemanticsData()
              .hint,
          l10n.reasoningFallback,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }

  testWidgets('shows Low for a model without None', (tester) async {
    for (final (provider, model) in [
      (AppDefaults.openAiProvider, 'gpt-6-astra'),
      (AppDefaults.anthropicProvider, 'custom-claude-model'),
    ]) {
      SharedPreferences.setMockInitialValues({'reasoning_effort': 'none'});
      await pumpRow(tester, provider: provider, model: model);
      expect(find.text('$model runs at Low'), findsOneWidget);
    }
  });

  testWidgets('shows the description where None is supported', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reasoning_effort': 'none'});
    await pumpRow(
      tester,
      provider: AppDefaults.openAiProvider,
      model: 'gpt-6-luna',
    );
    expect(
      find.text(
        'Lower levels favor speed; higher levels allow deeper reasoning.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('runs at'), findsNothing);
  });
}
