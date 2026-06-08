import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manager/appcast_writer.dart';
import '../../tool/release_manager/cli.dart';

void main() {
  group('ReleaseCli', () {
    test('validates stable branch policy', () {
      final exitCode = ReleaseCli.run([
        'validate',
        '--channel',
        'stable',
        '--version',
        '1.2.3',
        '--source-branch',
        'feature/test',
      ]);

      expect(exitCode, 64);
    });

    test('accepts stable from master', () {
      final exitCode = ReleaseCli.run([
        'validate',
        '--channel',
        'stable',
        '--version',
        '1.2.3',
        '--source-branch',
        'master',
      ]);

      expect(exitCode, 0);
    });

    test('accepts beta from feature branch', () {
      final exitCode = ReleaseCli.run([
        'validate',
        '--channel',
        'beta',
        '--version',
        '1.2.3-beta.1',
        '--source-branch',
        'feature/test',
      ]);

      expect(exitCode, 0);
    });

    test('bump writes version to pubspec', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final pubspec = File('${tempDir.path}/pubspec.yaml')
        ..writeAsStringSync('name: app\nversion: 1.0.0+1\n');

      final exitCode = ReleaseCli.run([
        'bump',
        '--version',
        '1.2.0',
        '--build-number',
        '5',
        '--pubspec',
        pubspec.path,
      ]);

      expect(exitCode, 0);
      expect(pubspec.readAsStringSync(), contains('version: 1.2.0+5'));
    });

    test('bump auto increments build number', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final pubspec = File('${tempDir.path}/pubspec.yaml')
        ..writeAsStringSync('name: app\nversion: 1.0.0+7\n');

      final exitCode = ReleaseCli.run([
        'bump',
        '--version',
        '1.1.0',
        '--build-number',
        'auto',
        '--pubspec',
        pubspec.path,
      ]);

      expect(exitCode, 0);
      expect(pubspec.readAsStringSync(), contains('version: 1.1.0+8'));
    });

    test('configure-built-app patches plist and renames', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final releaseDir = Directory('${tempDir.path}/Release')..createSync();
      final appContents = Directory(
        '${releaseDir.path}/Make It Sound Natural.app/Contents',
      )..createSync(recursive: true);
      File('${appContents.path}/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
<key>CFBundleDisplayName</key>
<string>Make It Sound Natural</string>
<key>CFBundleIdentifier</key>
<string>dev.maximtop.makeitsoundnatural</string>
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/x/y/master/appcast.xml</string>
</dict>
</plist>''');

      final exitCode = ReleaseCli.run([
        'configure-built-app',
        '--channel',
        'beta',
        '--release-dir',
        releaseDir.path,
        '--repo',
        'org/repo',
        '--bundle-version',
        '42',
        '--short-version',
        '1.2.3',
      ]);

      expect(exitCode, 0);
      final renamedPlist = File(
        '${releaseDir.path}/Make It Sound Natural Beta.app/Contents/Info.plist',
      );
      final plistContent = renamedPlist.readAsStringSync();
      expect(plistContent, contains('Make It Sound Natural Beta'));
      expect(
        plistContent,
        contains('dev.maximtop.makeitsoundnatural.beta'),
      );
      expect(
        plistContent,
        contains('appcast-beta.xml'),
      );
      expect(plistContent, contains('<string>1.2.3</string>'));
      expect(plistContent, contains('<string>42</string>'));
      expect(
        Directory(
          '${releaseDir.path}/Make It Sound Natural Beta.app',
        ).existsSync(),
        isTrue,
      );
    });

    test('configure-built-app can use custom update base URL', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final releaseDir = Directory('${tempDir.path}/Release')..createSync();
      final appContents = Directory(
        '${releaseDir.path}/Make It Sound Natural.app/Contents',
      )..createSync(recursive: true);
      File('${appContents.path}/Info.plist').writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
<key>CFBundleDisplayName</key>
<string>Make It Sound Natural</string>
<key>CFBundleIdentifier</key>
<string>dev.maximtop.makeitsoundnatural</string>
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/x/y/master/appcast.xml</string>
</dict>
</plist>''');

      final exitCode = ReleaseCli.run([
        'configure-built-app',
        '--channel',
        'nightly',
        '--release-dir',
        releaseDir.path,
        '--repo',
        'org/repo',
        '--update-base-url',
        'https://updates.example.com/misn/',
      ]);

      expect(exitCode, 0);
      final plistContent = File(
        '${releaseDir.path}/Make It Sound Natural Nightly.app/Contents/Info.plist',
      ).readAsStringSync();
      expect(
        plistContent,
        contains('https://updates.example.com/misn/appcast-nightly.xml'),
      );
    });

    test('configure-built-app fails when built app is missing', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final releaseDir = Directory('${tempDir.path}/Release')..createSync();

      final exitCode = ReleaseCli.run([
        'configure-built-app',
        '--channel',
        'beta',
        '--release-dir',
        releaseDir.path,
        '--repo',
        'org/repo',
      ]);

      expect(exitCode, 66);
    });

    test('update-appcast writes channel item', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final feed = File('${tempDir.path}/appcast-beta.xml')
        ..writeAsStringSync(
          AppcastWriter.emptyFeed(
            title: 'Make It Sound Natural Beta',
            link: 'https://example.com',
          ),
        );
      final notes = File('${tempDir.path}/notes.txt')
        ..writeAsStringSync('Fixed release flow\n');

      final exitCode = ReleaseCli.run([
        'update-appcast',
        '--channel',
        'beta',
        '--version',
        '1.2.3-beta.1',
        '--repo',
        'org/repo',
        '--dmg-size',
        '123',
        '--sparkle-signature',
        'sparkle:edSignature="abc"',
        '--feed',
        feed.path,
        '--notes-file',
        notes.path,
        '--pub-date',
        'Mon, 04 May 2026 00:00:00 GMT',
      ]);

      final content = feed.readAsStringSync();
      expect(exitCode, 0);
      expect(content, contains('Version 1.2.3-beta.1 (Beta)'));
      expect(content, contains('MakeItSoundNaturalBeta-1.2.3-beta.1.dmg'));
      expect(content, contains('sparkle:edSignature="abc"'));
      expect(content, contains('<li>Fixed release flow</li>'));
    });

    test('update-appcast can use custom update base URL', () {
      final tempDir = Directory.systemTemp.createTempSync('release_cli_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final feed = File('${tempDir.path}/appcast-nightly.xml')
        ..writeAsStringSync(
          AppcastWriter.emptyFeed(
            title: 'Make It Sound Natural Nightly',
            link: 'https://example.com',
          ),
        );

      final exitCode = ReleaseCli.run([
        'update-appcast',
        '--channel',
        'nightly',
        '--version',
        '1.2.3-nightly.20260602.1',
        '--sparkle-version',
        '101',
        '--repo',
        'org/repo',
        '--update-base-url',
        'https://updates.example.com/misn/',
        '--dmg-size',
        '123',
        '--sparkle-signature',
        'sparkle:edSignature="abc"',
        '--feed',
        feed.path,
        '--pub-date',
        'Mon, 04 May 2026 00:00:00 GMT',
      ]);

      final content = feed.readAsStringSync();
      expect(exitCode, 0);
      expect(
        content,
        contains(
          'https://updates.example.com/misn/'
          'MakeItSoundNaturalNightly-1.2.3-nightly.20260602.1.dmg',
        ),
      );
      expect(content, contains('<sparkle:version>101</sparkle:version>'));
      expect(
        content,
        contains(
          '<sparkle:shortVersionString>'
          '1.2.3-nightly.20260602.1'
          '</sparkle:shortVersionString>',
        ),
      );
      expect(content, isNot(contains('github.com/org/repo')));
    });
  });
}
