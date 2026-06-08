import 'package:make_it_sound_natural/models/correction_variant.dart';

/// Phase of the Home correction flow.
enum HomeFlowPhase {
  /// No generated variants are available and no generation is running.
  empty,

  /// Variant generation is running.
  processing,

  /// Generated variants are available.
  variants,
}

/// Immutable state machine for the Home correction flow.
class HomeFlowState {
  const HomeFlowState._({
    required this.phase,
    required this.variants,
    required this.selectedIndex,
  });

  /// Empty initial state.
  const HomeFlowState.empty()
    : phase = HomeFlowPhase.empty,
      variants = const [],
      selectedIndex = null;

  /// Current flow phase.
  final HomeFlowPhase phase;

  /// Generated variants currently shown by the Home screen.
  final List<CorrectionVariant> variants;

  /// Selected variant index, if any.
  final int? selectedIndex;

  /// Whether variant generation is currently running.
  bool get isProcessing => phase == HomeFlowPhase.processing;

  /// Whether generated variants are available.
  bool get hasVariants => variants.isNotEmpty;

  /// Moves into processing while preserving any visible variants.
  HomeFlowState startProcessing() {
    return HomeFlowState._(
      phase: HomeFlowPhase.processing,
      variants: variants,
      selectedIndex: selectedIndex,
    );
  }

  /// Leaves processing and restores the previous display state.
  HomeFlowState stopProcessing() {
    if (!isProcessing) return this;
    return HomeFlowState._(
      phase: hasVariants ? HomeFlowPhase.variants : HomeFlowPhase.empty,
      variants: variants,
      selectedIndex: selectedIndex,
    );
  }

  /// Replaces the visible variants and selected index.
  HomeFlowState withVariants(
    List<CorrectionVariant> nextVariants, {
    int? selectedIndex,
  }) {
    if (nextVariants.isEmpty) return const HomeFlowState.empty();
    final copiedVariants = List<CorrectionVariant>.unmodifiable(nextVariants);
    return HomeFlowState._(
      phase: HomeFlowPhase.variants,
      variants: copiedVariants,
      selectedIndex: _validIndex(selectedIndex, copiedVariants)
          ? selectedIndex
          : null,
    );
  }

  /// Clears selection while preserving variants and phase.
  HomeFlowState clearSelection() {
    if (selectedIndex == null) return this;
    return HomeFlowState._(
      phase: phase,
      variants: variants,
      selectedIndex: null,
    );
  }

  /// Selects a variant when the index is valid.
  HomeFlowState selectVariant(int index) {
    if (!_validIndex(index, variants)) return this;
    return HomeFlowState._(
      phase: phase,
      variants: variants,
      selectedIndex: index,
    );
  }

  static bool _validIndex(int? index, List<CorrectionVariant> variants) {
    return index != null && index >= 0 && index < variants.length;
  }
}
