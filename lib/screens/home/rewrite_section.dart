import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/screens/home/rewrite_shared.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// One labelled column of the Rewrite screen.
///
/// Owns the fixed-height eyebrow row so both columns start on the same line
/// whether or not the section carries a trailing control.
class RewriteSection extends StatelessWidget {
  /// Creates a labelled Rewrite column.
  const RewriteSection({
    required this.title,
    required this.child,
    super.key,
    this.trailing,
  });

  /// Uppercase eyebrow above the column.
  final String title;

  /// Column body.
  final Widget child;

  /// Optional control aligned to the end of the eyebrow row.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed height keeps both columns starting on the same line, whether
        // or not the section has a trailing control.
        SizedBox(
          height: eyebrowRowHeight,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.eyebrowOf(context),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        // The mockup's `.eyebrow-row` carries a 12px bottom margin; without
        // it the first card's border touches the auto-apply control above it.
        const SizedBox(height: AppSpacing.sm),
        Expanded(child: child),
      ],
    );
  }
}
