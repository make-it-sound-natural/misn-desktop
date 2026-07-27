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

      expect(state.selectVariant(-1, applied: true), same(state));
      expect(state.selectVariant(1, applied: true), same(state));
    });
  });

  group('HomeFlowState applied selection', () {
    test('pre-selection after a run does not count as applied', () {
      final state = const HomeFlowState.empty().withVariants(
        [variant('Balanced'), variant('Formal')],
        selectedIndex: 1,
      );

      expect(state.selectedIndex, 1);
      expect(state.selectionApplied, isFalse);
    });

    test('selectVariant records what the native side reported', () {
      final state = const HomeFlowState.empty().withVariants(
        [variant('Balanced'), variant('Formal')],
        selectedIndex: 0,
      );

      expect(state.selectVariant(1, applied: true).selectionApplied, isTrue);
      // A declined replacement leaves the text on the clipboard only, so the
      // card must not claim it was applied.
      expect(state.selectVariant(1, applied: false).selectionApplied, isFalse);
      expect(state.selectVariant(1, applied: false).selectedIndex, 1);
    });

    test('a second run drops the applied flag', () {
      final state = const HomeFlowState.empty()
          .withVariants([
            variant('Balanced'),
            variant('Formal'),
          ], selectedIndex: 0)
          .selectVariant(1, applied: true)
          .withVariants([variant('Casual')], selectedIndex: 0);

      expect(
        state.selectionApplied,
        isFalse,
        reason: 'fresh results must not inherit a stale Applied badge',
      );
    });

    test('clearSelection drops the applied flag', () {
      final state = const HomeFlowState.empty()
          .withVariants([variant('Balanced')], selectedIndex: 0)
          .selectVariant(0, applied: true)
          .clearSelection();

      expect(state.selectionApplied, isFalse);
    });

    test('processing round-trip preserves the applied flag', () {
      final applied = const HomeFlowState.empty()
          .withVariants([variant('Balanced')], selectedIndex: 0)
          .selectVariant(0, applied: true);

      expect(
        applied.startProcessing().stopProcessing().selectionApplied,
        isTrue,
      );
    });
  });

  group('HomeFlowState auth-failure phase', () {
    test('failWithAuthFailure enters error and clears variants', () {
      final state = const HomeFlowState.empty()
          .withVariants([variant('Balanced')], selectedIndex: 0)
          .startProcessing()
          .failWithAuthFailure(providerName: 'OpenRouter');

      expect(state.phase, HomeFlowPhase.error);
      expect(state.variants, isEmpty);
      expect(state.selectedIndex, isNull);
      expect(state.errorProviderName, 'OpenRouter');
    });

    test('startProcessing from error clears the error', () {
      final state = const HomeFlowState.empty()
          .failWithAuthFailure(providerName: 'OpenAI')
          .startProcessing();

      expect(state.phase, HomeFlowPhase.processing);
      expect(state.errorProviderName, isNull);
    });

    test('new variants replace the error state', () {
      final state = const HomeFlowState.empty()
          .failWithAuthFailure(providerName: 'OpenAI')
          .withVariants([variant('Casual')], selectedIndex: 0);

      expect(state.phase, HomeFlowPhase.variants);
      expect(state.errorProviderName, isNull);
    });

    test('stopProcessing after an error keeps the error visible', () {
      final state = const HomeFlowState.empty()
          .failWithAuthFailure(providerName: 'OpenAI')
          .stopProcessing();

      expect(state.phase, HomeFlowPhase.error);
      expect(state.errorProviderName, 'OpenAI');
    });
  });
}
