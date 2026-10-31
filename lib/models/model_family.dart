/// A provider's model family and the version scheme of its model slugs.
class ModelFamily {
  /// Creates a family whose pattern captures its numeric version parts.
  const ModelFamily({
    required this.provider,
    required this.id,
    required this.pattern,
    required this.supportsFast,
  });

  /// Provider identifier owning this family.
  final String provider;

  /// Stable identifier shared by all versions of the family.
  final String id;

  /// Anchored slug pattern with capture groups for numeric version parts.
  final RegExp pattern;

  /// Whether this family supports fast processing.
  final bool supportsFast;

  /// Returns the numeric version, or null when [slug] is outside the family.
  List<int>? versionOf(String slug) {
    final match = pattern.firstMatch(slug);
    if (match == null) return null;
    return [
      for (var index = 1; index <= match.groupCount; index++)
        if (match.group(index) case final String part)
          ...part.split('.').map(int.parse),
    ];
  }
}

/// Compares numeric version tuples, treating missing parts as zero.
int compareModelVersions(List<int> a, List<int> b) {
  final length = a.length > b.length ? a.length : b.length;
  for (var index = 0; index < length; index++) {
    final partA = index < a.length ? a[index] : 0;
    final partB = index < b.length ? b[index] : 0;
    final comparison = partA.compareTo(partB);
    if (comparison != 0) return comparison;
  }
  return 0;
}
