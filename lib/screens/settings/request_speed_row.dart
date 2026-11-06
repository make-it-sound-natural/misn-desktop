import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/model_catalog.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/request_speed.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:make_it_sound_natural/widgets/app_settings_section.dart';
import 'package:make_it_sound_natural/widgets/app_toast.dart';

/// Global speed preference and the selected model's effective request tier.
class RequestSpeedRow extends StatefulWidget {
  /// Creates the speed preference row for the selected provider and model.
  const RequestSpeedRow({
    required this.provider,
    required this.model,
    required this.isBuiltIn,
    super.key,
  });

  /// Provider that will receive rewrite requests.
  final String provider;

  /// Selected model slug.
  final String model;

  /// Whether the selected model comes from the built-in catalog.
  final bool isBuiltIn;

  @override
  State<RequestSpeedRow> createState() => _RequestSpeedRowState();
}

class _RequestSpeedRowState extends State<RequestSpeedRow> {
  final _settings = SettingsService();
  RequestSpeed _speed = AppDefaults.requestSpeed;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final speed = await _settings.getRequestSpeed();
    if (!mounted) return;
    setState(() {
      _speed = speed;
      _busy = false;
    });
  }

  Future<void> _select(RequestSpeed speed) async {
    setState(() => _busy = true);
    try {
      await ShortcutService().setRequestSpeed(speed);
      await _settings.setRequestSpeed(speed);
      if (mounted) setState(() => _speed = speed);
    } on Exception catch (error, stackTrace) {
      developer.log(
        'Could not save request speed',
        name: 'RequestSpeedRow',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      showAppToast(
        context,
        AppLocalizations.of(context)!.requestSpeedSaveFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final available = ModelCatalog.offersSpeed(widget.provider);
    final effective = ModelCatalog.effectiveSpeed(
      provider: widget.provider,
      model: widget.model,
      requested: _speed,
      isBuiltIn: widget.isBuiltIn,
    );
    final levels = {
      RequestSpeed.standard: l10n.requestSpeedStandard,
      RequestSpeed.fast: l10n.requestSpeedFast,
      RequestSpeed.ultrafast: l10n.requestSpeedUltrafast,
    };
    final options = {
      RequestSpeed.standard: l10n.requestSpeedStandard,
      RequestSpeed.fast: l10n.requestSpeedFastOption,
      RequestSpeed.ultrafast: l10n.requestSpeedUltrafastOption,
    };
    final subtitle = !available
        ? l10n.requestSpeedUnavailable
        : effective != _speed
        ? l10n.requestSpeedRunsAt(widget.model, levels[effective]!)
        : l10n.requestSpeedDescription;

    return AppSettingsRow(
      leading: const AppSettingsRowIcon(icon: Icons.bolt_outlined),
      title: l10n.requestSpeed,
      titleWidget: Text(
        l10n.requestSpeed,
        style: AppTextStyles.rowTitleOf(context),
      ),
      subtitleWidget: Text(
        subtitle,
        style: AppTextStyles.rowSubtitleOf(context),
      ),
      trailing: SizedBox(
        width: AppSizes.settingsWideControlWidth,
        child: Semantics(
          label: l10n.requestSpeed,
          hint: subtitle,
          child: AppPopupSelect<RequestSpeed>(
            key: const Key('apiProvider-speedPicker'),
            value: _speed,
            enabled: !_busy && available,
            options: [
              for (final speed in RequestSpeed.values)
                AppPopupOption(value: speed, label: options[speed]!),
            ],
            onChanged: (speed) => unawaited(_select(speed)),
          ),
        ),
      ),
    );
  }
}
