import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_shell.dart';

const double _promptEditorHeight = 260;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogShell(
      title: l10n.promptEditorTitle,
      subtitle: l10n.promptHelperText,
      compact: false,
      // Escape cancels the edit; the caller blocks barrier taps with
      // showDialog(barrierDismissible: false).
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isDefault) ...[
            Text(
              l10n.usingDefault,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SizedBox(
            height: _promptEditorHeight,
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: AppearanceScope.maybePreferencesOf(
                  context,
                ).editorFontSize,
                height: 1.5,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(AppSpacing.sm),
                hintText: l10n.enterPromptHint,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _isDefault ? null : _resetToDefault,
          icon: const Icon(Icons.restore_rounded, size: AppSizes.iconLg),
          label: Text(l10n.resetToDefault),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _hasChanges ? _save : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
