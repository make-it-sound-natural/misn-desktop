import 'dart:io';

/// Helpers for release automation file edits.
abstract final class ProjectFiles {
  /// Reads the first `version:` value from pubspec.yaml.
  static String readPubspecVersion(File pubspec) {
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    if (match == null) {
      throw const FormatException(
        'pubspec.yaml has no version field',
      );
    }
    return match.group(1)!;
  }

  /// Replaces the first `version:` value in pubspec.yaml.
  static void writePubspecVersion(File pubspec, String version) {
    final content = pubspec.readAsStringSync();
    final updated = content.replaceFirst(
      RegExp(r'^version:\s*\S+', multiLine: true),
      'version: $version',
    );
    if (updated == content) {
      throw const FormatException(
        'pubspec.yaml has no version field',
      );
    }
    pubspec.writeAsStringSync(updated);
  }

  /// Patches channel-specific display name, bundle id, and
  /// Sparkle feed URL in Info.plist.
  static void patchInfoPlist(
    File plist, {
    required String displayName,
    required String bundleId,
    required String feedUrl,
    String? bundleVersion,
    String? shortVersion,
  }) {
    var content = plist.readAsStringSync();
    content = _replacePlistString(
      content,
      'CFBundleDisplayName',
      displayName,
    );
    content = _replacePlistString(
      content,
      'CFBundleIdentifier',
      bundleId,
    );
    content = _replacePlistString(content, 'SUFeedURL', feedUrl);
    if (bundleVersion != null) {
      content = _replacePlistString(
        content,
        'CFBundleVersion',
        bundleVersion,
      );
    }
    if (shortVersion != null) {
      content = _replacePlistString(
        content,
        'CFBundleShortVersionString',
        shortVersion,
      );
    }
    plist.writeAsStringSync(content);
  }

  /// Renames the built `.app` bundle for a channel before signing.
  static Directory renameBuiltApp(
    Directory releaseDir, {
    required String fromName,
    required String toName,
  }) {
    final source = Directory('${releaseDir.path}/$fromName.app');
    final target = Directory('${releaseDir.path}/$toName.app');
    if (!source.existsSync()) {
      throw FileSystemException(
        'Built app not found',
        source.path,
      );
    }
    if (target.existsSync()) {
      target.deleteSync(recursive: true);
    }
    source.renameSync(target.path);
    return target;
  }

  static String _replacePlistString(
    String content,
    String key,
    String value,
  ) {
    final pattern = RegExp(
      '(<key>$key</key>\\s*<string>)([^<]*)(</string>)',
      multiLine: true,
    );
    final match = pattern.firstMatch(content);
    if (match == null) {
      throw FormatException('Info.plist has no $key string');
    }
    return content.replaceFirst(
      pattern,
      '${match.group(1)}$value${match.group(3)}',
    );
  }
}
