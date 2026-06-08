import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_manager/release_channel.dart';

void main() {
  group('ReleaseChannel', () {
    test('defines stable channel', () {
      final channel = ReleaseChannelConfig.byId('stable');

      expect(channel.id, 'stable');
      expect(channel.appName, 'Make It Sound Natural');
      expect(channel.bundleId, 'dev.maximtop.makeitsoundnatural');
      expect(channel.feedPath, 'appcast.xml');
      expect(channel.isPrerelease, isFalse);
      expect(channel.requiresMaster, isTrue);
    });

    test('defines beta channel', () {
      final channel = ReleaseChannelConfig.byId('beta');

      expect(channel.id, 'beta');
      expect(channel.appName, 'Make It Sound Natural Beta');
      expect(channel.bundleId, 'dev.maximtop.makeitsoundnatural.beta');
      expect(channel.feedPath, 'appcast-beta.xml');
      expect(channel.isPrerelease, isTrue);
      expect(channel.requiresMaster, isFalse);
    });

    test('defines nightly channel', () {
      final channel = ReleaseChannelConfig.byId('nightly');

      expect(channel.id, 'nightly');
      expect(channel.appName, 'Make It Sound Natural Nightly');
      expect(channel.bundleId, 'dev.maximtop.makeitsoundnatural.nightly');
      expect(channel.feedPath, 'appcast-nightly.xml');
      expect(channel.isPrerelease, isTrue);
      expect(channel.requiresMaster, isFalse);
    });

    test('rejects unknown channel', () {
      expect(
        () => ReleaseChannelConfig.byId('alpha'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
