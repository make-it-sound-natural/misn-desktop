import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

/// Backward-compatible alias for the shared compact settings row.
@Deprecated('Use AppSettingsRow instead.')
class SettingsRow extends AppSettingsRow {
  /// Creates a settings row widget.
  @Deprecated('Use AppSettingsRow instead.')
  const SettingsRow({
    required super.leading,
    required super.title,
    super.key,
    super.subtitle,
    super.trailing,
  });
}
