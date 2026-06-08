import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GitHub Actions test workflow', () {
    late String workflow;

    setUpAll(() {
      workflow = File('.github/workflows/test.yml').readAsStringSync();
    });

    test('cancels outdated runs for the same ref', () {
      expect(workflow, contains('concurrency:'));
      expect(
        workflow,
        contains(r'group: test-${{ github.workflow }}-${{ github.ref }}'),
      );
      expect(workflow, contains('cancel-in-progress: true'));
    });

    test('skips docs and spec only changes', () {
      expect(workflow, contains('paths-ignore:'));
      expect(workflow, contains("- '**/*.md'"));
      expect(workflow, contains("- 'docs/**'"));
      expect(workflow, contains("- '.sdd/**'"));
      expect(workflow, contains("- 'specs/**'"));
      expect(workflow, isNot(contains("- '.github/**'")));
    });

    test('runs Dart checks on Ubuntu', () {
      expect(workflow, contains('dart:'));
      expect(workflow, contains('name: Dart format, analyze, and tests'));
      expect(workflow, contains('runs-on: ubuntu-latest'));
      expect(workflow, contains('make lint-flutter'));
      expect(workflow, contains('make test-flutter'));
    });

    test('keeps native checks on macOS without full make test', () {
      expect(workflow, contains('native:'));
      expect(workflow, contains('name: Native macOS checks'));
      expect(workflow, contains('needs: dart'));
      expect(workflow, contains('runs-on: macos-latest'));
      expect(workflow, contains('make lint-swift'));
      expect(workflow, contains('make test-macos'));
      expect(workflow, isNot(contains('brew install swiftlint')));
      expect(
        RegExp(r'^\s*run:\s*make test\s*$', multiLine: true).hasMatch(workflow),
        isFalse,
      );
    });
  });

  group('GitHub Actions release workflows', () {
    const workflowPaths = [
      '.github/workflows/release-stable.yml',
      '.github/workflows/release-beta.yml',
      '.github/workflows/release-nightly.yml',
    ];

    for (final path in workflowPaths) {
      test('$path uses Sparkle 2 ed-key-file signing API', () {
        final workflow = File(path).readAsStringSync();

        expect(
          workflow,
          contains(r'--ed-key-file /tmp/sparkle_private_key "$DMG_PATH"'),
        );
        expect(
          workflow,
          isNot(
            contains(
              r'SIGN_OUTPUT=$("$SPARKLE_SIGN_UPDATE" "$DMG_PATH" '
              '/tmp/sparkle_private_key)',
            ),
          ),
        );
        expect(
          workflow,
          contains('Sparkle signature generation failed.'),
        );
      });

      test('$path signs and notarizes DMG before Sparkle signature', () {
        final workflow = File(path).readAsStringSync();

        expect(
          'Import code signing certificates'.allMatches(workflow).length,
          greaterThanOrEqualTo(2),
          reason:
              'release job must import the signing certificate for DMG signing',
        );
        expect(
          workflow,
          contains(
            r'codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG_PATH"',
          ),
        );
        expect(
          workflow,
          contains(r'bash scripts/notarize_macos_artifact.sh "$DMG_PATH"'),
        );
        expect(workflow, contains(r'xcrun stapler staple "$DMG_PATH"'));

        final notarizeIndex = workflow.indexOf('Sign and notarize DMG');
        final sparkleIndex = workflow.indexOf('Set up Sparkle private key');
        expect(notarizeIndex, isNonNegative);
        expect(sparkleIndex, isNonNegative);
        expect(notarizeIndex, lessThan(sparkleIndex));
        expect(workflow, contains('security delete-keychain build.keychain'));
      });

      test('$path uploads a browser-safe app ZIP', () {
        final workflow = File(path).readAsStringSync();

        expect(workflow, contains('Create browser download ZIP'));
        expect(
          workflow,
          contains('ditto -c -k --sequesterRsrc --keepParent'),
        );
        expect(workflow, contains(r'${{ steps.app_zip.outputs.zip_path }}'));
      });

      test('$path supports selectable external Sparkle update hosting', () {
        final workflow = File(path).readAsStringSync();

        expect(workflow, contains('UPDATE_BASE_URL:'));
        expect(workflow, contains('UPDATE_PUBLISH_TARGET:'));
        expect(workflow, contains('CLOUDFLARE_PAGES_PROJECT:'));
        expect(workflow, contains('CLOUDFLARE_PAGES_BRANCH:'));
        expect(
          workflow,
          contains(r'--update-base-url "${{ env.UPDATE_BASE_URL }}"'),
        );
        expect(workflow, contains('Publish Sparkle update files'));
        expect(
          workflow,
          contains('bash scripts/publish_update_files.sh'),
        );
        expect(workflow, contains('CLOUDFLARE_API_TOKEN'));
        expect(workflow, contains('CLOUDFLARE_ACCOUNT_ID'));
        expect(workflow, contains('UPDATE_SSH_PRIVATE_KEY'));
      });
    }

    test('nightly workflow uses run number for Sparkle comparison version', () {
      final workflow = File(
        '.github/workflows/release-nightly.yml',
      ).readAsStringSync();

      expect(workflow, contains(r'bundle_version=${{ github.run_number }}'));
      expect(workflow, contains('--bundle-version'));
      expect(
        workflow,
        contains(r'--sparkle-version "${{ github.run_number }}"'),
      );
    });
  });

  group('Fastlane release packaging', () {
    test('uses HFS+ for hdiutil fallback DMGs', () {
      final fastfile = File('macos/fastlane/Fastfile').readAsStringSync();

      expect(fastfile, contains('-fs HFS+'));
    });
  });
}
