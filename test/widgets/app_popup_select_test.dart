import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';

void main() {
  Future<void> pumpSelect(
    WidgetTester tester, {
    required ValueChanged<String> onChanged,
    String? value = 'a',
    String? placeholder,
    bool enabled = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: AppPopupSelect<String>(
                value: value,
                placeholder: placeholder,
                enabled: enabled,
                options: const [
                  AppPopupHeader<String>('Group'),
                  AppPopupOption<String>(value: 'a', label: 'Alpha'),
                  AppPopupOption<String>(value: 'b', label: 'Beta'),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the selected option label', (tester) async {
    await pumpSelect(tester, onChanged: (_) {});
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('shows the placeholder when nothing matches', (tester) async {
    await pumpSelect(
      tester,
      value: null,
      placeholder: 'Pick one',
      onChanged: (_) {},
    );
    expect(find.text('Pick one'), findsOneWidget);
  });

  testWidgets('picking an option reports its value', (tester) async {
    final picked = <String>[];
    await pumpSelect(tester, onChanged: picked.add);

    await tester.tap(find.byType(AppPopupSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta').last);
    await tester.pumpAndSettle();

    expect(picked, ['b']);
  });

  testWidgets('the selected row carries a checkmark', (tester) async {
    await pumpSelect(tester, onChanged: (_) {});

    await tester.tap(find.byType(AppPopupSelect<String>));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('a group header is not selectable', (tester) async {
    // A selectable header would emit a null value into onChanged from the
    // provider-grouped model picker.
    final picked = <String>[];
    await pumpSelect(tester, onChanged: picked.add);

    await tester.tap(find.byType(AppPopupSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group').last);
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(find.text('Beta'), findsOneWidget, reason: 'menu stays open');
  });

  testWidgets('a disabled select does not open', (tester) async {
    final picked = <String>[];
    await pumpSelect(tester, enabled: false, onChanged: picked.add);

    await tester.tap(find.byType(AppPopupSelect<String>));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsNothing);
    expect(picked, isEmpty);
  });
}
