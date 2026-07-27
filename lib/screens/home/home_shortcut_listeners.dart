import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:make_it_sound_natural/constants/shortcut_status.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';

/// Owns the Home screen's subscriptions to [ShortcutService].
///
/// Extracted from `_HomeScreenState` so the wiring reads in one place and the
/// state class stays closer to the size guideline. Every stream is cancelled
/// together, which is what the screen actually needs — six separate nullable
/// subscription fields made it easy to add a seventh and forget the cancel.
class HomeShortcutListeners {
  /// Creates the listener set. Nothing subscribes until [start].
  HomeShortcutListeners({
    required this.onVariants,
    required this.onStatus,
    required this.onNotEditable,
    required this.onOpenSettings,
    required this.onTextCaptured,
    required this.onError,
  });

  /// Raw marked-up variant content from a shortcut-driven run.
  final ValueChanged<String> onVariants;

  /// Status transitions reported by the native side.
  final ValueChanged<ShortcutStatus> onStatus;

  /// The shortcut fired somewhere text cannot be replaced.
  final VoidCallback onNotEditable;

  /// The native side asked for the Settings screen.
  final VoidCallback onOpenSettings;

  /// Text captured by the shortcut, to prefill the source field.
  final ValueChanged<String> onTextCaptured;

  /// Provider or transport error worth surfacing.
  final ValueChanged<String> onError;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Subscribes to every stream. Calling twice would double-deliver, so it
  /// asserts rather than silently stacking subscriptions.
  void start() {
    assert(_subscriptions.isEmpty, 'listeners already started');
    final service = ShortcutService();
    _subscriptions.addAll([
      service.variantsGeneratedStream.listen(onVariants),
      service.statusStream.listen(onStatus),
      service.notEditableStream.listen((_) => onNotEditable()),
      service.openSettingsStream.listen((_) => onOpenSettings()),
      service.textCapturedStream.listen(onTextCaptured),
      service.errorStream.listen(onError),
    ]);
  }

  /// Cancels every subscription.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
