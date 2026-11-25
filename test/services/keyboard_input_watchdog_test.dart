import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/services/keyboard_input_watchdog.dart';

void main() {
  const channel = MethodChannel(MethodChannelMethods.channelName);

  /// Runs [body] with a started watchdog and the native calls it made.
  void testWatchdog(
    String description,
    Future<void> Function(WidgetTester tester, List<MethodCall> calls) body,
  ) {
    testWidgets(description, (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      // Stopped here and not in a tear-down: the test binding checks for
      // pending timers before tear-downs run.
      final watchdog = KeyboardInputWatchdog()..start();
      try {
        await body(tester, calls);
      } finally {
        watchdog.stop();
      }
    });
  }

  Future<TextEditingController> pumpFocusedField(
    WidgetTester tester, {
    bool readOnly = false,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            autofocus: true,
            readOnly: readOnly,
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  Future<void> typeLetters(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    }
  }

  Iterable<MethodCall> stallReports(List<MethodCall> calls) => calls.where(
    (call) => call.method == MethodChannelMethods.reportTextInputStall,
  );

  testWatchdog('acknowledges a burst of key presses once', (
    tester,
    calls,
  ) async {
    await typeLetters(tester, 3);
    expect(calls, isEmpty);

    await tester.pump(KeyboardInputWatchdog.acknowledgementDelay);

    expect(calls.map((call) => call.method), [
      MethodChannelMethods.acknowledgeKeyEvents,
    ]);
  });

  testWatchdog('acknowledges again after the next key press', (
    tester,
    calls,
  ) async {
    await typeLetters(tester, 1);
    await tester.pump(KeyboardInputWatchdog.acknowledgementDelay);
    await typeLetters(tester, 1);
    await tester.pump(KeyboardInputWatchdog.acknowledgementDelay);

    expect(calls, hasLength(2));
  });

  testWatchdog('reports a focused field that ignores typing', (
    tester,
    calls,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFocusedField(tester);

    await typeLetters(tester, 20);

    expect(stallReports(calls), hasLength(1));
    expect(stallReports(calls).single.arguments, {
      'keyPresses': KeyboardInputWatchdog.stalledKeyPressLimit,
      'lifecycleState': 'resumed',
    });
  });

  testWatchdog('reports again only after the report interval', (
    tester,
    calls,
  ) async {
    final controller = await pumpFocusedField(tester);
    await typeLetters(tester, 6);
    expect(stallReports(calls), hasLength(1));

    controller.text = 'a';
    await typeLetters(tester, 6);
    expect(stallReports(calls), hasLength(1));

    await tester.pump(KeyboardInputWatchdog.reportInterval);
    await typeLetters(tester, 1);
    expect(stallReports(calls), hasLength(2));
  });

  testWatchdog('stays quiet while the typed text arrives', (
    tester,
    calls,
  ) async {
    final controller = await pumpFocusedField(tester);

    for (var i = 0; i < 20; i++) {
      await typeLetters(tester, 1);
      controller.text += 'a';
    }

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('counts a stall again once typing has worked', (
    tester,
    calls,
  ) async {
    final controller = await pumpFocusedField(tester);

    await typeLetters(tester, 4);
    controller.text = 'a';
    await typeLetters(tester, 5);
    expect(stallReports(calls), isEmpty);

    await typeLetters(tester, 1);
    expect(stallReports(calls), hasLength(1));
  });

  testWatchdog('counts each field separately', (tester, calls) async {
    final secondField = FocusNode();
    addTearDown(secondField.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(autofocus: true),
              TextField(focusNode: secondField),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await typeLetters(tester, 5);
    secondField.requestFocus();
    await tester.pump();
    await typeLetters(tester, 5);
    expect(stallReports(calls), isEmpty);

    await typeLetters(tester, 1);
    expect(stallReports(calls), hasLength(1));
  });

  testWatchdog('ignores the repeats of a held key', (tester, calls) async {
    final controller = await pumpFocusedField(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: 'a');
    controller.text = 'a';
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyA, character: 'a');
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('ignores keys that do not type', (tester, calls) async {
    await pumpFocusedField(tester);

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter, character: '\r');
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await typeLetters(tester, 20);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('ignores typing into a read-only field', (tester, calls) async {
    await pumpFocusedField(tester, readOnly: true);

    await typeLetters(tester, 20);

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('ignores typing with no field focused', (tester, calls) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    await typeLetters(tester, 20);

    expect(stallReports(calls), isEmpty);
  });
}
