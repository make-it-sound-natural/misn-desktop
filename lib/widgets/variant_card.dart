import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

const Duration _appliedRingDuration = Duration(milliseconds: 350);
const double _appliedRingAlpha = 0.3;
const double _appliedRingSpread = 4;
const double _variantCheckSize = 13;
const double _variantCopySize = 15;

/// One rewrite variant.
///
/// Two distinct states, deliberately not merged: [isDefault] marks the tone
/// that was merely pre-selected from preferences, and [isApplied] marks the
/// one the user actually pasted back. Only the applied one earns the accent,
/// because only it is true. The card chrome stays tappable so the pre-selected
/// tone is never the one you cannot apply — but the rewritten text itself is
/// not a tap target, so selecting it cannot paste into another application.
class VariantCard extends StatelessWidget {
  /// Creates a variant card.
  const VariantCard({
    required this.glyph,
    required this.name,
    required this.text,
    required this.isApplied,
    required this.isDefault,
    required this.appliedLabel,
    required this.defaultLabel,
    required this.applyLabel,
    required this.copyTooltip,
    required this.onApply,
    required this.onCopy,
    required this.textFontSize,
    super.key,
    this.justApplied = false,
  });

  /// Tone glyph.
  final IconData glyph;

  /// Tone display name.
  final String name;

  /// Rewritten text.
  final String text;

  /// Whether the user applied this variant.
  final bool isApplied;

  /// Whether this variant is pre-selected from preferences but not applied.
  final bool isDefault;

  /// Localized "Applied" label.
  final String appliedLabel;

  /// Localized "Default" tag for the pre-selected tone.
  final String defaultLabel;

  /// Localized "Apply" label.
  final String applyLabel;

  /// Localized copy tooltip.
  final String copyTooltip;

  /// Applies this variant.
  final VoidCallback onApply;

  /// Copies the text without changing the applied variant.
  final VoidCallback onCopy;

  /// Editor font size for the variant text.
  final double textFontSize;

  /// Plays the one-shot confirmation ring.
  final bool justApplied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // `Ink`, not `Container`: an opaque child fill paints over the InkWell's
    // splash, so the card advertised itself as tappable and then gave no
    // hover or press feedback at all.
    final card = Ink(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smPlus,
      ),
      decoration: BoxDecoration(
        color: isApplied ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                glyph,
                size: AppSizes.iconLg,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xsPlus),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.rowTitleOf(context),
                ),
              ),
              if (isApplied)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxsPlus,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: _variantCheckSize,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xxsPlus),
                      Text(
                        appliedLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (isDefault)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xxs),
                    child: Text(
                      defaultLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                // Accent, not muted: this is the primary verb of the whole
                // product. The accent rules allow two roles per screen — the
                // primary action and the applied state — and this is the
                // first of them. The mockup sets `.apply-btn` to the accent
                // too; forcing it grey left the screen with no focal point.
                TextButton(onPressed: onApply, child: Text(applyLabel)),
              ],
              IconButton(
                onPressed: onCopy,
                tooltip: copyTooltip,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.copy_rounded,
                  size: _variantCopySize,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // No onTap here. Placing a cursor or starting a selection used to
          // fire the apply path, which rewrites the clipboard and synthesises
          // Cmd+V into whichever application the text came from — an
          // irreversible cross-app side effect from an accidental click.
          SelectableText(
            text,
            style: TextStyle(fontSize: textFontSize, height: 1.5),
          ),
        ],
      ),
    );

    final tappable = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onApply,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: card,
      ),
    );

    // The wrapper type stays the same whether or not the ring is playing.
    // Swapping between `InkWell` and `TweenAnimationBuilder` here remounted
    // the whole subtree twice per apply, which rebuilt the `SelectableText`
    // and silently dropped any selection the user had made inside the card.
    final ringStart = justApplied && !reduceMotion ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      key: ValueKey('variant-ring-$name'),
      tween: Tween<double>(begin: ringStart, end: 0),
      duration: _appliedRingDuration,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            // An empty list paints nothing, so the idle case stays free.
            boxShadow: value == 0
                ? const <BoxShadow>[]
                : [
                    BoxShadow(
                      color: colorScheme.primary.withValues(
                        alpha: _appliedRingAlpha * value,
                      ),
                      spreadRadius: _appliedRingSpread,
                    ),
                  ],
          ),
          child: child,
        );
      },
      child: tappable,
    );
  }
}
