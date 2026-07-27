import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/widgets/app_skeleton.dart';

void main() {
  /// The shimmer is the only AnimatedBuilder inside the card; MaterialApp and
  /// Scaffold contribute their own elsewhere in the tree.
  Finder shimmerBars() => find.descendant(
    of: find.byType(AppSkeletonCard),
    matching: find.byType(AnimatedBuilder),
  );

  Future<void> pumpSkeleton(
    WidgetTester tester, {
    required bool disableAnimations,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: const Scaffold(body: AppSkeletonCard()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shimmers by default', (tester) async {
    await pumpSkeleton(tester, disableAnimations: false);

    expect(shimmerBars(), findsWidgets);
    // Leave the repeating controller settled so the test can finish.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stops shimmering when the system asks for reduced motion', (
    tester,
  ) async {
    await pumpSkeleton(tester, disableAnimations: true);

    expect(shimmerBars(), findsNothing);
  });

  testWidgets('reacts to reduced motion turning on after first build', (
    tester,
  ) async {
    await pumpSkeleton(tester, disableAnimations: false);
    expect(shimmerBars(), findsWidgets);

    await pumpSkeleton(tester, disableAnimations: true);
    expect(shimmerBars(), findsNothing);
  });
}
