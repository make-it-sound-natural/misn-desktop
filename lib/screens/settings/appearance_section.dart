import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

/// Settings section for app appearance preferences.
class AppearanceSettingsSection extends StatelessWidget {
  /// Creates the appearance settings section.
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = AppearanceScope.controllerOf(context);
    final preferences = controller.preferences;

    return AppSettingsSection(
      title: l10n.appearance,
      children: [
        AppSettingsRow(
          leading: const AppSettingsIconTile(icon: Icons.palette_rounded),
          title: l10n.appearanceTheme,
          subtitle: l10n.appearanceThemeHelper,
          trailing: SegmentedButton<AppearanceThemeMode>(
            key: const Key('appearanceThemeSelector'),
            segments: [
              ButtonSegment(
                value: AppearanceThemeMode.system,
                label: Text(
                  l10n.appearanceThemeSystem,
                  key: const Key('appearanceTheme-system'),
                ),
              ),
              ButtonSegment(
                value: AppearanceThemeMode.light,
                label: Text(
                  l10n.appearanceThemeLight,
                  key: const Key('appearanceTheme-light'),
                ),
              ),
              ButtonSegment(
                value: AppearanceThemeMode.dark,
                label: Text(
                  l10n.appearanceThemeDark,
                  key: const Key('appearanceTheme-dark'),
                ),
              ),
            ],
            selected: {preferences.themeMode},
            onSelectionChanged: (selection) {
              unawaited(controller.setThemeMode(selection.single));
            },
          ),
        ),
        const AppSettingsDivider(),
        _FontSizeRow(
          key: const Key('appearance-menuFontSizeRow'),
          fieldKey: const Key('appearance-menuFontSize'),
          title: l10n.appearanceMenuFontSize,
          subtitle: l10n.appearanceMenuFontSizeHelper,
          value: preferences.menuFontSize,
          min: AppDefaults.menuFontSizeMin,
          max: AppDefaults.menuFontSizeMax,
          onChanged: (value) {
            unawaited(controller.setMenuFontSize(value));
          },
        ),
        const AppSettingsDivider(),
        _FontSizeRow(
          key: const Key('appearance-editorFontSizeRow'),
          fieldKey: const Key('appearance-editorFontSize'),
          title: l10n.appearanceEditorFontSize,
          subtitle: l10n.appearanceEditorFontSizeHelper,
          value: preferences.editorFontSize,
          min: AppDefaults.editorFontSizeMin,
          max: AppDefaults.editorFontSizeMax,
          onChanged: (value) {
            unawaited(controller.setEditorFontSize(value));
          },
        ),
        const AppSettingsDivider(),
        AppSettingsRow(
          leading: const AppSettingsIconTile(icon: Icons.restart_alt_rounded),
          title: l10n.appearanceReset,
          trailing: FilledButton(
            key: const Key('appearance-reset'),
            onPressed: () async {
              await controller.reset();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.appearanceResetDone)),
              );
            },
            child: Text(l10n.appearanceReset),
          ),
        ),
      ],
    );
  }
}

class _FontSizeRow extends StatefulWidget {
  const _FontSizeRow({
    required this.fieldKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
  });

  final Key fieldKey;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  State<_FontSizeRow> createState() => _FontSizeRowState();
}

class _FontSizeRowState extends State<_FontSizeRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_FontSizeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.value.toStringAsFixed(0);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSettingsRow(
      leading: const AppSettingsIconTile(icon: Icons.format_size_rounded),
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 76,
            child: TextField(
              key: widget.fieldKey,
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: _submit,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(l10n.pixelsUnit),
        ],
      ),
    );
  }

  void _submit(String rawValue) {
    final parsed = double.tryParse(rawValue) ?? widget.value;
    if (parsed < widget.min) {
      widget.onChanged(widget.min);
      return;
    }
    if (parsed > widget.max) {
      widget.onChanged(widget.max);
      return;
    }
    widget.onChanged(parsed);
  }
}
