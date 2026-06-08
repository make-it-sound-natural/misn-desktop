import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';

/// Shared bordered panel used by desktop app surfaces.
class AppPanel extends StatelessWidget {
  /// Creates a standard app panel.
  const AppPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.xl,
  });

  /// Panel content.
  final Widget child;

  /// Inner padding.
  final EdgeInsets padding;

  /// Border radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}
