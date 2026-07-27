import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

/// Visual kinds for the floating toast.
enum AppToastKind {
  /// Inverted pill used for ordinary confirmations.
  neutral,

  /// Warning pill, for example when the target window changed.
  warning,

  /// Grey pill with a leading glyph, for example the not-editable notice.
  muted,

  /// Solid green pill confirming a saved setting.
  success,

  /// Solid error pill that stays up until dismissed.
  ///
  /// Provider errors (credits, token limits) carry text worth reading, so this
  /// kind gets a long timeout and its own close control.
  error,
}

/// How long an error toast stays up before dismissing itself.
const Duration _errorToastDuration = Duration(seconds: 120);

/// How long a save confirmation stays up.
const Duration _successToastDuration = Duration(seconds: 2);

/// How long every other toast stays up.
const Duration _defaultToastDuration = Duration(seconds: 4);

/// Shows a single-line floating toast.
///
/// Replaces any toast already on screen so rapid feedback does not queue up
/// behind a stale message.
void showAppToast(
  BuildContext context,
  String message, {
  AppToastKind kind = AppToastKind.neutral,
  IconData? icon,
}) {
  final theme = Theme.of(context);
  final statusColors = AppStatusColors.of(context);
  final isDark = theme.brightness == Brightness.dark;

  final (Color? background, Color foreground) = switch (kind) {
    AppToastKind.neutral => (
      null,
      theme.snackBarTheme.contentTextStyle?.color ?? AppColors.background,
    ),
    AppToastKind.warning => (statusColors.warning, statusColors.onStatus),
    AppToastKind.muted => (
      isDark ? AppColors.darkMutedToast : AppColors.mutedToast,
      AppColors.onMutedToast,
    ),
    AppToastKind.success => (statusColors.success, statusColors.onStatus),
    AppToastKind.error => (statusColors.error, statusColors.onStatus),
  };
  final isError = kind == AppToastKind.error;
  final duration = switch (kind) {
    AppToastKind.error => _errorToastDuration,
    AppToastKind.success => _successToastDuration,
    _ => _defaultToastDuration,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        duration: duration,
        showCloseIcon: isError,
        closeIconColor: foreground,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconLg, color: foreground),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
}
