import 'dart:async';

import 'package:flutter/material.dart';
import 'package:make_it_sound_natural/theme/app_design_tokens.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';

const double _skeletonTitleWidthFactor = 0.34;
const double _skeletonFirstLineWidthFactor = 0.92;
const double _skeletonSecondLineWidthFactor = 0.64;
const double _skeletonTitleHeight = 14;
const double _skeletonLineHeight = 13;
const double _skeletonShimmerAlpha = 0.65;

/// Loading placeholder shaped like a variant card.
///
/// The shimmer is skipped when the system asks for reduced motion.
class AppSkeletonCard extends StatefulWidget {
  /// Creates a skeleton card.
  const AppSkeletonCard({super.key});

  @override
  State<AppSkeletonCard> createState() => _AppSkeletonCardState();
}

class _AppSkeletonCardState extends State<AppSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.brightness == Brightness.dark
        ? AppColors.darkSkeleton
        : AppColors.skeleton;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smPlus,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBar(
            widthFactor: _skeletonTitleWidthFactor,
            height: _skeletonTitleHeight,
            fill: fill,
            shimmer: _reduceMotion ? null : _controller,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SkeletonBar(
            widthFactor: _skeletonFirstLineWidthFactor,
            height: _skeletonLineHeight,
            fill: fill,
            shimmer: _reduceMotion ? null : _controller,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SkeletonBar(
            widthFactor: _skeletonSecondLineWidthFactor,
            height: _skeletonLineHeight,
            fill: fill,
            shimmer: _reduceMotion ? null : _controller,
          ),
        ],
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.widthFactor,
    required this.height,
    required this.fill,
    required this.shimmer,
  });

  final double widthFactor;
  final double height;
  final Color fill;
  final Animation<double>? shimmer;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.sm);
    final shimmerAnimation = shimmer;

    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: shimmerAnimation == null
          ? Container(
              height: height,
              decoration: BoxDecoration(color: fill, borderRadius: radius),
            )
          : AnimatedBuilder(
              animation: shimmerAnimation,
              builder: (context, _) {
                final shift = 2 * shimmerAnimation.value;
                return Container(
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      begin: Alignment(-1 + shift, 0),
                      end: Alignment(1 + shift, 0),
                      colors: [
                        fill,
                        Theme.of(context).colorScheme.surface.withValues(
                          alpha: _skeletonShimmerAlpha,
                        ),
                        fill,
                      ],
                      stops: const [0.35, 0.5, 0.65],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
