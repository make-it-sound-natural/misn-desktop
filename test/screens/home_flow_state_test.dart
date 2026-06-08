import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/screens/home_flow_state.dart';

void main() {
  CorrectionVariant variant(String label) {
    return CorrectionVariant(
      label: label,
      icon: '*',
      text: '$label text',
    );
  }

  group('HomeFlowState', () {
    test('starts empty', () {
      const state = HomeFlowState.empty();

      expect(state.phase, HomeFlowPhase.empty);
      expect(state.variants, isEmpty);
      expect(state.selectedIndex, isNull);
      expect(state.isProcessing, isFalse);
      expect(state.hasVariants, isFalse);
    });

    test('processing preserves variants and selection', () {
      final variants = [variant('Balanced'), variant('Formal')];
      final state = const HomeFlowState.empty()
          .withVariants(variants, selectedIndex: 1)
          .startProcessing();

      expect(state.phase, HomeFlowPhase.processing);
      expect(state.variants, variants);
      expect(state.selectedIndex, 1);
      expect(state.isProcessing, isTrue);
    });

    test('stopProcessing restores previous variant state', () {
      final variants = [variant('Balanced'), variant('Formal')];
      final state = const HomeFlowState.empty()
          .withVariants(variants, selectedIndex: 1)
          .startProcessing()
          .stopProcessing();

      expect(state.phase, HomeFlowPhase.variants);
      expect(state.variants, variants);
      expect(state.selectedIndex, 1);
      expect(state.isProcessing, isFalse);
    });

    test('withVariants stores selected index', () {
      final variants = [variant('Balanced'), variant('Formal')];
      final state = const HomeFlowState.empty().withVariants(
        variants,
        selectedIndex: 1,
      );

      expect(state.phase, HomeFlowPhase.variants);
      expect(state.variants, variants);
      expect(state.selectedIndex, 1);
      expect(state.hasVariants, isTrue);
    });

    test('clearSelection keeps variants', () {
      final variants = [variant('Balanced'), variant('Formal')];
      final state = const HomeFlowState.empty()
          .withVariants(variants, selectedIndex: 1)
          .clearSelection();

      expect(state.phase, HomeFlowPhase.variants);
      expect(state.variants, variants);
      expect(state.selectedIndex, isNull);
    });

    test('invalid select is no-op', () {
      final variants = [variant('Balanced')];
      final state = const HomeFlowState.empty().withVariants(
        variants,
        selectedIndex: 0,
      );

      expect(state.selectVariant(-1), same(state));
      expect(state.selectVariant(1), same(state));
    });
  });
}
