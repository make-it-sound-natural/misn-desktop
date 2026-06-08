import 'package:make_it_sound_natural/widgets/app_settings_section.dart';

/// Backward-compatible alias for the shared compact settings section.
@Deprecated('Use AppSettingsSection instead.')
class SettingsSection extends AppSettingsSection {
  /// Creates a settings section widget.
  @Deprecated('Use AppSettingsSection instead.')
  const SettingsSection({
    required super.title,
    required super.children,
    super.key,
  });
}
