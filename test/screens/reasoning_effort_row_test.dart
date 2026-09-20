import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings/reasoning_effort_row.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
            home: const Scaffold(body: ReasoningEffortRow()),
          ),
        );
        await tester.pumpAndSettle();
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
    }
  }
}
