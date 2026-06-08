import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_metadata.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// Top-level app destinations shown in the shared window header.
enum AppHeaderTab {
  /// Rewrite workspace.
  rewrite,

  /// Settings workspace.
  settings,
}

/// Shared app header for Rewrite and Settings screens.
class AppWindowHeader extends StatelessWidget {
  /// Creates the shared app header.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final leftPadding =
            constraints.maxWidth >= AppSizes.headerWideBreakpoint
            ? AppSizes.headerWideLeadingInset
            : AppSizes.headerTrafficLightInset;
        final rightPadding =
            constraints.maxWidth >= AppSizes.headerTrailingBreakpoint
            ? AppSpacing.xxl
            : AppSpacing.lg;

        return Container(
          height: AppSizes.headerHeight,
          padding: EdgeInsets.fromLTRB(leftPadding, 0, rightPadding, 0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.asset(
                  'macos/Runner/Assets.xcassets/AppIcon.appiconset/'
                  'app_icon_128.png',
                  width: 32,
                  height: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppMetadata.title,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.appTitleOf(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppSegmentedTabs(
                activeTab: activeTab,
                onRewrite: onRewrite,
                onSettings: onSettings,
              ),
            ],
          ),
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: AppSizes.tabHeight,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentedTabButton(
            label: 'Rewrite',
            selected: activeTab == AppHeaderTab.rewrite,
            onPressed: activeTab == AppHeaderTab.rewrite ? null : onRewrite,
            side: _SegmentedTabSide.left,
          ),
          _SegmentedTabButton(
            label: l10n.settings,
            selected: activeTab == AppHeaderTab.settings,
            onPressed: activeTab == AppHeaderTab.settings ? null : onSettings,
            side: _SegmentedTabSide.right,
          ),
        ],
      ),
    );
  }
}

enum _SegmentedTabSide {
  left,
  right;

  BorderRadius get borderRadius {
    return switch (this) {
      _SegmentedTabSide.left => const BorderRadius.horizontal(
        left: Radius.circular(AppRadius.md),
      ),
      _SegmentedTabSide.right => const BorderRadius.horizontal(
        right: Radius.circular(AppRadius.md),
      ),
    };
  }
}

class _SegmentedTabButton extends StatelessWidget {
  const _SegmentedTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.side,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final _SegmentedTabSide side;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      final colorScheme = Theme.of(context).colorScheme;
      final selectedColor = Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF0EAFE)
          : colorScheme.primaryContainer;
      return Container(
        width: AppSizes.tabWidth,
        height: AppSizes.tabHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selectedColor,
          borderRadius: side.borderRadius,
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        fixedSize: const Size(AppSizes.tabWidth, AppSizes.tabHeight),
        foregroundColor: Theme.of(context).textTheme.bodyMedium?.color,
        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: side.borderRadius),
      ),
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
