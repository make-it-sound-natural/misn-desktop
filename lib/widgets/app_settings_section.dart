import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_panel.dart';

/// Shared compact settings section container.
class AppSettingsSection extends StatelessWidget {
  /// Creates a settings section.
  const AppSettingsSection({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
  });

  /// Section title.
  final String title;

  /// Optional section helper text.
  final String? subtitle;

  /// Rows shown inside the section.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xxs,
            bottom: AppSpacing.xs,
          ),
          child: Text(title, style: AppTextStyles.settingsHeaderOf(context)),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              right: AppSpacing.xs,
              bottom: AppSpacing.md,
            ),
            child: Text(
              subtitle!,
              style: AppTextStyles.rowSubtitleOf(context),
            ),
          ),
        AppPanel(
          // Matches the group panels on the AI Provider tab: three
          // stacked panels used to sit at three different insets.
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxsPlus),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Shared compact settings row.
class AppSettingsRow extends StatelessWidget {
  /// Creates a settings row.
  const AppSettingsRow({
    required this.leading,
    required this.title,
    super.key,
    this.subtitle,
    this.titleWidget,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.minHeight = AppSizes.settingsRowHeight,
  });

  /// Leading row glyph.
  final Widget leading;

  /// Row title.
  final String title;

  /// Optional row subtitle.
  final String? subtitle;

  /// Rich title, used when the row mixes fonts (for example a model slug).
  /// Wins over [title], which stays required for semantics.
  final Widget? titleWidget;

  /// Rich subtitle, used when parts of the line carry their own style.
  /// Wins over [subtitle].
  final Widget? subtitleWidget;

  /// Optional trailing control.
  final Widget? trailing;

  /// Optional row tap action.
  final VoidCallback? onTap;

  /// Minimum row height.
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget ??
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.rowTitleOf(context),
                      ),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    subtitleWidget!,
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.rowSubtitleOf(context),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: content,
    );
  }
}

/// Shared settings row divider aligned after the leading icon.
class AppSettingsDivider extends StatelessWidget {
  /// Creates a settings row divider.
  const AppSettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: Theme.of(context).dividerColor,
    );
  }
}

/// Single-tone glyph for a settings row.
///
/// Replaces the former pastel icon tile: the redesign reserves filled
/// containers for the primary action and the active state.
class AppSettingsRowIcon extends StatelessWidget {
  /// Creates a settings row icon.
  const AppSettingsRowIcon({required this.icon, super.key, this.color});

  /// Glyph.
  final IconData icon;

  /// Overrides the muted default, used for truthful status glyphs.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.rowIconSize,
      child: Icon(
        icon,
        size: AppSizes.rowIconSize,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
