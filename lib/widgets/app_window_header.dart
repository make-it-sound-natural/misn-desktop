import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

/// Top-level app destinations shown in the shared window header.
enum AppHeaderTab {
  /// Rewrite workspace.
  rewrite,

  /// Settings workspace.
  settings,
}

/// Shared window chrome for Rewrite and Settings.
///
/// Deliberately empty on the left: macOS shows the app name in the menu bar
/// and its icon in the Dock, so repeating either here is a web-app habit.
/// The band only has to clear the traffic lights and carry the view switcher.
class AppWindowHeader extends StatelessWidget {
  /// Creates the shared window header.
  const AppWindowHeader({
    required this.activeTab,
    required this.onRewrite,
    required this.onSettings,
    super.key,
  });

  /// Active segmented tab.
  final AppHeaderTab activeTab;

  /// Rewrite tab action.
  final VoidCallback onRewrite;

  /// Settings tab action.
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.headerHeight,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.headerTrafficLightInset,
        0,
        AppSpacing.sm,
        0,
      ),
      decoration: BoxDecoration(
        // Transparent so the window's vibrancy material shows through; the
        // hairline is what AppKit draws under a toolbar.
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          AppSegmentedTabs(
            activeTab: activeTab,
            onRewrite: onRewrite,
            onSettings: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Shared two-tab segmented control for top-level navigation.
class AppSegmentedTabs extends StatelessWidget {
  /// Creates the segmented top-level tabs.
  const AppSegmentedTabs({
    required this.activeTab,
    required this.onRewrite,
    required this.onSettings,
    super.key,
  });

  /// Active tab.
  final AppHeaderTab activeTab;

  /// Rewrite action.
  final VoidCallback onRewrite;

  /// Settings action.
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentedTabButton(
            label: l10n.rewriteTab,
            selected: activeTab == AppHeaderTab.rewrite,
            onPressed: activeTab == AppHeaderTab.rewrite ? null : onRewrite,
          ),
          const SizedBox(width: 2),
          _SegmentedTabButton(
            label: l10n.settings,
            selected: activeTab == AppHeaderTab.settings,
            onPressed: activeTab == AppHeaderTab.settings ? null : onSettings,
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabButton extends StatelessWidget {
  const _SegmentedTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        backgroundColor: selected
            ? theme.colorScheme.surface
            : Colors.transparent,
        overlayColor: theme.colorScheme.onSurface,
        minimumSize: const Size(
          AppSizes.tabWidth,
          AppSizes.segmentedTabHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label, overflow: TextOverflow.ellipsis),
    );

    if (!selected) return button;

    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        // In dark mode the active segment is *darker* than the strip it sits
        // on (1.1:1) and the shadow cannot render on near-black, so the raised
        // metaphor inverts. A hairline is what actually carries the state.
        border: isDark ? Border.all(color: theme.dividerColor) : null,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSegmentShadow
                : AppColors.segmentShadow,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: button,
    );
  }
}
