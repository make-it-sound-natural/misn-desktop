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

  testWidgets('uses traffic-light safe leading inset at compact widths', (
    tester,
  ) async {
    await pumpHeader(tester, width: 800);

    final iconLeft = tester.getTopLeft(find.byType(Image)).dx;

    expect(iconLeft, AppSizes.headerTrafficLightInset);
  });

  testWidgets('uses wide leading inset at wide widths', (tester) async {
    await pumpHeader(tester, width: 1_600);

    final iconLeft = tester.getTopLeft(find.byType(Image)).dx;

    expect(iconLeft, AppSizes.headerWideLeadingInset);
  });
}
