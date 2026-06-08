import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Adds a consistent Escape-to-cancel behavior to app dialogs.
class AppDialogEscapeDismiss<T> extends StatelessWidget {
  /// Creates an Escape dismissal wrapper.
  const AppDialogEscapeDismiss({
    required this.child,
    this.enabled = true,
    this.result,
    this.onDismiss,
    super.key,
  });

  /// Wrapped dialog widget.
  final Widget child;

  /// Whether Escape should dismiss the dialog.
  final bool enabled;

  /// Optional result passed to Navigator.pop when Escape dismisses the dialog.
  final T? result;

  /// Optional custom dismiss callback.
  final VoidCallback? onDismiss;

  bool _dismiss(BuildContext context) {
    if (!enabled) return false;
    final dismiss = onDismiss;
    if (dismiss != null) {
      dismiss();
      return true;
    }
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return false;
    navigator.pop<T>(result);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _dismiss(context);
              return null;
            },
          ),
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent ||
                event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            return _dismiss(context)
                ? KeyEventResult.handled
                : KeyEventResult.ignored;
          },
          child: child,
        ),
      ),
    );
  }
}
