import 'package:make_it_sound_natural/constants/model_families.dart';
import 'package:make_it_sound_natural/models/model_family.dart';

/// Resolves the newest available slug for each family of [provider].
Map<String, String> resolveFamilies(String provider, Iterable<String> ids) {
  final resolved = <String, String>{};
  for (final family in ModelFamilies.forProvider(provider)) {
    String? newestSlug;
    List<int>? newestVersion;
    for (final slug in ids) {
      final version = family.versionOf(slug);
      if (version == null) continue;
      final comparison = newestVersion == null
          ? 1
          : compareModelVersions(version, newestVersion);
      if (comparison > 0 ||
          (comparison == 0 &&
              newestSlug != null &&
              slug.compareTo(newestSlug) < 0)) {
        newestSlug = slug;
        newestVersion = version;
      }
    }
    if (newestSlug != null) resolved[family.id] = newestSlug;
  }
  return resolved;
}

/// Finds the family matching [slug] within [provider].
ModelFamily? familyForSlug(String provider, String slug) {
  for (final family in ModelFamilies.forProvider(provider)) {
    if (family.versionOf(slug) != null) return family;
  }
  return null;
}
