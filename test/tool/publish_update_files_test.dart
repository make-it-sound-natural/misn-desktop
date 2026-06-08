import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('publish_update_files.sh', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('publish_update_files_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Future<ProcessResult> runPublisher(
      List<String> args, {
      Map<String, String> environment = const {},
    }) {
      return Process.run(
        'bash',
        ['scripts/publish_update_files.sh', ...args],
        environment: environment,
      );
    }

    test('skips external publishing by default', () async {
      final result = await runPublisher(['/no/such.dmg', '/no/such.xml']);

      expect(result.exitCode, 0);
      expect(
        result.stdout,
        contains('UPDATE_PUBLISH_TARGET is github; skipping'),
      );
    });

    test('rejects unknown publish target', () async {
      final result = await runPublisher(
        ['/no/such.dmg', '/no/such.xml'],
        environment: {'UPDATE_PUBLISH_TARGET': 'ftp'},
      );

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains('Unsupported UPDATE_PUBLISH_TARGET: ftp'),
      );
    });

    test('requires Cloudflare Pages variables for Cloudflare target', () async {
      final dmg = File('${tempDir.path}/app.dmg')..writeAsStringSync('dmg');
      final feed = File('${tempDir.path}/appcast.xml')
        ..writeAsStringSync('feed');

      final result = await runPublisher(
        [dmg.path, feed.path],
        environment: {
          'UPDATE_PUBLISH_TARGET': 'cloudflare_pages',
          'UPDATE_BASE_URL': 'https://misn-updates.pages.dev',
        },
      );

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains(
          'CLOUDFLARE_PAGES_PROJECT is required when '
          'UPDATE_PUBLISH_TARGET=cloudflare_pages.',
        ),
      );
    });

    test('deploys Cloudflare Pages assets with Wrangler', () async {
      final dmg = File('${tempDir.path}/app.dmg')..writeAsStringSync('dmg');
      final feed = File('${tempDir.path}/appcast.xml')
        ..writeAsStringSync('feed');
      final siteDir = Directory('${tempDir.path}/update-site');
      final binDir = Directory('${tempDir.path}/bin')..createSync();
      final log = File('${tempDir.path}/npx.log');
      final npx = File('${binDir.path}/npx')
        ..writeAsStringSync(r'''
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$NPX_LOG"
printf '%s\n' '---' >> "$NPX_LOG"
if [ "$3" = "pages" ] && [ "$4" = "project" ] && [ "$5" = "list" ]; then
  printf '%s\n' '[]'
fi
''');
      Process.runSync('chmod', ['755', npx.path]);

      final result = await runPublisher(
        [dmg.path, feed.path],
        environment: {
          'PATH': '${binDir.path}:${Platform.environment['PATH']}',
          'NPX_LOG': log.path,
          'UPDATE_PUBLISH_TARGET': 'cloudflare_pages',
          'UPDATE_BASE_URL': 'https://misn-updates.pages.dev',
          'UPDATE_SITE_DIR': siteDir.path,
          'CLOUDFLARE_PAGES_PROJECT': 'misn-updates',
          'CLOUDFLARE_PAGES_BRANCH': 'main',
          'CLOUDFLARE_API_TOKEN': 'token',
          'CLOUDFLARE_ACCOUNT_ID': 'account',
        },
      );

      expect(result.exitCode, 0);
      expect(File('${siteDir.path}/app.dmg').readAsStringSync(), 'dmg');
      expect(File('${siteDir.path}/appcast.xml').readAsStringSync(), 'feed');
      expect(
        log.readAsStringSync(),
        contains(
          'wrangler\npages\nproject\ncreate\nmisn-updates\n'
          '--production-branch\nmain',
        ),
      );
      expect(
        log.readAsStringSync(),
        contains('wrangler\npages\ndeploy\n${siteDir.path}'),
      );
      expect(log.readAsStringSync(), contains('--project-name\nmisn-updates'));
      expect(log.readAsStringSync(), contains('--branch\nmain'));
      expect(log.readAsStringSync(), contains('--commit-dirty=true'));
    });

    test(
      'skips Cloudflare Pages project creation when project exists',
      () async {
        final dmg = File('${tempDir.path}/app.dmg')..writeAsStringSync('dmg');
        final feed = File('${tempDir.path}/appcast.xml')
          ..writeAsStringSync('feed');
        final binDir = Directory('${tempDir.path}/bin')..createSync();
        final log = File('${tempDir.path}/npx.log');
        final npx = File('${binDir.path}/npx')
          ..writeAsStringSync(r'''
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$NPX_LOG"
printf '%s\n' '---' >> "$NPX_LOG"
if [ "$3" = "pages" ] && [ "$4" = "project" ] && [ "$5" = "list" ]; then
  printf '%s\n' '{"result":[{"name":"misn-updates"}]}'
fi
''');
        Process.runSync('chmod', ['755', npx.path]);

        final result = await runPublisher(
          [dmg.path, feed.path],
          environment: {
            'PATH': '${binDir.path}:${Platform.environment['PATH']}',
            'NPX_LOG': log.path,
            'UPDATE_PUBLISH_TARGET': 'cloudflare_pages',
            'UPDATE_BASE_URL': 'https://misn-updates.pages.dev',
            'CLOUDFLARE_PAGES_PROJECT': 'misn-updates',
            'CLOUDFLARE_PAGES_BRANCH': 'main',
            'CLOUDFLARE_API_TOKEN': 'token',
            'CLOUDFLARE_ACCOUNT_ID': 'account',
          },
        );

        expect(result.exitCode, 0);
        expect(log.readAsStringSync(), isNot(contains('project\ncreate')));
        expect(log.readAsStringSync(), contains('pages\ndeploy'));
      },
    );

    test(
      'continues when Cloudflare project already exists during create',
      () async {
        final dmg = File('${tempDir.path}/app.dmg')..writeAsStringSync('dmg');
        final feed = File('${tempDir.path}/appcast.xml')
          ..writeAsStringSync('feed');
        final binDir = Directory('${tempDir.path}/bin')..createSync();
        final log = File('${tempDir.path}/npx.log');
        final npx = File('${binDir.path}/npx')
          ..writeAsStringSync(r'''
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$NPX_LOG"
printf '%s\n' '---' >> "$NPX_LOG"
if [ "$3" = "pages" ] && [ "$4" = "project" ] && [ "$5" = "list" ]; then
  printf '%s\n' '[]'
elif [ "$3" = "pages" ] && [ "$4" = "project" ] && [ "$5" = "create" ]; then
  printf '%s\n' 'A project with this name already exists.' >&2
  exit 1
fi
''');
        Process.runSync('chmod', ['755', npx.path]);

        final result = await runPublisher(
          [dmg.path, feed.path],
          environment: {
            'PATH': '${binDir.path}:${Platform.environment['PATH']}',
            'NPX_LOG': log.path,
            'UPDATE_PUBLISH_TARGET': 'cloudflare_pages',
            'UPDATE_BASE_URL': 'https://misn-updates.pages.dev',
            'CLOUDFLARE_PAGES_PROJECT': 'misn-updates',
            'CLOUDFLARE_PAGES_BRANCH': 'main',
            'CLOUDFLARE_API_TOKEN': 'token',
            'CLOUDFLARE_ACCOUNT_ID': 'account',
          },
        );

        expect(result.exitCode, 0);
        expect(log.readAsStringSync(), contains('project\ncreate'));
        expect(log.readAsStringSync(), contains('pages\ndeploy'));
      },
    );

    test('requires SSH variables only for SSH target', () async {
      final dmg = File('${tempDir.path}/app.dmg')..writeAsStringSync('dmg');
      final feed = File('${tempDir.path}/appcast.xml')
        ..writeAsStringSync('feed');

      final result = await runPublisher(
        [dmg.path, feed.path],
        environment: {
          'UPDATE_PUBLISH_TARGET': 'ssh',
          'UPDATE_BASE_URL': 'https://updates.example.com',
        },
      );

      expect(result.exitCode, 1);
      expect(
        result.stdout,
        contains(
          'UPDATE_SSH_HOST is required when UPDATE_PUBLISH_TARGET=ssh.',
        ),
      );
    });
  });
}
