import 'package:make_it_sound_natural/models/correction_variant.dart';

/// Phase of the Home correction flow.
enum HomeFlowPhase {
  /// No generated variants are available and no generation is running.
  empty,

  /// Variant generation is running.
  processing,

  /// Generated variants are available.
  variants,

  /// The active provider rejected the API key.
  error,
}

/// Immutable state machine for the Home correction flow.
class HomeFlowState {
  const HomeFlowState._({
    required this.phase,
    required this.variants,
    required this.selectedIndex,
    this.selectionApplied = false,
    this.errorProviderName,
  });

  /// Empty initial state.
  const HomeFlowState.empty()
    : phase = HomeFlowPhase.empty,
      variants = const [],
      selectedIndex = null,
      selectionApplied = false,
      errorProviderName = null;

  /// Current flow phase.
  final HomeFlowPhase phase;

  /// Generated variants currently shown by the Home screen.
  final List<CorrectionVariant> variants;

  /// Highlighted variant index, if any.
  ///
  /// After a run this is the preferred tone, which is merely pre-selected.
  /// It only counts as applied once the user picks it: see
  /// [selectionApplied].
  final int? selectedIndex;

  /// Whether [selectedIndex] was applied by the user rather than pre-selected.
  ///
  /// Only a real apply pastes the text back and copies it, so only a real
  /// apply may claim the accent "Applied" state.
  final bool selectionApplied;

  /// Display name of the provider that rejected the API key, if any.
  final String? errorProviderName;

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
      selectionApplied: selectionApplied,
    );
  }

  /// Leaves processing and restores the previous display state.
  ///
  /// An error state survives cancellation: its banner is what explains why
  /// no variants are on screen.
  HomeFlowState stopProcessing() {
    if (!isProcessing) return this;
    return HomeFlowState._(
      phase: hasVariants ? HomeFlowPhase.variants : HomeFlowPhase.empty,
      variants: variants,
      selectedIndex: selectedIndex,
      selectionApplied: selectionApplied,
    );
  }

  /// Enters the auth-failure state, replacing any visible variants.
  HomeFlowState failWithAuthFailure({required String providerName}) {
    return HomeFlowState._(
      phase: HomeFlowPhase.error,
      variants: const [],
      selectedIndex: null,
      errorProviderName: providerName,
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
      errorProviderName: errorProviderName,
    );
  }

  /// Highlights the variant the user picked.
  ///
  /// [applied] must reflect what the native side actually did: the highlight
  /// moves as soon as the user taps, but only a replacement that really
  /// reached the other application may claim the accent "Applied" state.
  HomeFlowState selectVariant(int index, {required bool applied}) {
    if (!_validIndex(index, variants)) return this;
    return HomeFlowState._(
      phase: phase,
      variants: variants,
      selectedIndex: index,
      selectionApplied: applied,
      errorProviderName: errorProviderName,
    );
  }

  static bool _validIndex(int? index, List<CorrectionVariant> variants) {
    return index != null && index >= 0 && index < variants.length;
  }
}
