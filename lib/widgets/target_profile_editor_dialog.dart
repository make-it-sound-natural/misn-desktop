import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/widgets/app_dialog_escape_dismiss.dart';

/// User-entered custom target profile values.
class TargetProfileDraft {
  /// Creates a custom target profile draft.
  const TargetProfileDraft({
    required this.name,
    required this.instruction,
  });

  /// Visible profile name.
  final String name;

  /// Prompt instruction sent to the LLM.
  final String instruction;
}

/// Dialog for creating a custom target profile.
class TargetProfileEditorDialog extends StatefulWidget {
  /// Creates a target profile editor dialog.
  const TargetProfileEditorDialog({this.initialProfile, super.key});

  /// Profile to edit. When null, the dialog creates a new profile.
  final TargetProfile? initialProfile;

  @override
  State<TargetProfileEditorDialog> createState() =>
      _TargetProfileEditorDialogState();
}

class _TargetProfileEditorDialogState extends State<TargetProfileEditorDialog> {
  final _nameController = TextEditingController();
  final _instructionController = TextEditingController();

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _instructionController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final initialProfile = widget.initialProfile;
    if (initialProfile != null) {
      _nameController.text = initialProfile.name;
      _instructionController.text = initialProfile.instruction;
    }
    _nameController.addListener(_onChanged);
    _instructionController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onChanged)
      ..dispose();
    _instructionController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _save() {
    Navigator.of(context).pop(
      TargetProfileDraft(
        name: _nameController.text.trim(),
        instruction: _instructionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.initialProfile == null
        ? l10n.addCustom
        : l10n.editPrompt;

    return AppDialogEscapeDismiss<TargetProfileDraft>(
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.dialogCompactMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      title,
                      style: AppTextStyles.pageTitleOf(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  key: const Key('targetProfileNameField'),
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.targetProfileName,
                    helperText: _nameController.text.trim().isEmpty
                        ? l10n.fieldRequired
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('targetProfileInstructionField'),
                  controller: _instructionController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.targetProfileInstruction,
                    helperText: _instructionController.text.trim().isEmpty
                        ? l10n.fieldRequired
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ElevatedButton(
                      onPressed: _canSave ? _save : null,
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
