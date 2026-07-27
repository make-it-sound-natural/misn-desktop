import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/l10n/correction_variant_localizations.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/screens/home/rewrite_section.dart';
import 'package:make_it_sound_natural/screens/home/rewrite_shared.dart';
import 'package:make_it_sound_natural/screens/home_flow_state.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:make_it_sound_natural/utils/shortcut_formatter.dart';
import 'package:make_it_sound_natural/widgets/app_inline_banner.dart';
import 'package:make_it_sound_natural/widgets/app_kbd_chip.dart';
import 'package:make_it_sound_natural/widgets/app_popup_select.dart';
import 'package:make_it_sound_natural/widgets/app_skeleton.dart';
import 'package:make_it_sound_natural/widgets/variant_card.dart';

/// Right Rewrite column: results, placeholders, or the reason there are none.
///
/// Renders whichever face of [HomeFlowState] is current, so the phase switch
/// lives next to the widgets it selects between.
class VariantsPanel extends StatelessWidget {
  /// Creates the variants column.
  const VariantsPanel({
    required this.flow,
    required this.autoApplyVariant,
    required this.shortcut,
    required this.justAppliedIndex,
    required this.onSelect,
    required this.onCopy,
    required this.onAutoApplyChanged,
    required this.onOpenSettings,
    required this.onRetry,
    super.key,
  });

  /// Current phase, variants, and selection.
  final HomeFlowState flow;

  /// Tone applied automatically to future runs.
  final String autoApplyVariant;

  /// Correction shortcut, taught by the empty state this column starts as.
  final String shortcut;

  /// Index of the card currently playing the confirmation ring.
  final int? justAppliedIndex;

  /// Applies the variant at the given index.
  final ValueChanged<int> onSelect;

  /// Copies a variant without applying it.
  final ValueChanged<String> onCopy;

  /// Persists a new auto-apply tone.
  final ValueChanged<String> onAutoApplyChanged;

  /// Opens Settings at the provider section.
  final VoidCallback onOpenSettings;

  /// Reruns the last submitted text after an auth failure.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RewriteSection(
      title: AppLocalizations.of(context)!.variantsEyebrow,
      trailing: _AutoApplySelector(
        variant: autoApplyVariant,
        onChanged: onAutoApplyChanged,
      ),
      // The column owns the window height now, so it scrolls its own content
      // rather than scrolling the whole page under the eyebrow row.
      child: SingleChildScrollView(
        child: switch (flow.phase) {
          HomeFlowPhase.processing => const _ProcessingSkeletons(),
          HomeFlowPhase.error => _AuthFailureBanner(
            providerName: flow.errorProviderName ?? '',
            onCheckApiKey: onOpenSettings,
            onRetry: onRetry,
          ),
          HomeFlowPhase.variants => _VariantsList(
            variants: flow.variants,
            selectedIndex: flow.selectedIndex,
            selectionApplied: flow.selectionApplied,
            justAppliedIndex: justAppliedIndex,
            onSelect: onSelect,
            onCopy: onCopy,
          ),
          HomeFlowPhase.empty => _EmptyState(shortcut: shortcut),
        },
      ),
    );
  }
}

/// Four placeholder cards plus the cancel hint, shown while a run is in
/// flight.
class _ProcessingSkeletons extends StatelessWidget {
  const _ProcessingSkeletons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: l10n.generatingVariants,
          child: const SizedBox.shrink(),
        ),
        for (var i = 0; i < skeletonCardCount; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          const AppSkeletonCard(),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const AppKbdChip('Esc'),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.escCancelHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// Explains an API-key rejection and offers the two ways forward.
class _AuthFailureBanner extends StatelessWidget {
  const _AuthFailureBanner({
    required this.providerName,
    required this.onCheckApiKey,
    required this.onRetry,
  });

  final String providerName;
  final VoidCallback onCheckApiKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final statusColors = AppStatusColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInlineBanner(
          icon: Icons.error_outline_rounded,
          kind: AppInlineBannerKind.error,
          title: l10n.authFailureBannerTitle,
          message: l10n.authFailureBannerBody(providerName),
          actions: [
            TextButton(
              onPressed: onCheckApiKey,
              style: TextButton.styleFrom(
                foregroundColor: statusColors.error,
              ),
              child: Text(l10n.checkApiKey),
            ),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Text(
            l10n.variantsEmptyStateError,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks the tone applied automatically to future runs.
class _AutoApplySelector extends StatelessWidget {
  const _AutoApplySelector({required this.variant, required this.onChanged});

  final String variant;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.autoApplyVariant, style: AppTextStyles.controlOf(context)),
        const SizedBox(width: AppSpacing.xs),
        AppPopupSelect<String>(
          key: const Key('rewrite-auto-apply'),
          value: variant,
          shrinkWrap: true,
          options: [
            for (final kind in CorrectionVariantKind.values)
              AppPopupOption<String>(
                value: kind.wireValue,
                label: l10n.correctionVariantLabel(kind),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Primer shown before the first run.
///
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.shortcut});

  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = AppTextStyles.rowSubtitleOf(context);

    // The rewrite gesture is taught here, in the column it fills, while the
    // column is empty — not in the source footer, where it crowded the two
    // hints that belong to the fields. Full sentence, so the key reads as an
    // action and not as another bare verb.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xxsPlus,
            runSpacing: AppSpacing.xxs,
            children: [
              Text(l10n.emptyPrimerLead, style: muted),
              AppKbdChip(ShortcutFormatter.formatShortcutDisplay(shortcut)),
              Text(l10n.emptyPrimerRewriteTail, style: muted),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.emptyPrimerSubtitle,
            textAlign: TextAlign.center,
            style: muted,
          ),
        ],
      ),
    );
  }
}

/// Vertical list of variant cards. The panel grows with its content.
class _VariantsList extends StatelessWidget {
  const _VariantsList({
    required this.variants,
    required this.selectedIndex,
    required this.selectionApplied,
    required this.justAppliedIndex,
    required this.onSelect,
    required this.onCopy,
  });

  final List<CorrectionVariant> variants;
  final int? selectedIndex;
  final bool selectionApplied;
  final int? justAppliedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editorFontSize = AppearanceScope.maybePreferencesOf(
      context,
    ).editorFontSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < variants.length; index++) ...[
          if (index > 0) const SizedBox(height: AppSpacing.sm),
          VariantCard(
            glyph: _iconForVariantKind(variants[index].kind),
            name: l10n.correctionVariantDisplayLabel(variants[index]),
            text: variants[index].text,
            isApplied: selectionApplied && selectedIndex == index,
            isDefault: !selectionApplied && selectedIndex == index,
            justApplied: justAppliedIndex == index,
            appliedLabel: l10n.applied,
            defaultLabel: l10n.variantDefaultTag,
            applyLabel: l10n.apply,
            copyTooltip: l10n.copy,
            textFontSize: editorFontSize,
            onApply: () => onSelect(index),
            onCopy: () => onCopy(variants[index].text),
          ),
        ],
      ],
    );
  }
}

IconData _iconForVariantKind(CorrectionVariantKind? kind) {
  switch (kind) {
    case CorrectionVariantKind.balanced:
      return Icons.tune_rounded;
    case CorrectionVariantKind.casual:
      return Icons.chat_bubble_outline_rounded;
    case CorrectionVariantKind.formal:
      return Icons.business_center_outlined;
    case CorrectionVariantKind.concise:
      return Icons.short_text_rounded;
    case null:
      return Icons.auto_awesome_rounded;
  }
}
