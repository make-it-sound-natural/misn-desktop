import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

const double _unityCardSelectedShadowAlpha = 0.08;
const double _unityCardIdleShadowAlpha = 0.03;
const double _unityCardSelectedShadowBlur = 10;
const double _unityCardIdleShadowBlur = 6;
const double _unityCardSelectedBorderWidth = 2;
const double _unityCardSubtleAlpha = 0.7;

/// Compact rewrite variant card with a selected gradient border.
class UnityCard extends StatelessWidget {
  /// Creates a Unity-style card widget.
  ///
  /// [child] is the content to display inside the card.
  /// [isSelected] determines whether the card displays the selected state with
  /// a gradient border.
  /// [onTap] is an optional callback invoked when the card is tapped.
  /// [padding] controls the internal spacing around the child content.
  const UnityCard({
    required this.child,
    super.key,
    this.isSelected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  /// The widget to display inside the card.
  final Widget child;

  /// Whether the card is in the selected state, showing a gradient border.
  final bool isSelected;

  /// Optional callback invoked when the card is tapped.
  final VoidCallback? onTap;

  /// The padding around the child content.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          gradient: isSelected ? AppColors.accentGradient : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isSelected
                    ? _unityCardSelectedShadowAlpha
                    : _unityCardIdleShadowAlpha,
              ),
              blurRadius: isSelected
                  ? _unityCardSelectedShadowBlur
                  : _unityCardIdleShadowBlur,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Container(
          margin: EdgeInsets.all(
            isSelected ? _unityCardSelectedBorderWidth : 0,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.surface
                : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(
              isSelected ? AppRadius.sm : AppRadius.md,
            ),
            border: isSelected
                ? null
                : Border.all(
                    color: dividerColor.withValues(
                      alpha: _unityCardSubtleAlpha,
                    ),
                  ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              isSelected ? AppRadius.sm : AppRadius.md,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
