import 'dart:async';

import 'package:logging/logging.dart';
import 'package:make_it_sound_natural/models/correction_variant.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/utils/logger.dart';

/// Exception thrown when OpenAI API operations fail.
class OpenAIException implements Exception {
  /// Creates an OpenAI exception with the given error message.
  OpenAIException(this.message);

  /// The error message describing what went wrong.
  final String message;
  @override
  String toString() => message;
}

/// Service for generating text correction variants using LLM APIs.
class OpenAIService {
  final Logger _log = getLogger('OpenAIService');

  /// Generates text correction variants for the given text.
  ///
  /// [text] is the text to improve. [context] is optional user context.
  /// Returns a list of correction variants with different styles.
  Future<List<CorrectionVariant>> generateVariants(
    String text, {
    String? context,
  }) async {
    try {
      // Delegate to native shortcut service (background).
      // Context is handled inside the native layer if not passed,
      // but if passed explicitly (e.g. from UI override), native
      // layer should use it. Currently native generateVariants only
      // accepts text. Context is managed via setContext/getContext
      // in native. If the UI context field differs from saved
      // context, we might need to update it first. For now, we
      // assume the context in Settings/Native is the source of truth.

      final content = await ShortcutService().generateVariants(text);
      return parseVariants(content);
    } catch (e) {
      throw OpenAIException('Error generating variants: $e');
    }
  }

  /// Parses variant markers from LLM response content.
  ///
  /// Extracts variants marked with ---BALANCED---, ---CASUAL---,
  /// ---FORMAL---, and ---CONCISE--- markers. Returns a fallback list
  /// if no markers are found.
  List<CorrectionVariant> parseVariants(String content) {
    final variants = <CorrectionVariant>[];

    const balancedMarker = '---BALANCED---';
    const casualMarker = '---CASUAL---';
    const formalMarker = '---FORMAL---';
    const conciseMarker = '---CONCISE---';

    final balancedIndex = content.indexOf(balancedMarker);
    final casualIndex = content.indexOf(casualMarker);
    final formalIndex = content.indexOf(formalMarker);
    final conciseIndex = content.indexOf(conciseMarker);

    // Helper to safely extract text from index to end or next marker
    String? extractFrom(int start, int markerLength, int? nextIndex) {
      if (start == -1) return null;
      final effectiveEnd =
          (nextIndex != -1 && nextIndex != null && nextIndex > start)
          ? nextIndex
          : content.length;
      return content.substring(start + markerLength, effectiveEnd).trim();
    }

    if (balancedIndex != -1) {
      final text = extractFrom(
        balancedIndex,
        balancedMarker.length,
        casualIndex != -1 ? casualIndex : formalIndex,
      );
      if (text != null && text.isNotEmpty) {
        variants.append(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.balanced,
            text: text,
          ),
        );
      }
    }

    if (casualIndex != -1) {
      final text = extractFrom(
        casualIndex,
        casualMarker.length,
        formalIndex != -1 ? formalIndex : conciseIndex,
      );
      if (text != null && text.isNotEmpty) {
        variants.append(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.casual,
            text: text,
          ),
        );
      }
    }

    if (formalIndex != -1) {
      final text = extractFrom(formalIndex, formalMarker.length, conciseIndex);
      if (text != null && text.isNotEmpty) {
        variants.append(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.formal,
            text: text,
          ),
        );
      }
    }

    if (conciseIndex != -1) {
      final text = content
          .substring(conciseIndex + conciseMarker.length)
          .trim();
      if (text.isNotEmpty) {
        variants.append(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.concise,
            text: text,
          ),
        );
      }
    }

    if (variants.isEmpty) {
      _log.warning('No variants parsed from markers. Using fallback.');
      final fallbackText = content.trim();
      variants
        ..add(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.balanced,
            text: fallbackText,
          ),
        )
        ..add(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.casual,
            text: fallbackText,
          ),
        )
        ..add(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.formal,
            text: fallbackText,
          ),
        )
        ..add(
          CorrectionVariant.withKind(
            variantKind: CorrectionVariantKind.concise,
            text: fallbackText,
          ),
        );
    }

    return variants;
  }
}

extension on List<CorrectionVariant> {
  void append(CorrectionVariant variant) => add(variant);
}
