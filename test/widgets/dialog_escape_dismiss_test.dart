import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/prompt_edit_dialog.dart';
import 'package:make_it_sound_natural/widgets/shortcut_change_dialog.dart';
import 'package:make_it_sound_natural/widgets/target_profile_editor_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MethodChannelMethods.channelName);
  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpDialog(
    WidgetTester tester,
    Widget dialog, {
    bool barrierDismissible = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(menuFontSize: AppDefaults.menuFontSize),
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                unawaited(
                  showDialog<Object?>(
                    context: context,
                    barrierDismissible: barrierDismissible,
                    builder: (context) => dialog,
                  ),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Escape closes prompt editor while text field is focused', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      const PromptEditDialog(
        currentPrompt: '',
        defaultPrompt: 'Default prompt',
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(PromptEditDialog), findsNothing);
  });

  testWidgets('Escape closes target profile editor', (tester) async {
    await pumpDialog(tester, const TargetProfileEditorDialog());
    await tester.tap(find.byKey(const Key('targetProfileNameField')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(TargetProfileEditorDialog), findsNothing);
  });

  testWidgets('Escape closes shortcut recorder instead of recording Escape', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      const ShortcutChangeDialog(currentShortcut: 'cmd+shift+k'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(ShortcutChangeDialog), findsNothing);
    expect(
      methodCalls.where(
        (call) => call.method == MethodChannelMethods.enableShortcuts,
      ),
      isNotEmpty,
    );
  });
}
