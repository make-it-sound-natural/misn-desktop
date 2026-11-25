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

      final watchdog = KeyboardInputWatchdog()..start();
      await body(tester, calls);
      watchdog.stop();
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

  Future<void> typeLetter(WidgetTester tester) =>
      tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');

  Iterable<MethodCall> stallReports(List<MethodCall> calls) => calls.where(
    (call) => call.method == MethodChannelMethods.reportTextInputStall,
  );

  testWatchdog('acknowledges a burst of key presses once', (
    tester,
    calls,
  ) async {
    for (var i = 0; i < 3; i++) {
      await typeLetter(tester);
    }
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
    await typeLetter(tester);
    await tester.pump(KeyboardInputWatchdog.acknowledgementDelay);
    await typeLetter(tester);
    await tester.pump(KeyboardInputWatchdog.acknowledgementDelay);

    expect(calls, hasLength(2));
  });

  testWatchdog('reports a focused field that ignores typing', (
    tester,
    calls,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpFocusedField(tester);

    for (var i = 0; i < 20; i++) {
      await typeLetter(tester);
    }

    expect(stallReports(calls), hasLength(1));
    expect(stallReports(calls).single.arguments, {
      'keyPresses': KeyboardInputWatchdog.stalledKeyPressLimit,
      'lifecycleState': 'resumed',
    });
  });

  testWatchdog('stays quiet while the typed text arrives', (
    tester,
    calls,
  ) async {
    final controller = await pumpFocusedField(tester);

    for (var i = 0; i < 20; i++) {
      await typeLetter(tester);
      controller.text += 'a';
    }

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('counts a stall again once typing has worked', (
    tester,
    calls,
  ) async {
    final controller = await pumpFocusedField(tester);

    for (var i = 0; i < 4; i++) {
      await typeLetter(tester);
    }
    controller.text = 'a';
    for (var i = 0; i < 4; i++) {
      await typeLetter(tester);
    }

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('ignores keys that do not type', (tester, calls) async {
    await pumpFocusedField(tester);

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter, character: '\r');
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    for (var i = 0; i < 20; i++) {
      await typeLetter(tester);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('ignores typing into a read-only field', (tester, calls) async {
    await pumpFocusedField(tester, readOnly: true);

    for (var i = 0; i < 20; i++) {
      await typeLetter(tester);
    }

    expect(stallReports(calls), isEmpty);
  });

  testWatchdog('ignores typing with no field focused', (tester, calls) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));

    for (var i = 0; i < 20; i++) {
      await typeLetter(tester);
    }

    expect(stallReports(calls), isEmpty);
  });
}
