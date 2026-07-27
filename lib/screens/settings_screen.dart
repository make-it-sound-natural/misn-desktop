import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings/advanced_section.dart';
import 'package:make_it_sound_natural/screens/settings/api_provider_section.dart';
import 'package:make_it_sound_natural/screens/settings/appearance_section.dart';
import 'package:make_it_sound_natural/screens/settings/permissions_section.dart';
import 'package:make_it_sound_natural/screens/settings/preferences_section.dart';
import 'package:make_it_sound_natural/screens/settings/shortcuts_section.dart';
import 'package:make_it_sound_natural/screens/settings/target_profile_section.dart';
import 'package:make_it_sound_natural/screens/settings/updates_section.dart';
import 'package:make_it_sound_natural/services/update_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_window_header.dart';

enum _SettingsDestination {
  aiProvider,
  appearance,
  writing,
  language,
  shortcuts,
  permissions,
  updates,
  advanced,
}

/// Main settings screen that orchestrates all settings sections.
class SettingsScreen extends StatefulWidget {
  /// Creates the settings screen widget.
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsDestination _selectedDestination = _SettingsDestination.aiProvider;

  @override
  void initState() {
    super.initState();
    unawaited(UpdateService().preloadSettingsSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppWindowHeader(
            activeTab: AppHeaderTab.settings,
            onRewrite: _closeSettings,
            onSettings: () {},
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingsSidebar(
                  selected: _selectedDestination,
                  onSelected: (destination) {
                    setState(() => _selectedDestination = destination);
                  },
                ),
                Expanded(
                  child: _buildSettingsContent(_selectedDestination),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closeSettings() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _buildSettingsContent(_SettingsDestination destination) {
    return switch (destination) {
      _SettingsDestination.shortcuts => const _SettingsContentFrame(
        child: ShortcutsSettingsSection(),
      ),
      _SettingsDestination.writing => const _SettingsContentFrame(
        child: PreferencesSettingsSection(),
      ),
      _SettingsDestination.language => const _SettingsContentFrame(
        child: _LanguageSettingsContent(),
      ),
      _SettingsDestination.aiProvider => const _SettingsContentFrame(
        child: ApiProviderSection(),
      ),
      _SettingsDestination.appearance => const _SettingsContentFrame(
        child: AppearanceSettingsSection(),
      ),
      _SettingsDestination.permissions => const _SettingsContentFrame(
        child: PermissionsSettingsSection(),
      ),
      _SettingsDestination.updates => const _SettingsContentFrame(
        child: UpdatesSettingsSection(),
      ),
      _SettingsDestination.advanced => const _SettingsContentFrame(
        child: AdvancedSettingsSection(),
      ),
    };
  }
}

class _LanguageSettingsContent extends StatelessWidget {
  const _LanguageSettingsContent();

  @override
  Widget build(BuildContext context) {
    return AppSettingsSection(
      title: AppLocalizations.of(context)!.settingsNavLanguage,
      subtitle: AppLocalizations.of(context)!.languageSectionDescription,
      children: const [TargetProfileSettingsRow()],
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.selected,
    required this.onSelected,
  });

  final _SettingsDestination selected;
  final ValueChanged<_SettingsDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (
        destination: _SettingsDestination.aiProvider,
        label: l10n.apiProvider,
        icon: Icons.auto_awesome_rounded,
        key: 'aiProvider',
      ),
      (
        destination: _SettingsDestination.appearance,
        label: l10n.appearance,
        icon: Icons.palette_rounded,
        key: 'appearance',
      ),
      (
        destination: _SettingsDestination.writing,
        label: l10n.settingsNavWriting,
        icon: Icons.edit_rounded,
        key: 'writing',
      ),
      (
        destination: _SettingsDestination.language,
        label: l10n.settingsNavLanguage,
        icon: Icons.language_rounded,
        key: 'language',
      ),
      (
        destination: _SettingsDestination.shortcuts,
        label: l10n.settingsNavShortcuts,
        icon: Icons.keyboard_rounded,
        key: 'shortcuts',
      ),
      (
        destination: _SettingsDestination.permissions,
        label: l10n.permissions,
        icon: Icons.shield_outlined,
        key: 'permissions',
      ),
      (
        destination: _SettingsDestination.updates,
        label: l10n.updates,
        icon: Icons.update_rounded,
        key: 'updates',
      ),
      (
        destination: _SettingsDestination.advanced,
        label: l10n.advancedSettings,
        icon: Icons.tune_rounded,
        key: 'advanced',
      ),
    ];

    return Container(
      width: AppSizes.settingsSidebarWidth,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
        0,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              // Matches the nav rows' horizontal inset so the two most
              // prominent left edges of the screen share one column.
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text(
                l10n.settings,
                style: AppTextStyles.pageTitleOf(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final item in items) ...[
              _SettingsSidebarItem(
                key: Key('settingsNav-${item.key}'),
                label: item.label,
                icon: item.icon,
                selected: selected == item.destination,
                onTap: () => onSelected(item.destination),
              ),
              const SizedBox(height: AppSpacing.xxs),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSidebarItem extends StatelessWidget {
  const _SettingsSidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // `onPrimaryContainer` is the role for content sitting on a
    // `primaryContainer` fill; it resolves to the same tint but survives a
    // palette change that `primary` would not.
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: AppSizes.sidebarRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, size: AppSizes.iconLg, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsContentFrame extends StatelessWidget {
  const _SettingsContentFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Top and sides match the Rewrite tab's 24 so content does not shift
      // when you switch tabs; the deeper bottom inset is the mockup's.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.settingsMaxContentWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
