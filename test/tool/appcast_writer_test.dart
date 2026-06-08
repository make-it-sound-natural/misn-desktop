import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manager/appcast_writer.dart';

void main() {
  group('AppcastWriter', () {
    test('creates empty feed', () {
      final feed = AppcastWriter.emptyFeed(
        title: 'Make It Sound Natural Beta',
        link: 'https://github.com/make-it-sound-natural/misn-desktop',
      );

      expect(
        feed,
        contains('<title>Make It Sound Natural Beta</title>'),
      );
      expect(feed, contains('<language>en</language>'));
      expect(feed, contains('</channel>'));
    });

    test('inserts release item after language', () {
      final tempDir = Directory.systemTemp.createTempSync('appcast_writer_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final feed = File('${tempDir.path}/appcast.xml')
        ..writeAsStringSync(
          AppcastWriter.emptyFeed(
            title: 'Make It Sound Natural',
            link: 'https://github.com/make-it-sound-natural/misn-desktop',
          ),
        );

      AppcastWriter.insertItem(
        feed,
        title: 'Version 1.2.3',
        version: '1.2.3',
        shortVersion: '1.2.3',
        pubDate: 'Sun, 03 May 2026 12:00:00 +0000',
        minimumSystemVersion: '10.15',
        dmgUrl: 'https://github.com/org/repo/releases/download/v1.2.3/app.dmg',
        sparkleSignature: 'sparkle:edSignature="abc"',
        dmgSize: 123,
        notes: const ['Added release automation'],
      );

      final content = feed.readAsStringSync();
      expect(
        content,
        contains('<sparkle:version>1.2.3</sparkle:version>'),
      );
      expect(content, contains('sparkle:edSignature="abc"'));
      expect(content, contains('length="123"'));
    });
  });
}
