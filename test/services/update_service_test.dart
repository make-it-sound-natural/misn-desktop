import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService', () {
    late UpdateService updateService;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Create a test channel with the same name
      const channel = MethodChannel('com.makeitsoundnatural/shortcut');

      // Set up mock handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls.add(call);

            switch (call.method) {
              case 'checkForUpdates':
                return {'success': true, 'error': null};
              case 'getAppVersion':
                return {'version': '1.2.3', 'build': '42'};
              case 'getLastUpdateCheck':
                return '2024-01-15T10:30:00Z';
              case 'getAutomaticUpdateChecks':
                return true;
              case 'setAutomaticUpdateChecks':
                return null;
              default:
                return null;
            }
          });

      updateService = UpdateService();
    });

    tearDown(() {
      const channel = MethodChannel('com.makeitsoundnatural/shortcut');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('checkForUpdates calls native method and returns success', () async {
      final result = await updateService.checkForUpdates();

      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'checkForUpdates');
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('checkForUpdates returns error on failure', () async {
      const channel = MethodChannel('com.makeitsoundnatural/shortcut');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkForUpdates') {
              return {'success': false, 'error': 'Network error'};
            }
            return null;
          });

      final result = await updateService.checkForUpdates();

      expect(result.success, isFalse);
      expect(result.error, 'Network error');
    });

    test('getAppVersion returns correct version info', () async {
      final version = await updateService.getAppVersion();

      expect(methodCalls.any((c) => c.method == 'getAppVersion'), isTrue);
      expect(version.version, '1.2.3');
      expect(version.build, '42');
      expect(version.displayString, '1.2.3 (42)');
    });

    test('getLastUpdateCheck returns parsed DateTime', () async {
      final lastCheck = await updateService.getLastUpdateCheck();

      expect(methodCalls.any((c) => c.method == 'getLastUpdateCheck'), isTrue);
      expect(lastCheck, isNotNull);
      expect(lastCheck!.year, 2024);
      expect(lastCheck.month, 1);
      expect(lastCheck.day, 15);
    });

    test('getLastUpdateCheck returns null when never checked', () async {
      const channel = MethodChannel('com.makeitsoundnatural/shortcut');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getLastUpdateCheck') {
              return null;
            }
            return null;
          });

      final lastCheck = await updateService.getLastUpdateCheck();

      expect(lastCheck, isNull);
    });

    test('getAutomaticUpdateChecks returns boolean', () async {
      final result = await updateService.getAutomaticUpdateChecks();

      expect(
        methodCalls.any((c) => c.method == 'getAutomaticUpdateChecks'),
        isTrue,
      );
      expect(result, isTrue);
    });

    test('setAutomaticUpdateChecks sends value to native', () async {
      await updateService.setAutomaticUpdateChecks(enabled: false);

      expect(
        methodCalls.any((c) => c.method == 'setAutomaticUpdateChecks'),
        isTrue,
      );
      final call = methodCalls.firstWhere(
        (c) => c.method == 'setAutomaticUpdateChecks',
      );
      expect(call.arguments, false);
    });
  });

  group('UpdateCheckResult', () {
    test('success result has no error', () {
      const result = UpdateCheckResult(success: true);
      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('failure result has error message', () {
      const result = UpdateCheckResult(success: false, error: 'Test error');
      expect(result.success, isFalse);
      expect(result.error, 'Test error');
    });
  });

  group('AppVersion', () {
    test('displayString formats correctly', () {
      const version = AppVersion(version: '2.0.0', build: '100');
      expect(version.displayString, '2.0.0 (100)');
      expect(version.toString(), '2.0.0 (100)');
    });

    test('releaseChannel infers stable from plain semantic version', () {
      const version = AppVersion(version: '1.2.3', build: '42');

      expect(version.releaseChannel, AppReleaseChannel.stable);
      expect(version.releaseChannelLabel, 'Stable');
    });

    test('releaseChannel infers beta from beta suffix', () {
      const version = AppVersion(version: '1.2.3-beta.1', build: '42');

      expect(version.releaseChannel, AppReleaseChannel.beta);
      expect(version.releaseChannelLabel, 'Beta');
    });

    test('releaseChannel infers nightly from nightly suffix', () {
      const version = AppVersion(
        version: '1.2.3-nightly.20260603.123',
        build: '123',
      );

      expect(version.releaseChannel, AppReleaseChannel.nightly);
      expect(version.releaseChannelLabel, 'Nightly');
    });

    test('releaseChannel is unknown for empty or unknown version', () {
      const empty = AppVersion(version: '', build: '');
      const unknown = AppVersion(version: 'Unknown', build: 'Unknown');

      expect(empty.releaseChannel, AppReleaseChannel.unknown);
      expect(unknown.releaseChannelLabel, 'Unknown');
    });
  });

  group('UpdateCheckState', () {
    test('initial state is idle', () {
      const state = UpdateCheckState.idle;
      expect(state, UpdateCheckState.idle);
    });

    test('all states are defined', () {
      expect(UpdateCheckState.values.length, 4);
      expect(UpdateCheckState.values, contains(UpdateCheckState.idle));
      expect(UpdateCheckState.values, contains(UpdateCheckState.checking));
      expect(UpdateCheckState.values, contains(UpdateCheckState.upToDate));
      expect(UpdateCheckState.values, contains(UpdateCheckState.error));
    });
  });
}
