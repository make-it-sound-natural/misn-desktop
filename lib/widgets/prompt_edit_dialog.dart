import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_escape_dismiss.dart';

/// Dialog for editing the AI prompt.
/// Returns the new prompt string if saved, or null if cancelled.
/// Returns empty string if reset to default.
class PromptEditDialog extends StatefulWidget {
  /// Creates a dialog for editing the AI prompt.
  ///
  /// [currentPrompt] is the currently saved custom prompt (empty if using
  /// default). [defaultPrompt] is the default prompt from the native side.
  const PromptEditDialog({
    required this.currentPrompt,
    required this.defaultPrompt,
    super.key,
  });

  /// The current custom prompt (empty string means using default)
  final String currentPrompt;

  /// The default prompt fetched from native side (single source of truth)
  final String defaultPrompt;

  @override
  State<PromptEditDialog> createState() => _PromptEditDialogState();
}

class _PromptEditDialogState extends State<PromptEditDialog> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    // If current prompt is empty, show the default prompt
    final initialText = widget.currentPrompt.isEmpty
        ? widget.defaultPrompt
        : widget.currentPrompt;
    _controller = TextEditingController(text: initialText);
    _isDefault = widget.currentPrompt.isEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final currentText = _controller.text;
    final originalText = widget.currentPrompt.isEmpty
        ? widget.defaultPrompt
        : widget.currentPrompt;
    setState(() {
      _hasChanges = currentText != originalText;
      _isDefault = currentText == widget.defaultPrompt;
    });
  }

  void _resetToDefault() {
    _controller.text = widget.defaultPrompt;
  }

  void _save() {
    final text = _controller.text.trim();
    // If the text equals default, save empty string to indicate "use default"
    if (text == widget.defaultPrompt) {
      Navigator.of(context).pop('');
    } else {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColors = AppStatusColors.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogEscapeDismiss<String>(
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.dialogMaxWidth,
            maxHeight: 600,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.accentGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: const Icon(Icons.auto_fix_high_rounded, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.promptEditorTitle,
                      style: AppTextStyles.pageTitleOf(context),
                    ),
                    const Spacer(),
                    if (_isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColors.successContainer,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          l10n.usingDefault,
                          style: TextStyle(
                            color: statusColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Helper text
                Text(
                  l10n.promptHelperText,
                  style: AppTextStyles.rowSubtitleOf(context),
                ),
                const SizedBox(height: AppSpacing.md),

                // Text editor
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: theme.dividerColor,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(16),
                        border: InputBorder.none,
                        hintText: l10n.enterPromptHint,
                        hintStyle: TextStyle(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Actions
                Row(
                  children: [
                    // Reset button
                    TextButton.icon(
                      onPressed: _isDefault ? null : _resetToDefault,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(l10n.resetToDefault),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const Spacer(),
                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Save button
                    ElevatedButton(
                      onPressed: _hasChanges ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
