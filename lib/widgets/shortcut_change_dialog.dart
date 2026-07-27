import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/utils/logger.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';

const double _recorderVerticalPadding = 26;
const double _recorderGlowAlpha = 0.2;
const double _feedbackRowHeight = 16;

/// States for the keyboard shortcut recording process.
enum ShortcutRecordingState {
  /// No recording is in progress.
  idle,

  /// Keys are currently being pressed and recorded.
  recording,

  /// A valid shortcut combination has been recorded.
  valid,

  /// The recorded shortcut is invalid (e.g., missing modifier keys).
  invalid,

  /// The shortcut is being validated for system conflicts.
  validating,

  /// The recorded shortcut conflicts with an existing system shortcut.
  conflict,

  /// The shortcut is being saved to the system.
  saving,
}

/// A dialog for recording and changing keyboard shortcuts.
///
/// Allows users to record a new keyboard shortcut by pressing key
/// combinations. Validates the shortcut structure and checks for conflicts
/// with system shortcuts before saving.
class ShortcutChangeDialog extends StatefulWidget {
  /// Creates a dialog for changing a keyboard shortcut.
  ///
  /// [currentShortcut] is the currently assigned shortcut string that will be
  /// displayed to the user.
  const ShortcutChangeDialog({
    required this.currentShortcut,
    super.key,
  });

  /// The currently assigned shortcut string.
  final String currentShortcut;

  @override
  State<ShortcutChangeDialog> createState() => _ShortcutChangeDialogState();
}

class _ShortcutChangeDialogState extends State<ShortcutChangeDialog> {
  final Logger _log = getLogger('ShortcutChangeDialog');
  ShortcutRecordingState _state = ShortcutRecordingState.idle;
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  String _recordedShortcut = '';
  String? _conflictName;
  final FocusNode _focusNode = FocusNode();
  final ShortcutService _shortcutService = ShortcutService();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    unawaited(_disableSystemShortcuts());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    unawaited(_enableSystemShortcuts());
    super.dispose();
  }

  Future<void> _disableSystemShortcuts() async {
    await _shortcutService.disableShortcuts();
  }

  Future<void> _enableSystemShortcuts() async {
    await _shortcutService.enableShortcuts();
  }

  void _transitionTo(ShortcutRecordingState newState) {
    _log.info('Transitioning from $_state to $newState');
    setState(() => _state = newState);
    unawaited(_onStateEnter(newState));
  }

  Future<void> _onStateEnter(ShortcutRecordingState state) async {
    switch (state) {
      case ShortcutRecordingState.validating:
        _log.info('Starting validation for $_recordedShortcut');
        await _validateWithSystem();
      case ShortcutRecordingState.saving:
        _log.info('Saving shortcut $_recordedShortcut');
        // Return the new shortcut to the caller
        if (mounted) {
          Navigator.of(context).pop(_recordedShortcut);
        }
      case ShortcutRecordingState.idle:
      case ShortcutRecordingState.recording:
      case ShortcutRecordingState.valid:
      case ShortcutRecordingState.invalid:
      case ShortcutRecordingState.conflict:
        break;
    }
  }

  Future<void> _validateWithSystem() async {
    _log.info('Calling validateShortcut with $_recordedShortcut');
    final result = await _shortcutService.validateShortcut(_recordedShortcut);
    _log.info('Validation result: $result');
    if (!mounted) return;

    if (result['isValid'] == true) {
      _transitionTo(ShortcutRecordingState.saving);
    } else {
      setState(() {
        _conflictName = result['conflictName'] as String?;
      });
      _transitionTo(ShortcutRecordingState.conflict);
    }
  }

  void _cancel() => Navigator.of(context).pop();

  void _handleKeyEvent(KeyEvent event) {
    if (_state == ShortcutRecordingState.validating ||
        _state == ShortcutRecordingState.saving) {
      return;
    }

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancel();
        return;
      }

      _log.info('KeyDown ${event.logicalKey}');
      setState(() {
        _pressedKeys.add(event.logicalKey);
      });
      _transitionTo(ShortcutRecordingState.recording);

      // Update recorded shortcut string from current keys only on KeyDown
      // This captures the "peak" complexity of the shortcut
      if (_pressedKeys.isNotEmpty) {
        final newShortcut = ShortcutFormatter.shortcutToString(_pressedKeys);
        _log.info('Keys pressed: $_pressedKeys, Recorded: $newShortcut');
        setState(() {
          _recordedShortcut = newShortcut;
        });
      }
    } else if (event is KeyUpEvent) {
      _log.info('KeyUp ${event.logicalKey}');
      setState(() {
        _pressedKeys.remove(event.logicalKey);
      });

      if (_pressedKeys.isEmpty && _state == ShortcutRecordingState.recording) {
        // User released all keys.
        if (ShortcutFormatter.validateShortcutStructure(_recordedShortcut)) {
          _log.info('Valid combination detected: $_recordedShortcut');
          _transitionTo(ShortcutRecordingState.valid);
        } else {
          _log.info('Invalid combination detected: $_recordedShortcut');
          _transitionTo(ShortcutRecordingState.invalid);
        }
      }
    }
  }

  void _clear() {
    setState(() {
      _pressedKeys.clear();
      _recordedShortcut = '';
      _conflictName = null;
    });
    _transitionTo(ShortcutRecordingState.idle);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogShell(
      title: l10n.changeShortcutTitle,
      // Escape cancels recording rather than being captured as the new
      // shortcut; the caller blocks barrier taps instead.
      content: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${l10n.currentShortcut}: ',
                    style: AppTextStyles.groupTitleOf(context),
                  ),
                  TextSpan(
                    text: ShortcutFormatter.formatShortcutDisplay(
                      widget.currentShortcut,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.newShortcut,
              style: AppTextStyles.groupTitleOf(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Focus(
              focusNode: _focusNode,
              onKeyEvent: (node, event) {
                _handleKeyEvent(event);
                return KeyEventResult.handled;
              },
              child: GestureDetector(
                onTap: _focusNode.requestFocus,
                child: AnimatedContainer(
                  duration: MediaQuery.of(context).disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: _recorderVerticalPadding,
                  ),
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: _getBorderColor(), width: 2),
                    boxShadow: _state == ShortcutRecordingState.recording
                        ? [
                            BoxShadow(
                              color: colorScheme.primary.withValues(
                                alpha: _recorderGlowAlpha,
                              ),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _recordedShortcut.isEmpty
                        ? l10n.pressKeyCombination
                        : ShortcutFormatter.formatShortcutDisplay(
                            _recordedShortcut,
                          ),
                    style: _recordedShortcut.isEmpty
                        ? theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          )
                        : theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildFeedbackMessage(l10n),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _clear, child: Text(l10n.clear)),
        OutlinedButton(onPressed: _cancel, child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _state == ShortcutRecordingState.valid
              ? () => _transitionTo(ShortcutRecordingState.validating)
              : null,
          child:
              _state == ShortcutRecordingState.validating ||
                  _state == ShortcutRecordingState.saving
              ? SizedBox(
                  width: AppSizes.iconLg,
                  height: AppSizes.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }

  Color _getBorderColor() {
    final statusColors = AppStatusColors.of(context);
    switch (_state) {
      case ShortcutRecordingState.recording:
        return Theme.of(context).colorScheme.primary;
      case ShortcutRecordingState.valid:
      case ShortcutRecordingState.saving:
      case ShortcutRecordingState.validating:
        return Theme.of(context).colorScheme.primary;
      case ShortcutRecordingState.invalid:
      case ShortcutRecordingState.conflict:
        return statusColors.error;
      case ShortcutRecordingState.idle:
        return Theme.of(context).dividerColor;
    }
  }

  Widget _buildFeedbackMessage(AppLocalizations l10n) {
    final statusColors = AppStatusColors.of(context);
    switch (_state) {
      case ShortcutRecordingState.invalid:
        return Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: statusColors.error,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.shortcutMustIncludeModifier,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: statusColors.error),
            ),
          ],
        );
      case ShortcutRecordingState.conflict:
        return Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: statusColors.error,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.shortcutConflictsWith(_conflictName ?? 'System'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: statusColors.error),
              ),
            ),
          ],
        );
      case ShortcutRecordingState.validating:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.validatingShortcut,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      case ShortcutRecordingState.valid:
        return const SizedBox(
          height: _feedbackRowHeight,
        ); // Or a success message
      case ShortcutRecordingState.idle:
      case ShortcutRecordingState.recording:
      case ShortcutRecordingState.saving:
        return const SizedBox(height: _feedbackRowHeight); // Placeholder
    }
  }
}
