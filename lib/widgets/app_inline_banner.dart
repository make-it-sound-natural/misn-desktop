import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

/// Border opacity for a banner's status-coloured outline.
const double _borderAlpha = 0.3;

/// Which status a banner carries.
enum AppInlineBannerKind {
  /// Something needs attention before the feature works.
  warning,

  /// Something failed.
  error,
}

/// Status strip shown inline above content.
///
/// One component so the two banners on the Rewrite screen stop drifting: they
/// were built separately and ended up with two radii, two border treatments
/// and two glyph sizes for what reads as the same pattern.
///
/// Pass [title] for the tall variant, which stacks a heading over the message
/// and puts [actions] on their own right-aligned row. Without it the banner is
/// a single compact row with the actions inline.
class AppInlineBanner extends StatelessWidget {
  /// Creates an inline status banner.
  const AppInlineBanner({
    required this.icon,
    required this.message,
    required this.kind,
    super.key,
    this.title,
    this.actions = const [],
  });

  /// Leading status glyph.
  final IconData icon;

  /// Body copy.
  final String message;

  /// Status this banner carries.
  final AppInlineBannerKind kind;

  /// Optional heading; its presence selects the tall layout.
  final String? title;

  /// Trailing controls.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors = AppStatusColors.of(context);
    final (Color tint, Color fill) = switch (kind) {
      AppInlineBannerKind.warning => (
        statusColors.warning,
        statusColors.warningContainer,
      ),
      AppInlineBannerKind.error => (
        statusColors.error,
        statusColors.errorContainer,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: tint.withValues(alpha: _borderAlpha)),
      ),
      child: title == null
          ? _buildCompact(theme, tint)
          : _buildDetailed(theme, tint),
    );
  }

  Widget _buildCompact(ThemeData theme, Color tint) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: tint),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  Widget _buildDetailed(ThemeData theme, Color tint) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smPlus,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppSizes.iconMd, color: tint),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            // Wrap, not Row: the banner lives in one column of a two-column
            // layout, which gets narrow enough for two buttons to overflow.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
