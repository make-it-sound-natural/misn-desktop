import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// Opt-in switch that also reads nearby window text as App context.
class OnboardingNearbyTextOption extends StatelessWidget {
  /// Creates the nearby text switch row.
  const OnboardingNearbyTextOption({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Switch title.
  final String title;

  /// Privacy note shown under the title.
  final String description;

  /// Whether nearby text is selected.
  final bool value;

  /// Called when the user flips the switch.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // One semantics node, so a screen reader announces the label with the
    // switch state instead of reading the texts and the switch separately.
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.rowTitleOf(context)),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  description,
                  style: AppTextStyles.rowSubtitleOf(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            key: const Key('onboarding-nearby-text-switch'),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
