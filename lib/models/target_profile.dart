import 'package:flutter/foundation.dart';

/// Source type for a target language profile.
enum TargetProfileSource {
  /// Profile shipped with the app.
  builtIn,

  /// Profile created by the user.
  custom,
}

/// Language or dialect target applied independently from style variants.
@immutable
class TargetProfile {
  /// Creates a target profile.
  const TargetProfile({
    required this.id,
    required this.name,
    required this.instruction,
    required this.source,
    this.description,
  });

  /// Creates a profile from persisted JSON data.
  factory TargetProfile.fromJson(Map<String, Object?> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final instruction = json['instruction'] as String? ?? '';
    final sourceName = json['source'] as String? ?? '';
    final source = TargetProfileSource.values
        .where((value) => value.name == sourceName)
        .firstOrNull;

    if (id.trim().isEmpty ||
        name.trim().isEmpty ||
        instruction.trim().isEmpty ||
        source == null) {
      throw const FormatException('Invalid target profile');
    }

    return TargetProfile(
      id: id,
      name: name,
      instruction: instruction,
      source: source,
      description: json['description'] as String?,
    );
  }

  /// Stable identifier.
  final String id;

  /// User-visible name.
  final String name;

  /// Prompt instruction sent to the LLM.
  final String instruction;

  /// Built-in or custom source.
  final TargetProfileSource source;

  /// Optional UI detail text.
  final String? description;

  /// Whether this profile is shipped with the app.
  bool get isBuiltIn => source == TargetProfileSource.builtIn;

  /// Whether this profile was created by the user.
  bool get isCustom => source == TargetProfileSource.custom;

  /// Converts this profile to persisted JSON data.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'instruction': instruction,
    'source': source.name,
    if (description != null) 'description': description,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          instruction == other.instruction &&
          source == other.source &&
          description == other.description;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    instruction,
    source,
    description,
  );
}
