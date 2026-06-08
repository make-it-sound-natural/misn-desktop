import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manager/project_files.dart';

void main() {
  group('ProjectFiles', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('release_manager_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reads and writes pubspec version', () {
      final pubspec = File('${tempDir.path}/pubspec.yaml')
        ..writeAsStringSync('name: app\nversion: 1.0.0+1\n');

      expect(ProjectFiles.readPubspecVersion(pubspec), '1.0.0+1');

      ProjectFiles.writePubspecVersion(pubspec, '1.1.0+2');

      expect(
        pubspec.readAsStringSync(),
        'name: app\nversion: 1.1.0+2\n',
      );
    });

    test('patches macOS plist channel values', () {
      final plist = File('${tempDir.path}/Info.plist')
        ..writeAsStringSync('''
<dict>
  <key>CFBundleDisplayName</key>
  <string>Make It Sound Natural</string>
  <key>CFBundleIdentifier</key>
  <string>dev.maximtop.makeitsoundnatural</string>
  <key>SUFeedURL</key>
  <string>https://old.example/appcast.xml</string>
</dict>
''');

      ProjectFiles.patchInfoPlist(
        plist,
        displayName: 'Make It Sound Natural Beta',
        bundleId: 'dev.maximtop.makeitsoundnatural.beta',
        feedUrl: 'https://raw.example/appcast-beta.xml',
      );

      expect(
        plist.readAsStringSync(),
        contains('<string>Make It Sound Natural Beta</string>'),
      );
      expect(
        plist.readAsStringSync(),
        contains(
          '<string>dev.maximtop.makeitsoundnatural.beta</string>',
        ),
      );
      expect(
        plist.readAsStringSync(),
        contains(
          '<string>https://raw.example/appcast-beta.xml</string>',
        ),
      );
    });

    test('renames built app bundle for channel', () {
      final releaseDir = Directory('${tempDir.path}/Release')..createSync();
      Directory('${releaseDir.path}/Make It Sound Natural.app').createSync();

      final renamed = ProjectFiles.renameBuiltApp(
        releaseDir,
        fromName: 'Make It Sound Natural',
        toName: 'Make It Sound Natural Beta',
      );

      expect(
        Directory('${releaseDir.path}/Make It Sound Natural.app').existsSync(),
        isFalse,
      );
      expect(
        renamed.path,
        endsWith('Make It Sound Natural Beta.app'),
      );
      expect(renamed.existsSync(), isTrue);
    });
  });
}
