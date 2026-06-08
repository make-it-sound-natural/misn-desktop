/// Parsed app version from pubspec.yaml.
final class ReleaseVersion {
  /// Creates a release version.
  const ReleaseVersion({
    required this.marketingVersion,
    required this.buildNumber,
  });

  /// Parses a pubspec version value such as `1.2.3+45`.
  factory ReleaseVersion.parsePubspecValue(String value) {
    final parts = value.trim().split('+');
    if (parts.length != 2) {
      throw FormatException(
        'Version must include build number',
        value,
      );
    }

    final buildNumber = int.tryParse(parts[1]);
    if (buildNumber == null || buildNumber < 1) {
      throw FormatException(
        'Build number must be positive',
        value,
      );
    }

    return ReleaseVersion(
      marketingVersion: parts[0],
      buildNumber: buildNumber,
    );
  }

  /// User-visible version part before `+`.
  final String marketingVersion;

  /// Monotonic build number after `+`.
  final int buildNumber;

  /// Value written to pubspec.yaml.
  String get pubspecValue => '$marketingVersion+$buildNumber';

  /// Returns true when a marketing version matches channel policy.
  static bool isValidForChannel(
    String channel,
    String marketingVersion,
  ) {
    return switch (channel) {
      'stable' => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(marketingVersion),
      'beta' => RegExp(r'^\d+\.\d+\.\d+-beta\.\d+$').hasMatch(marketingVersion),
      'nightly' => RegExp(
        r'^\d+\.\d+\.\d+-nightly\.\d{8}\.\d+$',
      ).hasMatch(marketingVersion),
      _ => false,
    };
  }
}
