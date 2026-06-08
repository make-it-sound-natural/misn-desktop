import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/constants/shortcut_status.dart';
import 'package:make_it_sound_natural/models/screen_recording_permission_status.dart';
import 'package:make_it_sound_natural/models/screenshot_context_mode.dart';
import 'package:make_it_sound_natural/services/settings_service.dart';
import 'package:make_it_sound_natural/services/shortcut_service.dart';
import 'package:make_it_sound_natural/services/target_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShortcutService Accessibility permissions', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    test('checkAccessibilityPermissions uses no-prompt check method', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              calls.add(call);
              return call.method ==
                  MethodChannelMethods.checkAccessibilityPermissions;
            },
          );

      final granted = await ShortcutService().checkAccessibilityPermissions();

      expect(granted, isTrue);
      expect(
        calls.single.method,
        MethodChannelMethods.checkAccessibilityPermissions,
      );
    });

    test('requestAccessibilityPermission uses prompt request method', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              calls.add(call);
              return call.method ==
                  MethodChannelMethods.requestAccessibilityPermission;
            },
          );

      final granted = await ShortcutService().requestAccessibilityPermission();

      expect(granted, isTrue);
      expect(
        calls.single.method,
        MethodChannelMethods.requestAccessibilityPermission,
      );
    });
  });

  group('ShortcutService Context Storage', () {
    late ShortcutService service;
    late List<MethodCall> methodCalls;

    setUp(() async {
      // Reset shared preferences before each test
      SharedPreferences.setMockInitialValues({});

      // Initialize service
      service = ShortcutService();
      methodCalls = [];

      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (methodCall) async {
              methodCalls.add(methodCall);
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    test('_handleStoreContext replaces context when replace is true', () async {
      // Setup: Store initial context
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_context', 'Old context text');

      // Listen to status stream
      final statusEvents = <ShortcutStatus>[];
      service.statusStream.listen(statusEvents.add);

      // Simulate storeContext call from native with replace=true
      const newText = 'Brand new context';
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(MethodChannelMethods.storeContext, {
                'text': newText,
                'replace': true,
              }),
            ),
            (_) {},
          );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify context was replaced
      final storedContext = prefs.getString('user_context');
      expect(storedContext, equals(newText));

      // Verify status was emitted
      expect(statusEvents, contains(ShortcutStatus.contextReplaced));

      // Verify setContext was called on native side
      final setContextCalls = methodCalls
          .where((call) => call.method == MethodChannelMethods.setContext)
          .toList();
      expect(setContextCalls.length, equals(1));
      expect(setContextCalls.first.arguments, equals(newText));
    });

    test('_handleStoreContext appends context when replace is false', () async {
      // Setup: Store initial context
      final prefs = await SharedPreferences.getInstance();
      const oldContext = 'Existing context';
      await prefs.setString('user_context', oldContext);

      // Listen to status stream
      final statusEvents = <ShortcutStatus>[];
      service.statusStream.listen(statusEvents.add);

      // Simulate storeContext call from native with replace=false
      const additionalText = 'Additional context';
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(MethodChannelMethods.storeContext, {
                'text': additionalText,
                'replace': false,
              }),
            ),
            (_) {},
          );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify context was appended with separator
      final storedContext = prefs.getString('user_context');
      expect(storedContext, equals('$oldContext\n\n---\n\n$additionalText'));

      // Verify status was emitted
      expect(statusEvents, contains(ShortcutStatus.contextAppended));

      // Verify setContext was called on native side with concatenated context
      final setContextCalls = methodCalls
          .where((call) => call.method == MethodChannelMethods.setContext)
          .toList();
      expect(setContextCalls.length, equals(1));
      expect(
        setContextCalls.first.arguments,
        equals('$oldContext\n\n---\n\n$additionalText'),
      );
    });

    test(
      '_handleStoreContext appends to empty context without separator',
      () async {
        // Setup: No initial context
        final prefs = await SharedPreferences.getInstance();

        // Listen to status stream
        final statusEvents = <ShortcutStatus>[];
        service.statusStream.listen(statusEvents.add);

        // Simulate storeContext call from native with replace=false
        const newText = 'First context entry';
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              MethodChannelMethods.channelName,
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall(MethodChannelMethods.storeContext, {
                  'text': newText,
                  'replace': false,
                }),
              ),
              (_) {},
            );

        // Wait for async operations
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify context is just the new text
        // (no separator when appending to empty)
        final storedContext = prefs.getString('user_context');
        expect(storedContext, equals(newText));

        // Verify status was emitted
        expect(statusEvents, contains(ShortcutStatus.contextAppended));
      },
    );

    test('storeContext emits status even when window not visible', () async {
      // This test verifies that the status is always emitted,
      // regardless of window visibility (HomeScreen handles visibility logic)
      final statusEvents = <ShortcutStatus>[];
      service.statusStream.listen(statusEvents.add);

      // Simulate storeContext call
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(MethodChannelMethods.storeContext, {
                'text': 'Test context',
                'replace': true,
              }),
            ),
            (_) {},
          );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify status was emitted
      expect(statusEvents, isNotEmpty);
      expect(statusEvents, contains(ShortcutStatus.contextReplaced));
    });
  });

  group('ShortcutService onError', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async => null,
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    test('onError emits errorStream and ShortcutStatus.error', () async {
      final service = ShortcutService();
      final errors = <String>[];
      final statuses = <ShortcutStatus>[];
      service.errorStream.listen(errors.add);
      service.statusStream.listen(statuses.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onError,
                'Insufficient credits or quota.',
              ),
            ),
            (_) {},
          );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(errors, equals(['Insufficient credits or quota.']));
      expect(statuses, contains(ShortcutStatus.error));
    });

    test(
      'onProviderAuthFailure records settings state and keeps error message',
      () async {
        final service = ShortcutService();
        final errors = <String>[];
        service.errorStream.listen(errors.add);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              MethodChannelMethods.channelName,
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall(MethodChannelMethods.onProviderAuthFailure, {
                  'provider': 'openrouter',
                  'message': 'Invalid API key. Check settings.',
                }),
              ),
              (_) {},
            );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final failure = await SettingsService().getProviderAuthFailure(
          'openrouter',
        );
        expect(failure?.message, 'Invalid API key. Check settings.');
        expect(errors, contains('Invalid API key. Check settings.'));
      },
    );

    test('onSuccess clears active provider auth failure', () async {
      SharedPreferences.setMockInitialValues({'api_provider': 'openrouter'});
      final settings = SettingsService();
      await settings.recordProviderAuthFailure(
        provider: 'openrouter',
        message: 'Invalid API key. Check settings.',
      );

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(MethodChannelMethods.onSuccess),
            ),
            (_) {},
          );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(await settings.getProviderAuthFailure('openrouter'), isNull);
    });
  });

  group('ShortcutService target profile sync', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              methodCalls.add(call);
              return null;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    test('loadAndSyncSettings sends selected target profile', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('target_profile_selected_id', 'britishEnglish');
      await prefs.setBool('target_profile_selection_confirmed', true);

      await ShortcutService().loadAndSyncSettings();

      final calls = methodCalls
          .where((call) => call.method == MethodChannelMethods.setTargetProfile)
          .toList();
      expect(calls, hasLength(1));
      expect(calls.single.arguments, containsPair('id', 'britishEnglish'));
      expect(calls.single.arguments, containsPair('selectionRequired', false));
    });

    test('loadAndSyncSettings sends screenshot context mode', () async {
      final settings = SettingsService();
      await settings.setScreenshotContextMode(ScreenshotContextMode.fullScreen);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              methodCalls.add(call);
              if (call.method ==
                  MethodChannelMethods.checkScreenRecordingPermission) {
                return {'status': 'granted'};
              }
              return null;
            },
          );

      await ShortcutService().loadAndSyncSettings();

      final calls = methodCalls
          .where(
            (call) =>
                call.method == MethodChannelMethods.setScreenshotContextMode,
          )
          .toList();
      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'fullScreen');
    });

    test(
      'loadAndSyncSettings promotes pending mode when permission granted',
      () async {
        SharedPreferences.setMockInitialValues({
          'screenshot_context_mode': 'off',
          'pending_screenshot_context_mode': 'fullScreen',
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                methodCalls.add(call);
                if (call.method ==
                    MethodChannelMethods.checkScreenRecordingPermission) {
                  return {'status': 'granted'};
                }
                return null;
              },
            );

        await ShortcutService().loadAndSyncSettings();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('screenshot_context_mode'), 'fullScreen');
        expect(prefs.getString('pending_screenshot_context_mode'), isNull);
        expect(
          methodCalls.any(
            (call) =>
                call.method == MethodChannelMethods.setScreenshotContextMode &&
                call.arguments == 'fullScreen',
          ),
          isTrue,
        );
      },
    );

    test(
      'loadAndSyncSettings keeps pending mode inactive when permission missing',
      () async {
        SharedPreferences.setMockInitialValues({
          'screenshot_context_mode': 'off',
          'pending_screenshot_context_mode': 'activeApplication',
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                methodCalls.add(call);
                if (call.method ==
                    MethodChannelMethods.checkScreenRecordingPermission) {
                  return {'status': 'manualGrantRequired'};
                }
                return null;
              },
            );

        await ShortcutService().loadAndSyncSettings();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('screenshot_context_mode'), 'off');
        expect(
          prefs.getString('pending_screenshot_context_mode'),
          'activeApplication',
        );
        expect(
          methodCalls.any(
            (call) =>
                call.method == MethodChannelMethods.setScreenshotContextMode &&
                call.arguments == 'off',
          ),
          isTrue,
        );
      },
    );

    test(
      'loadAndSyncSettings preserves active screenshot context when granted',
      () async {
        SharedPreferences.setMockInitialValues({
          'screenshot_context_mode': 'activeApplication',
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                methodCalls.add(call);
                if (call.method ==
                    MethodChannelMethods.checkScreenRecordingPermission) {
                  return {'status': 'granted'};
                }
                return null;
              },
            );

        await ShortcutService().loadAndSyncSettings();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('screenshot_context_mode'), 'activeApplication');
        expect(prefs.getString('pending_screenshot_context_mode'), isNull);
      },
    );

    test('setScreenshotContextMode sends persisted value to native', () async {
      await ShortcutService().setScreenshotContextMode(
        ScreenshotContextMode.activeApplication,
      );

      final calls = methodCalls
          .where(
            (call) =>
                call.method == MethodChannelMethods.setScreenshotContextMode,
          )
          .toList();
      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'activeApplication');
    });

    test('requestScreenRecordingPermission sends mode to native', () async {
      final status = await ShortcutService().requestScreenRecordingPermission(
        ScreenshotContextMode.fullScreen,
      );

      final calls = methodCalls
          .where(
            (call) =>
                call.method ==
                MethodChannelMethods.requestScreenRecordingPermission,
          )
          .toList();
      expect(calls, hasLength(1));
      expect(calls.single.arguments, 'fullScreen');
      expect(status, ScreenRecordingPermissionStatus.manualGrantRequired);
    });

    test('checkScreenRecordingPermission sends mode to native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              methodCalls.add(call);
              if (call.method ==
                  MethodChannelMethods.checkScreenRecordingPermission) {
                return {'status': 'granted'};
              }
              return null;
            },
          );

      final status = await ShortcutService().checkScreenRecordingPermission(
        ScreenshotContextMode.fullScreen,
      );

      expect(status, ScreenRecordingPermissionStatus.granted);
      expect(
        methodCalls.single.method,
        MethodChannelMethods.checkScreenRecordingPermission,
      );
      expect(methodCalls.single.arguments, 'fullScreen');
    });

    test('checkScreenRecordingPermission skips native for off mode', () async {
      final status = await ShortcutService().checkScreenRecordingPermission(
        ScreenshotContextMode.off,
      );

      expect(status, ScreenRecordingPermissionStatus.granted);
      expect(methodCalls, isEmpty);
    });

    test(
      'requestScreenRecordingPermission skips native for off mode',
      () async {
        final status = await ShortcutService().requestScreenRecordingPermission(
          ScreenshotContextMode.off,
        );

        final calls = methodCalls
            .where(
              (call) =>
                  call.method ==
                  MethodChannelMethods.requestScreenRecordingPermission,
            )
            .toList();
        expect(status, ScreenRecordingPermissionStatus.granted);
        expect(calls, isEmpty);
      },
    );

    test('requestScreenRecordingPermission parses granted status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              methodCalls.add(call);
              if (call.method ==
                  MethodChannelMethods.requestScreenRecordingPermission) {
                return {'status': 'granted'};
              }
              return null;
            },
          );

      final status = await ShortcutService().requestScreenRecordingPermission(
        ScreenshotContextMode.fullScreen,
      );

      expect(status, ScreenRecordingPermissionStatus.granted);
    });

    test('requestScreenRecordingPermission parses prompt status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              methodCalls.add(call);
              if (call.method ==
                  MethodChannelMethods.requestScreenRecordingPermission) {
                return {'status': 'promptMayBeVisible'};
              }
              return null;
            },
          );

      final status = await ShortcutService().requestScreenRecordingPermission(
        ScreenshotContextMode.fullScreen,
      );

      expect(status, ScreenRecordingPermissionStatus.promptMayBeVisible);
    });

    test(
      'requestScreenRecordingPermission falls back for unknown status',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                methodCalls.add(call);
                if (call.method ==
                    MethodChannelMethods.requestScreenRecordingPermission) {
                  return {'status': 'future'};
                }
                return null;
              },
            );

        final status = await ShortcutService().requestScreenRecordingPermission(
          ScreenshotContextMode.fullScreen,
        );

        expect(status, ScreenRecordingPermissionStatus.manualGrantRequired);
      },
    );

    test(
      'presentScreenRecordingPermissionGuide returns native result',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                methodCalls.add(call);
                if (call.method ==
                    MethodChannelMethods
                        .presentScreenRecordingPermissionGuide) {
                  return true;
                }
                return null;
              },
            );

        final isGranted = await ShortcutService()
            .presentScreenRecordingPermissionGuide(
              title: 'Title',
              message: 'Message',
              dragInstruction: 'Drag',
              openSettings: 'Open',
              revealInFinder: 'Reveal',
              checkAgain: 'Check',
              cancel: 'Cancel',
              stillMissing: 'Missing',
              debugHint: 'Debug',
              openSettingsOnAppear: true,
            );

        final calls = methodCalls
            .where(
              (call) =>
                  call.method ==
                  MethodChannelMethods.presentScreenRecordingPermissionGuide,
            )
            .toList();
        expect(isGranted, isTrue);
        expect(calls, hasLength(1));
        expect(calls.single.arguments, containsPair('title', 'Title'));
        expect(
          calls.single.arguments,
          containsPair('openSettingsOnAppear', true),
        );
        expect(
          calls.single.arguments,
          containsPair('manualAddRequired', true),
        );
      },
    );

    test(
      'presentScreenRecordingPermissionGuide sends manual add flag',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                methodCalls.add(call);
                if (call.method ==
                    MethodChannelMethods
                        .presentScreenRecordingPermissionGuide) {
                  return true;
                }
                return null;
              },
            );

        await ShortcutService().presentScreenRecordingPermissionGuide(
          title: 'Title',
          message: 'Message',
          dragInstruction: 'Drag',
          openSettings: 'Open',
          revealInFinder: 'Reveal',
          checkAgain: 'Check',
          cancel: 'Cancel',
          stillMissing: 'Missing',
          debugHint: 'Debug',
          manualAddRequired: false,
          openSettingsOnAppear: true,
        );

        final call = methodCalls.singleWhere(
          (call) =>
              call.method ==
              MethodChannelMethods.presentScreenRecordingPermissionGuide,
        );
        expect(call.arguments, containsPair('manualAddRequired', false));
      },
    );

    test('loadAndSyncSettings sends selected custom target profile', () async {
      final targetProfileService = TargetProfileService(
        idFactory: () => 'custom_gopnik',
      );
      final custom = await targetProfileService.createCustomProfile(
        name: 'гопник',
        instruction: 'разговаривай как гопник все на русском языке',
      );
      await targetProfileService.selectProfile(custom.id);

      await ShortcutService().loadAndSyncSettings();

      final calls = methodCalls
          .where((call) => call.method == MethodChannelMethods.setTargetProfile)
          .toList();
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['id'], 'custom_gopnik');
      expect(arguments['name'], 'гопник');
      expect(
        arguments['instruction'],
        'разговаривай как гопник все на русском языке',
      );
      expect(arguments['selectionRequired'], false);
    });

    test(
      'loadAndSyncSettings falls back when confirmed selection is missing',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('target_profile_selection_confirmed', true);

        await ShortcutService().loadAndSyncSettings();

        final calls = methodCalls
            .where(
              (call) => call.method == MethodChannelMethods.setTargetProfile,
            )
            .toList();
        final arguments = calls.single.arguments as Map<Object?, Object?>;
        expect(arguments['id'], TargetProfileService.defaultProfileId);
        expect(arguments['selectionRequired'], false);
      },
    );

    test(
      'loadAndSyncSettings sends selectionRequired when unconfirmed',
      () async {
        await ShortcutService().loadAndSyncSettings();

        final calls = methodCalls
            .where(
              (call) => call.method == MethodChannelMethods.setTargetProfile,
            )
            .toList();
        expect(calls, hasLength(1));
        expect(calls.single.arguments, containsPair('selectionRequired', true));
      },
    );

    test(
      'loadAndSyncSettings does not sync removed custom instruction',
      () async {
        final targetProfileService = TargetProfileService(
          idFactory: () => 'custom_removed',
        );
        const removedInstruction = 'Rewrite in the retired team voice.';
        final custom = await targetProfileService.createCustomProfile(
          name: 'Retired team voice',
          instruction: removedInstruction,
        );
        await targetProfileService.selectProfile(custom.id);
        await targetProfileService.removeCustomProfile(custom.id);

        await ShortcutService().loadAndSyncSettings();

        final calls = methodCalls
            .where(
              (call) => call.method == MethodChannelMethods.setTargetProfile,
            )
            .toList();
        final arguments = calls.single.arguments as Map<Object?, Object?>;
        expect(arguments['id'], TargetProfileService.defaultProfileId);
        expect(arguments['instruction'], isNot(removedInstruction));
        expect(
          arguments['instruction'],
          'Rewrite in natural American English.',
        );
      },
    );
  });
}
