import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
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
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(title, style: AppTextStyles.sectionTitleOf(context)),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              right: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              subtitle!,
              style: AppTextStyles.rowSubtitleOf(context),
            ),
          ),
        AppPanel(
          padding: EdgeInsets.zero,
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
    this.trailing,
    this.onTap,
    this.minHeight = AppSizes.settingsRowHeight,
  });

  /// Leading icon or tile.
  final Widget leading;

  /// Row title.
  final String title;

  /// Optional row subtitle.
  final String? subtitle;

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
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.rowTitleOf(context),
                  ),
                  if (subtitle != null) ...[
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
      indent: AppSpacing.lg + AppSizes.iconTileSmall + AppSpacing.sm,
      endIndent: AppSpacing.lg,
      color: Theme.of(context).dividerColor,
    );
  }
}

/// Shared icon tile for settings rows.
class AppSettingsIconTile extends StatelessWidget {
  /// Creates an icon tile.
  const AppSettingsIconTile({
    required this.icon,
    super.key,
    this.backgroundColor = const Color(0xFFF0EAFE),
    this.iconColor = AppColors.primary,
  });

  /// Icon.
  final IconData icon;

  /// Tile background color.
  final Color backgroundColor;

  /// Icon color.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final defaultBackground = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF0EAFE)
        : colorScheme.primaryContainer;
    return Container(
      width: AppSizes.iconTileSmall,
      height: AppSizes.iconTileSmall,
      decoration: BoxDecoration(
        color: backgroundColor == const Color(0xFFF0EAFE)
            ? defaultBackground
            : backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        color: iconColor == AppColors.primary ? colorScheme.primary : iconColor,
        size: 22,
      ),
    );
  }
}
