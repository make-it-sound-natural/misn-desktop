/// Release channel metadata used by GitHub release automation.
final class ReleaseChannelConfig {
  const ReleaseChannelConfig({
    required this.id,
    required this.displayName,
    required this.appName,
    required this.bundleId,
    required this.feedPath,
    required this.isPrerelease,
    required this.requiresMaster,
  });

  /// Machine-readable channel id.
  final String id;

  /// User-visible channel label.
  final String displayName;

  /// macOS application display name.
  final String appName;

  /// macOS bundle identifier.
  final String bundleId;

  /// Sparkle appcast file path in the repository root.
  final String feedPath;

  /// Whether GitHub Release should be marked as prerelease.
  final bool isPrerelease;

  /// Whether release source branch must be master.
  final bool requiresMaster;

  /// Returns release channel config by id.
  static ReleaseChannelConfig byId(String id) {
    return switch (id) {
      'stable' => stable,
      'beta' => beta,
      'nightly' => nightly,
      _ => throw ArgumentError.value(
        id,
        'id',
        'Unknown release channel',
      ),
    };
  }

  /// Stable public release channel.
  static const stable = ReleaseChannelConfig(
    id: 'stable',
    displayName: 'Stable',
    appName: 'Make It Sound Natural',
    bundleId: 'dev.maximtop.makeitsoundnatural',
    feedPath: 'appcast.xml',
    isPrerelease: false,
    requiresMaster: true,
  );

  /// Beta prerelease channel.
  static const beta = ReleaseChannelConfig(
    id: 'beta',
    displayName: 'Beta',
    appName: 'Make It Sound Natural Beta',
    bundleId: 'dev.maximtop.makeitsoundnatural.beta',
    feedPath: 'appcast-beta.xml',
    isPrerelease: true,
    requiresMaster: false,
  );

  /// Nightly internal test channel.
  static const nightly = ReleaseChannelConfig(
    id: 'nightly',
    displayName: 'Nightly',
    appName: 'Make It Sound Natural Nightly',
    bundleId: 'dev.maximtop.makeitsoundnatural.nightly',
    feedPath: 'appcast-nightly.xml',
    isPrerelease: true,
    requiresMaster: false,
  );
}
