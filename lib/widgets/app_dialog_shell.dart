import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_escape_dismiss.dart';

/// Shared chrome for every app dialog.
///
/// Title, optional subtitle, scrollable content, and a right-aligned action
/// row inside a surface card. Escape closes the dialog unless [dismissible]
/// is false, which mirrors the dialogs that require an explicit choice.
///
/// [dismissible] only governs this widget's own Escape handler. A dialog
/// that must not be dismissed has to be shown with
/// `showDialog(barrierDismissible: false)` as well, otherwise the modal
/// route keeps popping itself on Escape and on a barrier tap.
class AppDialogShell extends StatelessWidget {
  /// Creates the shared dialog shell.
  const AppDialogShell({
    required this.title,
    required this.content,
    super.key,
    this.subtitle,
    this.actions = const [],
    this.compact = true,
    this.dismissible = true,
  });

  /// Dialog title.
  final String title;

  /// Optional muted line under the title.
  final String? subtitle;

  /// Dialog body.
  final Widget content;

  /// Right-aligned actions, ordered least to most prominent.
  final List<Widget> actions;

  /// Uses the compact width when true, the default width otherwise.
  final bool compact;

  /// Whether Escape dismisses the dialog.
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = compact
        ? AppSizes.dialogCompactMaxWidth
        : AppSizes.dialogMaxWidth;

    return AppDialogEscapeDismiss<void>(
      enabled: dismissible,
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Flexible(child: SingleChildScrollView(child: content)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.xs),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a destructive confirmation on the shared shell.
///
/// Returns true only when the destructive action is chosen.
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required Widget message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final statusColors = AppStatusColors.of(dialogContext);
      return AppDialogShell(
        title: title,
        content: DefaultTextStyle(
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.55,
          ),
          child: message,
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: statusColors.error,
              side: BorderSide(
                color: statusColors.error.withValues(alpha: 0.4),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
