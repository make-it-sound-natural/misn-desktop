import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// Small keyboard-hint chip, for example `⌘⇧J`.
///
/// Deliberately uses the UI font: SF Mono draws ⌘⇧⌃⌥ below cap height, so
/// shortcut combos look broken in a monospace face. Native menus render
/// their key equivalents in the system font for the same reason.
class AppKbdChip extends StatelessWidget {
  /// Creates a keyboard chip.
  const AppKbdChip(this.label, {super.key});

  /// Shortcut text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSize = theme.textTheme.bodySmall?.fontSize ?? 12;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxsPlus,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border(
          top: BorderSide(color: theme.dividerColor),
          left: BorderSide(color: theme.dividerColor),
          right: BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor, width: 2),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: baseSize - 1,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
