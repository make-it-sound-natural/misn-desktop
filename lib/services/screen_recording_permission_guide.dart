import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';

/// The Screen Recording helper as Settings and onboarding show it.
extension ScreenRecordingPermissionGuide on ShortcutService {
  /// Opens Screen Recording in System Settings with the native helper.
  /// Returns true when permission is granted before the helper closes.
  Future<bool> showScreenRecordingPermissionGuide(AppLocalizations l10n) {
    return presentScreenRecordingPermissionGuide(
      title: l10n.screenRecordingPermissionGuideTitle,
      message: l10n.screenRecordingPermissionGuideMessage,
      dragInstruction: l10n.screenRecordingPermissionDragInstruction,
      openSettings: l10n.openSystemSettings,
      revealInFinder: l10n.revealInFinder,
      checkAgain: l10n.checkAgain,
      cancel: l10n.cancel,
      stillMissing: l10n.screenRecordingPermissionStillMissing,
      debugHint: l10n.screenRecordingPermissionDebugHint,
      manualAddRequired: false,
      openSettingsOnAppear: true,
    );
  }
}
