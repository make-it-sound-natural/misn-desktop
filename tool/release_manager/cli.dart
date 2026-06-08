import 'dart:io';

import 'appcast_writer.dart';
import 'project_files.dart';
import 'release_channel.dart';
import 'release_version.dart';

/// Command-line entrypoint for release automation.
abstract final class ReleaseCli {
  /// Runs a release manager command and returns a process-like
  /// exit code.
  static int run(List<String> args) {
    if (args.isEmpty) {
      return 64;
    }
    return switch (args.first) {
      'validate' => _validate(args.skip(1).toList()),
      'bump' => _bump(args.skip(1).toList()),
      'configure-built-app' => _configureBuiltApp(args.skip(1).toList()),
      'update-appcast' => _updateAppcast(args.skip(1).toList()),
      _ => 64,
    };
  }

  static const String _minimumSystemVersion = '10.15';

  static int _validate(List<String> args) {
    final channelId = _value(args, '--channel');
    final version = _value(args, '--version');
    final sourceBranch = _value(args, '--source-branch');
    if (channelId == null || version == null || sourceBranch == null) {
      return 64;
    }

    final channel = ReleaseChannelConfig.byId(channelId);
    if (channel.requiresMaster && sourceBranch != 'master') {
      return 64;
    }
    if (!ReleaseVersion.isValidForChannel(channelId, version)) {
      return 64;
    }
    return 0;
  }

  static int _bump(List<String> args) {
    final version = _value(args, '--version');
    final buildNumberRaw = _value(args, '--build-number');
    final pubspecPath = _value(args, '--pubspec') ?? 'pubspec.yaml';
    if (version == null || buildNumberRaw == null) {
      return 64;
    }

    final pubspec = File(pubspecPath);
    if (!pubspec.existsSync()) {
      return 66;
    }

    int buildNumber;
    if (buildNumberRaw == 'auto') {
      final current = ProjectFiles.readPubspecVersion(pubspec);
      final parsed = ReleaseVersion.parsePubspecValue(current);
      buildNumber = parsed.buildNumber + 1;
    } else {
      buildNumber = int.tryParse(buildNumberRaw) ?? -1;
      if (buildNumber < 1) {
        return 64;
      }
    }

    ProjectFiles.writePubspecVersion(
      pubspec,
      '$version+$buildNumber',
    );
    return 0;
  }

  static int _configureBuiltApp(List<String> args) {
    final channelId = _value(args, '--channel');
    final releaseDirPath = _value(args, '--release-dir');
    final repo = _value(args, '--repo');
    final updateBaseUrl = _value(args, '--update-base-url');
    final bundleVersion = _value(args, '--bundle-version');
    final shortVersion = _value(args, '--short-version');
    if (channelId == null || releaseDirPath == null || repo == null) {
      return 64;
    }

    final channel = ReleaseChannelConfig.byId(channelId);
    final feedUrl = _feedUrl(
      repo: repo,
      channel: channel,
      updateBaseUrl: updateBaseUrl,
    );

    Directory appBundle;
    try {
      appBundle = channel.id == 'stable'
          ? Directory('$releaseDirPath/${channel.appName}.app')
          : ProjectFiles.renameBuiltApp(
              Directory(releaseDirPath),
              fromName: ReleaseChannelConfig.stable.appName,
              toName: channel.appName,
            );
    } on FileSystemException {
      return 66;
    }

    final infoPlist = File('${appBundle.path}/Contents/Info.plist');
    if (!infoPlist.existsSync()) {
      return 66;
    }

    ProjectFiles.patchInfoPlist(
      infoPlist,
      displayName: channel.appName,
      bundleId: channel.bundleId,
      feedUrl: feedUrl,
      bundleVersion: bundleVersion,
      shortVersion: shortVersion,
    );
    return 0;
  }

  static int _updateAppcast(List<String> args) {
    final channelId = _value(args, '--channel');
    final version = _value(args, '--version');
    final repo = _value(args, '--repo');
    final updateBaseUrl = _value(args, '--update-base-url');
    final dmgSizeRaw = _value(args, '--dmg-size');
    final sparkleSignature = _value(args, '--sparkle-signature');
    if (channelId == null ||
        version == null ||
        repo == null ||
        dmgSizeRaw == null ||
        sparkleSignature == null) {
      return 64;
    }
    final sparkleVersion = _value(args, '--sparkle-version') ?? version;

    final dmgSize = int.tryParse(dmgSizeRaw);
    if (dmgSize == null || dmgSize < 1 || sparkleSignature.isEmpty) {
      return 64;
    }

    final channel = ReleaseChannelConfig.byId(channelId);
    final feed = File(_value(args, '--feed') ?? channel.feedPath);
    if (!feed.existsSync()) {
      return 66;
    }

    final notesFilePath = _value(args, '--notes-file');
    final notes = notesFilePath == null
        ? <String>[channel.displayName]
        : File(
            notesFilePath,
          ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();

    AppcastWriter.insertItem(
      feed,
      title: _appcastTitle(channel, version),
      version: sparkleVersion,
      shortVersion: version,
      pubDate: _value(args, '--pub-date') ?? HttpDate.format(DateTime.now()),
      minimumSystemVersion: _minimumSystemVersion,
      dmgUrl: _dmgUrl(
        repo: repo,
        channel: channel,
        version: version,
        updateBaseUrl: updateBaseUrl,
      ),
      sparkleSignature: sparkleSignature,
      dmgSize: dmgSize,
      notes: notes.isEmpty ? <String>[channel.displayName] : notes,
    );
    return 0;
  }

  static String _appcastTitle(ReleaseChannelConfig channel, String version) {
    return switch (channel.id) {
      'stable' => 'Version $version',
      'beta' => 'Version $version (Beta)',
      'nightly' => 'Nightly $version',
      _ => 'Version $version',
    };
  }

  static String _artifactPrefix(ReleaseChannelConfig channel) {
    return channel.appName.replaceAll(' ', '');
  }

  static String _feedUrl({
    required String repo,
    required ReleaseChannelConfig channel,
    required String? updateBaseUrl,
  }) {
    final normalizedBaseUrl = _normalizeBaseUrl(updateBaseUrl);
    if (normalizedBaseUrl != null) {
      return '$normalizedBaseUrl/${channel.feedPath}';
    }

    return 'https://raw.githubusercontent.com/'
        '$repo/master/${channel.feedPath}';
  }

  static String _dmgUrl({
    required String repo,
    required ReleaseChannelConfig channel,
    required String version,
    required String? updateBaseUrl,
  }) {
    final artifactName = '${_artifactPrefix(channel)}-$version.dmg';
    final normalizedBaseUrl = _normalizeBaseUrl(updateBaseUrl);
    if (normalizedBaseUrl != null) {
      return '$normalizedBaseUrl/$artifactName';
    }

    return 'https://github.com/$repo/releases/download/v$version/'
        '$artifactName';
  }

  static String? _normalizeBaseUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  static String? _value(List<String> args, String name) {
    final index = args.indexOf(name);
    if (index < 0 || index + 1 >= args.length) {
      return null;
    }
    return args[index + 1];
  }
}
