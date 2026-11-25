import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/utils/logger.dart';

/// Tells native where key presses stop when typing has no effect.
///
/// A focused field that ignores the keyboard looks the same whether the
/// presses never reached Flutter or reached it and produced no text. This
/// reports both ends, and native writes the verdict to the unified log (see
/// `KeyboardInputDiagnostics.swift`).
///
/// Only counts leave this class, never the keys themselves: the fields it
/// watches include API keys.
class KeyboardInputWatchdog {
  /// Creates a watchdog reporting over [channel].
  KeyboardInputWatchdog({
    MethodChannel channel = const MethodChannel(
      MethodChannelMethods.channelName,
    ),
  }) : _channel = channel;

  /// Delay before an acknowledgement, so a burst of typing sends one.
  ///
  /// Native waits several seconds before it calls presses lost, so this has
  /// to stay well under that.
  static const Duration acknowledgementDelay = Duration(milliseconds: 500);

  /// Printable presses in a row that must change nothing before a report.
  ///
  /// One or two can be legitimate, such as a key the field's formatter
  /// rejects; a handful in a row is someone typing into a dead field.
  static const int stalledKeyPressLimit = 5;

  final MethodChannel _channel;
  final Logger _log = getLogger('KeyboardInputWatchdog');

  Timer? _acknowledgementTimer;
  WeakReference<EditableTextState>? _watchedField;
  TextEditingValue? _valueAtLastKeyPress;
  int _stalledKeyPresses = 0;

  /// Starts watching key presses.
  void start() => HardwareKeyboard.instance.addHandler(_handleKeyEvent);

  /// Stops watching and drops a pending acknowledgement.
  void stop() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _acknowledgementTimer?.cancel();
    _acknowledgementTimer = null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyUpEvent) {
      _acknowledgementTimer ??= Timer(acknowledgementDelay, _acknowledge);
      if (_isPrintable(event)) _checkFocusedField();
    }
    // Observing only: the event still goes to whoever handles it.
    return false;
  }

  void _acknowledge() {
    _acknowledgementTimer = null;
    unawaited(_invoke(MethodChannelMethods.acknowledgeKeyEvents));
  }

  bool _isPrintable(KeyEvent event) {
    final character = event.character;
    if (character == null || character.isEmpty) return false;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isMetaPressed || keyboard.isControlPressed) return false;

    final codePoint = character.runes.first;
    final isControl = codePoint < 0x20 || codePoint == 0x7f;
    // macOS reports arrows and function keys as private-use characters.
    final isPrivateUse = codePoint >= 0xe000 && codePoint <= 0xf8ff;
    return !isControl && !isPrivateUse;
  }

  /// Compares the focused field with how the previous key press left it.
  ///
  /// Text arrives after the key event that caused it, so the effect of a
  /// press is only visible by the time the next one comes.
  void _checkFocusedField() {
    final field = _focusedEditableField();
    final value = field?.textEditingValue;
    final unchanged =
        field != null &&
        identical(field, _watchedField?.target) &&
        value == _valueAtLastKeyPress;

    _watchedField = field == null ? null : WeakReference(field);
    _valueAtLastKeyPress = value;
    _stalledKeyPresses = unchanged ? _stalledKeyPresses + 1 : 0;

    if (_stalledKeyPresses == stalledKeyPressLimit) _reportStall();
  }

  EditableTextState? _focusedEditableField() {
    final field = FocusManager.instance.primaryFocus?.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (field == null || field.widget.readOnly) return null;
    return field;
  }

  void _reportStall() {
    unawaited(
      _invoke(MethodChannelMethods.reportTextInputStall, {
        'keyPresses': stalledKeyPressLimit,
        'lifecycleState':
            WidgetsBinding.instance.lifecycleState?.name ?? 'unknown',
      }),
    );
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      _log.warning('Keyboard diagnostics call $method failed: ${e.message}');
    } on MissingPluginException catch (e) {
      _log.warning('Keyboard diagnostics channel unavailable: $e');
    }
  }
}
