import 'dart:convert';

import 'package:make_it_sound_natural/models/target_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Validation failure while creating a custom target profile.
class TargetProfileValidationException implements Exception {
  /// Creates a target profile validation exception.
  const TargetProfileValidationException(this.message);

  /// User-readable validation message.
  final String message;

  @override
  String toString() => message;
}

/// Result of removing a custom target profile.
class TargetProfileRemovalResult {
  /// Creates a removal result.
  const TargetProfileRemovalResult({
    required this.removed,
    required this.fallbackApplied,
    this.fallbackProfile,
  });

  /// Whether a custom profile was removed.
  final bool removed;

  /// Whether selected profile moved to the default built-in profile.
  final bool fallbackApplied;

  /// Fallback profile selected after removal.
  final TargetProfile? fallbackProfile;
}

/// Manages target language/dialect profiles.
class TargetProfileService {
  /// Creates a target profile service.
  TargetProfileService({String Function()? idFactory})
    : _idFactory =
          idFactory ??
          (() => 'custom_${DateTime.now().microsecondsSinceEpoch}');

  static const String _selectedIdKey = 'target_profile_selected_id';
  static const String _customProfilesKey = 'target_profile_custom_profiles';
  static const String _selectionConfirmedKey =
      'target_profile_selection_confirmed';

  /// Safe fallback profile ID.
  static const String defaultProfileId = 'americanEnglish';

  /// Built-in target profiles shipped with the app.
  static const List<TargetProfile> builtInProfiles = [
    TargetProfile(
      id: defaultProfileId,
      name: 'American English',
      instruction: 'Rewrite in natural American English.',
      source: TargetProfileSource.builtIn,
      description: 'US spelling, wording, and idiom.',
    ),
    TargetProfile(
      id: 'britishEnglish',
      name: 'British English',
      instruction: 'Rewrite in natural British English.',
      source: TargetProfileSource.builtIn,
      description: 'UK spelling, wording, and idiom.',
    ),
    TargetProfile(
      id: 'originalLanguage',
      name: 'Natural in original language',
      instruction:
          'Refine the text in its original language. Do not translate '
          'unless the input itself asks for translation.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'spanish',
      name: 'Spanish',
      instruction:
          'Translate and rewrite the entire text in natural Spanish. Every '
          'output variant must be Spanish. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'french',
      name: 'French',
      instruction:
          'Translate and rewrite the entire text in natural French. Every '
          'output variant must be French. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'german',
      name: 'German',
      instruction:
          'Translate and rewrite the entire text in natural German. Every '
          'output variant must be German. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'portuguese',
      name: 'Portuguese',
      instruction:
          'Translate and rewrite the entire text in natural Portuguese. Every '
          'output variant must be Portuguese. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'russian',
      name: 'Russian',
      instruction:
          'Translate and rewrite the entire text in natural Russian. Every '
          'output variant must be Russian. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'arabic',
      name: 'Arabic',
      instruction:
          'Translate and rewrite the entire text in natural Arabic. Every '
          'output variant must be Arabic. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'japanese',
      name: 'Japanese',
      instruction:
          'Translate and rewrite the entire text in natural Japanese. Every '
          'output variant must be Japanese. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
    TargetProfile(
      id: 'chinese',
      name: 'Chinese',
      instruction:
          'Translate and rewrite the entire text in natural Chinese. Every '
          'output variant must be Chinese. Do not leave English text except '
          'names, URLs, code, or intentionally preserved proper nouns.',
      source: TargetProfileSource.builtIn,
    ),
  ];

  final String Function() _idFactory;

  /// Whether first-run target selection is still required.
  Future<bool> isSelectionRequired() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_selectionConfirmedKey) ?? false);
  }

  /// Returns all built-in and custom profiles.
  Future<List<TargetProfile>> getAllProfiles() async => [
    ...builtInProfiles,
    ...await getCustomProfiles(),
  ];

  /// Returns persisted custom profiles, ignoring malformed entries.
  Future<List<TargetProfile>> getCustomProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_customProfilesKey);
    if (encoded == null || encoded.isEmpty) return [];

    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return [];
    }

    if (decoded is! List) return [];

    return decoded
        .whereType<Map<String, Object?>>()
        .map(_tryParseProfile)
        .nonNulls
        .where((profile) => profile.isCustom)
        .toList();
  }

  /// Returns selected profile, null if user has not selected one yet.
  Future<TargetProfile?> getSelectedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedId = prefs.getString(_selectedIdKey);
    if (selectedId == null || selectedId.isEmpty) return null;

    final profile = await getProfileById(selectedId);
    if (profile != null) return profile;

    final fallback = await getProfileById(defaultProfileId);
    await selectProfile(defaultProfileId);
    return fallback;
  }

  /// Finds a profile by ID.
  Future<TargetProfile?> getProfileById(String id) async {
    for (final profile in await getAllProfiles()) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  /// Searches profiles by visible name.
  Future<List<TargetProfile>> searchProfiles(String query) async {
    final normalized = query.trim().toLowerCase();
    final profiles = await getAllProfiles();
    if (normalized.isEmpty) return profiles;
    return profiles
        .where((profile) => profile.name.toLowerCase().contains(normalized))
        .toList();
  }

  /// Selects a profile and marks initial selection complete.
  Future<TargetProfile> selectProfile(String id) async {
    final profile = await getProfileById(id);
    if (profile == null) throw ArgumentError('Unknown target profile: $id');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedIdKey, profile.id);
    await prefs.setBool(_selectionConfirmedKey, true);
    return profile;
  }

  /// Creates a custom profile.
  Future<TargetProfile> createCustomProfile({
    required String name,
    required String instruction,
  }) async {
    final trimmedName = name.trim();
    final trimmedInstruction = instruction.trim();
    await _validateCustomProfileInput(
      name: trimmedName,
      instruction: trimmedInstruction,
    );

    final profile = TargetProfile(
      id: _idFactory(),
      name: trimmedName,
      instruction: trimmedInstruction,
      source: TargetProfileSource.custom,
    );
    final customProfiles = [...await getCustomProfiles(), profile];
    await _saveCustomProfiles(customProfiles);
    return profile;
  }

  /// Updates an existing custom profile.
  Future<TargetProfile> updateCustomProfile(
    String id, {
    required String name,
    required String instruction,
  }) async {
    final customProfiles = await getCustomProfiles();
    final index = customProfiles.indexWhere((profile) => profile.id == id);
    if (index == -1) {
      throw const TargetProfileValidationException(
        'Custom profile not found',
      );
    }

    final trimmedName = name.trim();
    final trimmedInstruction = instruction.trim();
    await _validateCustomProfileInput(
      name: trimmedName,
      instruction: trimmedInstruction,
      currentId: id,
    );

    final existingProfile = customProfiles[index];
    final updatedProfile = TargetProfile(
      id: existingProfile.id,
      name: trimmedName,
      instruction: trimmedInstruction,
      source: TargetProfileSource.custom,
      description: existingProfile.description,
    );
    customProfiles[index] = updatedProfile;
    await _saveCustomProfiles(customProfiles);
    return updatedProfile;
  }

  /// Removes a custom profile.
  Future<TargetProfileRemovalResult> removeCustomProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final wasSelected = prefs.getString(_selectedIdKey) == id;
    final customProfiles = await getCustomProfiles();
    final target = customProfiles
        .where((profile) => profile.id == id)
        .firstOrNull;

    if (target == null) {
      return const TargetProfileRemovalResult(
        removed: false,
        fallbackApplied: false,
      );
    }

    await _saveCustomProfiles(
      customProfiles.where((profile) => profile.id != id).toList(),
    );

    if (wasSelected) {
      final fallback = await selectProfile(defaultProfileId);
      return TargetProfileRemovalResult(
        removed: true,
        fallbackApplied: true,
        fallbackProfile: fallback,
      );
    }

    return const TargetProfileRemovalResult(
      removed: true,
      fallbackApplied: false,
    );
  }

  Future<void> _saveCustomProfiles(List<TargetProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customProfilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
  }

  Future<void> _validateCustomProfileInput({
    required String name,
    required String instruction,
    String? currentId,
  }) async {
    if (name.isEmpty || instruction.isEmpty) {
      throw const TargetProfileValidationException(
        'Name and instruction are required',
      );
    }

    final profiles = await getAllProfiles();
    final duplicate = profiles.any(
      (profile) =>
          profile.id != currentId &&
          profile.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      throw const TargetProfileValidationException(
        'Profile name already exists',
      );
    }
  }

  TargetProfile? _tryParseProfile(Map<String, Object?> json) {
    try {
      return TargetProfile.fromJson(json);
    } on FormatException {
      return null;
    }
  }
}
