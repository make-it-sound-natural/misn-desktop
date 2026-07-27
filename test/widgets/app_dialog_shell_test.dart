import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester,
    Widget dialog, {
    bool barrierDismissible = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(menuFontSize: 14),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: barrierDismissible,
                builder: (_) => dialog,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders title, subtitle, content and actions', (tester) async {
    await pumpDialog(
      tester,
      AppDialogShell(
        title: 'API Key',
        subtitle: 'OpenRouter · stored locally in the macOS Keychain',
        content: const Text('body'),
        actions: [
          OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
          FilledButton(onPressed: () {}, child: const Text('Save')),
        ],
      ),
    );

    expect(find.text('API Key'), findsOneWidget);
    expect(
      find.text('OpenRouter · stored locally in the macOS Keychain'),
      findsOneWidget,
    );
    expect(find.text('body'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Escape closes a dismissible shell', (tester) async {
    await pumpDialog(
      tester,
      const AppDialogShell(title: 'T', content: Text('body')),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('body'), findsNothing);
  });

  testWidgets('Escape is ignored when the dialog opts out of dismissal', (
    tester,
  ) async {
    // A non-dismissible dialog must pair `dismissible: false` with
    // `barrierDismissible: false`, otherwise the modal route pops itself.
    await pumpDialog(
      tester,
      const AppDialogShell(
        title: 'T',
        content: Text('body'),
        dismissible: false,
      ),
      barrierDismissible: false,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('confirm dialog returns true only on the destructive action', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(menuFontSize: 14),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context: context,
                  title: 'Delete provider?',
                  message: const Text('tokenguard will be removed.'),
                  confirmLabel: 'Delete',
                  cancelLabel: 'Cancel',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
