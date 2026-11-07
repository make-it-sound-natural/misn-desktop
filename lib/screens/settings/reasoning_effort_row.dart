import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_catalog.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/reasoning_effort.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';

/// Shared reasoning preference and the selected model's effective level.
class ReasoningEffortRow extends StatefulWidget {
  /// Creates the reasoning preference row for the selected provider and model.
  const ReasoningEffortRow({
    required this.provider,
    required this.model,
    super.key,
  });

  /// Provider that will receive rewrite requests.
  final String provider;

  /// Selected model slug.
  final String model;

  @override
  State<ReasoningEffortRow> createState() => _ReasoningEffortRowState();
}

class _ReasoningEffortRowState extends State<ReasoningEffortRow> {
  final _settings = SettingsService();
  ReasoningEffort _effort = AppDefaults.reasoningEffort;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final effort = await _settings.getReasoningEffort();
    if (!mounted) return;
    setState(() {
      _effort = effort;
      _busy = false;
    });
  }

  Future<void> _select(ReasoningEffort effort) async {
    setState(() => _busy = true);
    try {
      await ShortcutService().setReasoningEffort(
        effort,
        provider: widget.provider,
        model: widget.model,
      );
      await _settings.setReasoningEffort(effort);
      if (mounted) setState(() => _effort = effort);
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Could not save reasoning effort',
        name: 'ReasoningEffortRow',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      showAppToast(context, AppLocalizations.of(context)!.reasoningSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effective = ModelCatalog.effectiveReasoning(
      provider: widget.provider,
      model: widget.model,
      requested: _effort,
    );
    final subtitle = effective != _effort
        ? l10n.reasoningRunsAtLow(widget.model)
        : l10n.reasoningDescription;
    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.psychology_outlined),
      title: l10n.reasoningEffort,
      titleWidget: Text(
        l10n.reasoningEffort,
        style: AppTextStyles.rowTitleOf(context),
      ),
      subtitleWidget: Text(
        subtitle,
        style: AppTextStyles.rowSubtitleOf(context),
      ),
      trailing: SizedBox(
        width: AppSizes.settingsWideControlWidth,
        child: Tooltip(
          message: l10n.reasoningFallback,
          child: Semantics(
            label: l10n.reasoningEffort,
            hint: l10n.reasoningFallback,
            child: AppPopupSelect<ReasoningEffort>(
              key: const Key('apiProvider-reasoningPicker'),
              value: _effort,
              enabled: !_busy,
              options: [
                for (final effort in ReasoningEffort.values)
                  AppPopupOption(
                    value: effort,
                    label: _optionLabel(l10n, effort),
                  ),
              ],
              onChanged: (effort) => unawaited(_select(effort)),
            ),
          ),
        ),
      ),
    );
  }
}

String _optionLabel(AppLocalizations l10n, ReasoningEffort effort) =>
    switch (effort) {
      ReasoningEffort.none => l10n.reasoningNone,
      ReasoningEffort.low => l10n.reasoningLow,
      ReasoningEffort.medium => l10n.reasoningMedium,
      ReasoningEffort.high => l10n.reasoningHigh,
    };
