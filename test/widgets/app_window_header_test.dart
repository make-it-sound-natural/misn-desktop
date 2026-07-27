import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_window_header.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required double width,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, AppSizes.headerHeight));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: AppSizes.headerHeight,
            child: AppWindowHeader(
              activeTab: AppHeaderTab.rewrite,
              onRewrite: () {},
              onSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('carries only the view switcher, no app name or icon', (
    tester,
  ) async {
    await pumpHeader(tester, width: 1_200);

    expect(find.byType(AppSegmentedTabs), findsOneWidget);
    // macOS shows the app name in the menu bar and the icon in the Dock;
    // repeating either inside the window is what made the band feel heavy.
    expect(find.byType(Image), findsNothing);
    expect(find.text('Make It Sound Natural'), findsNothing);
  });

  testWidgets('reserves a fixed traffic-light inset at every width', (
    tester,
  ) async {
    for (final width in [800.0, 1_600.0]) {
      await pumpHeader(tester, width: width);

      final tabsLeft = tester.getTopLeft(find.byType(AppSegmentedTabs)).dx;
      expect(
        tabsLeft,
        greaterThan(AppSizes.headerTrafficLightInset),
        reason: 'tabs must never overlap the traffic lights',
      );
    }
  });

  testWidgets('is transparent so the window material shows through', (
    tester,
  ) async {
    await pumpHeader(tester, width: 1_200);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AppWindowHeader),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect(decoration.border, isNotNull);
  });
}
