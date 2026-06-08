import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings/advanced_section.dart';
import 'package:make_it_sound_natural/screens/settings/api_provider_section.dart';
import 'package:make_it_sound_natural/screens/settings/appearance_section.dart';
import 'package:make_it_sound_natural/screens/settings/preferences_section.dart';
import 'package:make_it_sound_natural/screens/settings/shortcuts_section.dart';
import 'package:make_it_sound_natural/screens/settings/target_profile_section.dart';
import 'package:make_it_sound_natural/screens/settings/updates_section.dart';
import 'package:make_it_sound_natural/services/update_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_window_header.dart';

const double _wideSidebarWidth = 316;
const double _mediumSidebarWidth = 284;

enum _SettingsDestination {
  aiProvider,
  appearance,
  writing,
  language,
  shortcuts,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          AppWindowHeader(
            activeTab: AppHeaderTab.settings,
            onRewrite: _closeSettings,
            onSettings: () {},
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidebarWidth = constraints.maxWidth >= 1500
                    ? _wideSidebarWidth
                    : constraints.maxWidth >= 980
                    ? _mediumSidebarWidth
                    : 260.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsSidebar(
                      width: sidebarWidth,
                      selected: _selectedDestination,
                      onSelected: (destination) {
                        setState(
                          () => _selectedDestination = destination,
                        );
                      },
                    ),
                    Expanded(
                      child: _buildSettingsContent(_selectedDestination),
                    ),
                  ],
                );
              },
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
      children: const [TargetProfileSettingsRow()],
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({
    required this.width,
    required this.selected,
    required this.onSelected,
  });

  final double width;
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
      width: width,
      padding: EdgeInsets.fromLTRB(
        width >= 316 ? AppSpacing.lg : AppSpacing.md,
        AppSpacing.xxl,
        AppSpacing.lg,
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
            Text(
              l10n.settings,
              style: AppTextStyles.pageTitleOf(context),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final item in items) ...[
              _SettingsSidebarItem(
                key: Key('settingsNav-${item.key}'),
                label: item.label,
                icon: item.icon,
                selected: selected == item.destination,
                onTap: () => onSelected(item.destination),
              ),
              const SizedBox(height: AppSpacing.xs),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final selectedColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF0EAFE)
        : colorScheme.primaryContainer;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: AppSizes.compactRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 4,
                height: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                icon,
                size: 22,
                color: selected ? colorScheme.primary : textColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colorScheme.primary : textColor,
                    fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
                    fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: child,
    );
  }
}
