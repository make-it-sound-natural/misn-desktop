import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/home_screen.dart';
import 'package:make_it_sound_natural/widgets/app_inline_banner.dart';
import 'package:make_it_sound_natural/widgets/variant_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHomeScreen(WidgetTester tester) async {
    // The native minimum window is 980x600; the 800x600 test default is a
    // size the app never actually renders at.
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('HomeScreen Context Management', () {
    setUp(() {
      // Reset shared preferences before each test
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
      });

      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.makeitsoundnatural/shortcut'),
            (methodCall) async {
              // Return default values for expected method calls
              switch (methodCall.method) {
                case 'checkAccessibilityPermissions':
                  return false;
                case 'getDefaultPrompt':
                  return 'Default prompt text';
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.makeitsoundnatural/shortcut'),
            null,
          );
    });

    testWidgets('loads context on initialization', (tester) async {
      // Setup: Store context in preferences
      final prefs = await SharedPreferences.getInstance();
      const storedContext = 'This is stored context from preferences';
      await prefs.setString('user_context', storedContext);

      // Build the HomeScreen
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      );

      // Wait for async initialization
      await tester.pumpAndSettle();

      // Verify context field contains the stored context
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Get the context field (second TextField)
      final contextField = textFields.at(1);
      final textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals(storedContext));
    });

    testWidgets('reloads context when app lifecycle changes to resumed', (
      tester,
    ) async {
      // Setup: Initial context
      final prefs = await SharedPreferences.getInstance();
      const initialContext = 'Initial context';
      await prefs.setString('user_context', initialContext);

      // Build the HomeScreen
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial context is loaded
      final textFields = find.byType(TextField);
      final contextField = textFields.at(1);
      var textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals(initialContext));

      // Simulate app going to background and context being updated externally
      // (this happens when cmd+shift+j/l is pressed while app is in background)
      // Valid transition: resumed -> inactive -> hidden -> paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Update context in preferences (simulating native shortcut update)
      const updatedContext = 'Context updated while app was in background';
      await prefs.setString('user_context', updatedContext);

      // Simulate app returning to foreground
      // Valid transition: paused -> hidden -> inactive -> resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify context field now shows the updated context
      textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals(updatedContext));
    });

    testWidgets('context field updates when app resumes after being inactive', (
      tester,
    ) async {
      // Setup: Initial context
      final prefs = await SharedPreferences.getInstance();
      const initialContext = 'Context before inactive';
      await prefs.setString('user_context', initialContext);

      // Build the HomeScreen
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial context
      final textFields = find.byType(TextField);
      final contextField = textFields.at(1);
      var textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals(initialContext));

      // Simulate app going inactive (e.g., during shortcut execution)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Update context while inactive
      const updatedContext = 'Context changed during inactive state';
      await prefs.setString('user_context', updatedContext);

      // Simulate app resuming
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify context was reloaded
      textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals(updatedContext));
    });

    testWidgets('context does not reload when app goes to paused state', (
      tester,
    ) async {
      // This test ensures we only reload on resume, not on pause
      final prefs = await SharedPreferences.getInstance();
      const initialContext = 'Initial state';
      await prefs.setString('user_context', initialContext);

      // Build the HomeScreen
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Update context and go to paused state
      const updatedContext = 'Should not be visible yet';
      await prefs.setString('user_context', updatedContext);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Verify context is still the initial one (not reloaded on pause)
      final textFields = find.byType(TextField);
      final contextField = textFields.at(1);
      final textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals(initialContext));
    });

    testWidgets('handles multiple lifecycle transitions correctly', (
      tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_context', 'Context 1');

      // Build the HomeScreen
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      final contextField = textFields.at(1);

      // Cycle through multiple lifecycle states
      // Forward: resumed -> inactive -> hidden -> paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      await prefs.setString('user_context', 'Context 2');

      // Backward: paused -> hidden -> inactive -> resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify final context is loaded
      final textField = tester.widget<TextField>(contextField);
      expect(textField.controller?.text, equals('Context 2'));
    });
  });

  group('HomeScreen API key banner', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                default:
                  return null;
              }
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

    testWidgets('hides banner when OpenRouter provider has a key', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'openrouter',
        'openai_api_key': '',
        'openrouter_api_key': 'openrouter-key',
      });

      await pumpHomeScreen(tester);

      expect(
        find.text('Provider setup required for corrections'),
        findsNothing,
      );
    });

    testWidgets('shows banner when OpenRouter provider has no key', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'openrouter',
        'openai_api_key': '',
        'openrouter_api_key': '',
      });

      await pumpHomeScreen(tester);

      expect(
        find.text('Provider setup required for corrections'),
        findsOneWidget,
      );
    });

    testWidgets('shows banner when OpenAI provider has no OpenAI key', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'openai',
        'openai_api_key': '',
        'openrouter_api_key': 'openrouter-key',
      });

      await pumpHomeScreen(tester);

      expect(
        find.text('Provider setup required for corrections'),
        findsOneWidget,
      );
    });

    testWidgets('shows banner when custom provider has no visible model', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'tokenguard',
        'llm_custom_providers': [
          jsonEncode({
            'id': 'tokenguard',
            'displayName': 'TokenGuard',
            'baseUrl': 'https://tokenguard.int.agrd.dev/api/v1',
            'isBuiltIn': false,
          }),
        ],
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                case MethodChannelMethods.getStoredCustomProviderApiKey:
                  return 'custom-key';
                default:
                  return null;
              }
            },
          );

      await pumpHomeScreen(tester);

      expect(
        find.text('Provider setup required for corrections'),
        findsOneWidget,
      );
    });
  });

  group('HomeScreen flow state', () {
    const markedVariants = '''
---BALANCED---
Balanced output.
---FORMAL---
Formal output.
''';

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'openrouter',
        'openrouter_api_key': 'openrouter-key',
        'default_variant': 'Formal',
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    testWidgets(
      'native onVariantsGenerated renders variants and selected default',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                switch (call.method) {
                  case MethodChannelMethods.checkAccessibilityPermissions:
                    return false;
                  case MethodChannelMethods.getDefaultPrompt:
                    return 'Default prompt text';
                  default:
                    return null;
                }
              },
            );

        await pumpHomeScreen(tester);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              MethodChannelMethods.channelName,
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall(
                  MethodChannelMethods.onVariantsGenerated,
                  markedVariants,
                ),
              ),
              (_) {},
            );

        await tester.pumpAndSettle();

        expect(find.text('Balanced output.'), findsOneWidget);
        expect(find.text('Formal output.'), findsOneWidget);
        // The preferred tone is pre-selected, not applied: nothing has been
        // pasted back or copied yet, so it must not claim otherwise.
        expect(find.text('Default'), findsOneWidget);
        expect(find.text('Applied'), findsNothing);
      },
    );

    testWidgets(
      'variant headers use Material icons instead of emoji labels',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                switch (call.method) {
                  case MethodChannelMethods.checkAccessibilityPermissions:
                    return false;
                  case MethodChannelMethods.getDefaultPrompt:
                    return 'Default prompt text';
                  default:
                    return null;
                }
              },
            );

        await pumpHomeScreen(tester);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              MethodChannelMethods.channelName,
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall(
                  MethodChannelMethods.onVariantsGenerated,
                  markedVariants,
                ),
              ),
              (_) {},
            );

        await tester.pumpAndSettle();

        expect(find.text('✨'), findsNothing);
        expect(find.text('📧'), findsNothing);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
        expect(find.byIcon(Icons.business_center_outlined), findsOneWidget);
      },
    );

    testWidgets('native onError keeps variants as snackbar-only state', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                default:
                  return null;
              }
            },
          );

      await pumpHomeScreen(tester);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onVariantsGenerated,
                markedVariants,
              ),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();

      const errorMessage = 'Insufficient credits or quota.';
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onError,
                errorMessage,
              ),
            ),
            (_) {},
          );

      await tester.pumpAndSettle();

      expect(find.textContaining(errorMessage), findsOneWidget);
      expect(find.text('Formal output.'), findsOneWidget);
      expect(find.text('Status'), findsNothing);
    });

    testWidgets('manual processing toggles Process button state', (
      tester,
    ) async {
      final completer = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                case MethodChannelMethods.generateVariants:
                  return completer.future;
                default:
                  return null;
              }
            },
          );

      await pumpHomeScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Original text');
      await tester.pump();

      await tester.tap(find.text('Process'));
      await tester.pump();

      expect(find.text('Processing…'), findsOneWidget);

      completer.complete(markedVariants);
      await tester.pumpAndSettle();

      expect(find.text('Processing…'), findsNothing);
      expect(find.text('Formal output.'), findsOneWidget);
    });

    testWidgets(
      'source clear action is compact tertiary and Process remains primary',
      (
        tester,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(MethodChannelMethods.channelName),
              (call) async {
                switch (call.method) {
                  case MethodChannelMethods.checkAccessibilityPermissions:
                    return false;
                  case MethodChannelMethods.getDefaultPrompt:
                    return 'Default prompt text';
                  default:
                    return null;
                }
              },
            );

        await pumpHomeScreen(tester);
        await tester.enterText(find.byType(TextField).first, 'Original text');
        await tester.pump();

        expect(find.text('Process'), findsOneWidget);
        final clearIcon = find.byIcon(Icons.close_rounded);
        expect(clearIcon, findsWidgets);
        expect(find.text('Clear'), findsNothing);

        final clearButtonFinder = find.ancestor(
          of: clearIcon.first,
          matching: find.byType(IconButton),
        );
        final clearButton = tester.widget<IconButton>(clearButtonFinder.first);
        expect(
          clearButton.style?.backgroundColor?.resolve(<WidgetState>{}),
          isNot(Colors.transparent),
        );
        expect(
          clearButton.style?.shape?.resolve(<WidgetState>{}),
          isA<RoundedRectangleBorder>(),
        );
      },
    );
  });

  group('HomeScreen LLM error SnackBar (errorStream)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                default:
                  return null;
              }
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

    testWidgets(
      'shows long-lived dismissible SnackBar when native sends onError',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(),
          ),
        );
        await tester.pumpAndSettle();

        const errorMessage = 'Insufficient credits or quota.';
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              MethodChannelMethods.channelName,
              const StandardMethodCodec().encodeMethodCall(
                const MethodCall(
                  MethodChannelMethods.onError,
                  errorMessage,
                ),
              ),
              (_) {},
            );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.textContaining(errorMessage), findsOneWidget);
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.showCloseIcon, isTrue);
        expect(snackBar.closeIconColor, equals(Colors.white));
        expect(
          snackBar.duration,
          equals(const Duration(seconds: 120)),
        );
      },
    );

    testWidgets(
      'shows provider auth failure from typed event in rewrite flow',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(),
          ),
        );
        await tester.pumpAndSettle();

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

        await tester.pumpAndSettle();

        expect(
          find.textContaining('Invalid API key. Check settings.'),
          findsOneWidget,
        );
      },
    );
  });

  group('HomeScreen cancel and apply feedback', () {
    const markedVariants = '''
---BALANCED---
Balanced output.
---FORMAL---
Formal output.
''';

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'openrouter',
        'openrouter_api_key': 'openrouter-key',
        'default_variant': 'Balanced',
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    testWidgets('Escape during processing cancels the run and toasts', (
      tester,
    ) async {
      final completer = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                case MethodChannelMethods.generateVariants:
                  return completer.future;
                default:
                  return null;
              }
            },
          );

      await pumpHomeScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Original text');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rewrite-process')));
      await tester.pump();

      expect(find.text('Processing…'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.text('Processing cancelled'), findsOneWidget);
      expect(find.text('Processing…'), findsNothing);

      // A late reply from the cancelled run must be discarded. The payload is
      // deliberately distinct: ShortcutService is a singleton and may hold
      // variants cached by an earlier test in this file.
      completer.complete('''
---BALANCED---
Late output from a cancelled run.
''');
      await tester.pumpAndSettle();
      expect(find.text('Late output from a cancelled run.'), findsNothing);
    });

    testWidgets('applying a variant shows one merged toast', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                case MethodChannelMethods.replaceTextInOriginalApp:
                  // The native side reports it replaced the text in place.
                  return true;
                default:
                  return null;
              }
            },
          );

      await pumpHomeScreen(tester);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onVariantsGenerated,
                markedVariants,
              ),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Apply').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('applied — copied to clipboard'),
        findsOneWidget,
      );
      expect(find.text('Copied to clipboard'), findsNothing);
      expect(find.text('Applied'), findsOneWidget);
    });

    testWidgets('claims only a copy when the replacement was declined', (
      tester,
    ) async {
      // The native side declines when our earlier paste is no longer at the
      // caret; saying "applied" then would be a lie.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async => switch (call.method) {
              MethodChannelMethods.checkAccessibilityPermissions => false,
              MethodChannelMethods.getDefaultPrompt => 'Default prompt text',
              MethodChannelMethods.replaceTextInOriginalApp => false,
              _ => null,
            },
          );

      await pumpHomeScreen(tester);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onVariantsGenerated,
                markedVariants,
              ),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Apply').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply').first);
      await tester.pumpAndSettle();

      expect(find.text('Copied to clipboard'), findsOneWidget);
      expect(
        find.textContaining('applied — copied to clipboard'),
        findsNothing,
      );
      // The card must not claim an apply the native side declined — the toast
      // and the badge have to tell the same story.
      expect(find.text('Applied'), findsNothing);
    });

    testWidgets('the pre-selected variant can still be applied', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async => switch (call.method) {
              MethodChannelMethods.checkAccessibilityPermissions => false,
              MethodChannelMethods.getDefaultPrompt => 'Default prompt text',
              // The card only claims "Applied" for a replacement the native
              // side confirms, so this run has to report one.
              MethodChannelMethods.replaceTextInOriginalApp => true,
              _ => null,
            },
          );

      await pumpHomeScreen(tester);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onVariantsGenerated,
                markedVariants,
              ),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();

      // Regression guard: the default tone used to be the one card the user
      // could not click, which made the likeliest choice unreachable.
      final defaultCard = find.ancestor(
        of: find.text('Default'),
        matching: find.byType(VariantCard),
      );
      expect(defaultCard, findsOneWidget);
      await tester.ensureVisible(defaultCard);
      await tester.pumpAndSettle();
      await tester.tap(defaultCard);
      await tester.pumpAndSettle();

      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Default'), findsNothing);
    });
  });

  group('HomeScreen auth failure', () {
    /// Seeds the record the native side writes when a provider rejects a key.
    void seedAuthFailure({required bool inThePast}) {
      final at = inThePast
          ? DateTime.now().toUtc().subtract(const Duration(hours: 1))
          : DateTime.now().toUtc().add(const Duration(seconds: 5));
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
        'api_provider': 'openrouter',
        'provider_auth_failure_openrouter': jsonEncode({
          'provider': 'openrouter',
          'message': 'Invalid API key',
          'occurredAt': at.toIso8601String(),
        }),
      });
    }

    void mockFailingRun() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                case MethodChannelMethods.generateVariants:
                  // What the native bridge now reports for a rejected key.
                  throw PlatformException(
                    code: 'API_ERROR',
                    message: 'Invalid API key',
                  );
                default:
                  return null;
              }
            },
          );
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    testWidgets('a rejected key shows the banner instead of variants', (
      tester,
    ) async {
      seedAuthFailure(inThePast: false);
      mockFailingRun();

      await pumpHomeScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Original text');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rewrite-process')));
      await tester.pumpAndSettle();

      // Scoped by title: the "no API key yet" banner is also on screen, and
      // both are AppInlineBanner now.
      final authBanner = find.ancestor(
        of: find.text('The provider rejected your API key.'),
        matching: find.byType(AppInlineBanner),
      );
      expect(authBanner, findsOneWidget);
      expect(
        find.text('Check the key for OpenRouter, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Check API key'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(VariantCard), findsNothing);
    });

    testWidgets('Retry reruns the same text', (tester) async {
      seedAuthFailure(inThePast: false);
      var generateCalls = 0;
      final seen = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              switch (call.method) {
                case MethodChannelMethods.checkAccessibilityPermissions:
                  return false;
                case MethodChannelMethods.getDefaultPrompt:
                  return 'Default prompt text';
                case MethodChannelMethods.generateVariants:
                  generateCalls += 1;
                  seen.add(call.arguments as String);
                  throw PlatformException(
                    code: 'API_ERROR',
                    message: 'Invalid API key',
                  );
                default:
                  return null;
              }
            },
          );

      await pumpHomeScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Original text');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rewrite-process')));
      await tester.pumpAndSettle();
      expect(generateCalls, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(generateCalls, 2);
      expect(seen, ['Original text', 'Original text']);
    });

    testWidgets('a failure older than the run falls back to the toast', (
      tester,
    ) async {
      // The banner must only speak for the run the user just started.
      seedAuthFailure(inThePast: true);
      mockFailingRun();

      await pumpHomeScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Original text');
      await tester.pump();
      await tester.tap(find.byKey(const Key('rewrite-process')));
      await tester.pumpAndSettle();

      expect(find.text('The provider rejected your API key.'), findsNothing);
      expect(find.textContaining('Invalid API key'), findsWidgets);
    });
  });

  group('HomeScreen variant card interactions', () {
    const markedVariants =
        '[BALANCED]Balanced text[/BALANCED][FORMAL]Formal text[/FORMAL]';

    Future<void> showVariants(WidgetTester tester) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onVariantsGenerated,
                markedVariants,
              ),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    testWidgets('copy does not apply the variant', (tester) async {
      // The whole card is an InkWell(onTap: onApply) and the SelectableText
      // carries onApply too, so the copy button has to absorb its own tap.
      // If it stops doing that, copying would paste into another app.
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
      });
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              calls.add(call.method);
              return switch (call.method) {
                MethodChannelMethods.checkAccessibilityPermissions => false,
                MethodChannelMethods.getDefaultPrompt => 'Default prompt text',
                _ => null,
              };
            },
          );

      await pumpHomeScreen(tester);
      await showVariants(tester);

      final copyButton = find
          .descendant(
            of: find.byType(VariantCard),
            matching: find.byIcon(Icons.copy_rounded),
          )
          .first;
      await tester.ensureVisible(copyButton);
      await tester.pumpAndSettle();
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(find.text('Copied to clipboard'), findsOneWidget);
      expect(find.text('Applied'), findsNothing);
      expect(
        calls,
        isNot(contains(MethodChannelMethods.replaceTextInOriginalApp)),
      );
    });

    testWidgets('a second Process press cancels the run', (tester) async {
      // The button stays enabled while running so it can act as Cancel.
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
      });
      final completer = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async => switch (call.method) {
              MethodChannelMethods.checkAccessibilityPermissions => false,
              MethodChannelMethods.getDefaultPrompt => 'Default prompt text',
              MethodChannelMethods.generateVariants => completer.future,
              _ => null,
            },
          );

      await pumpHomeScreen(tester);
      await tester.enterText(find.byType(TextField).first, 'Original text');
      await tester.pump();
      // The source panel scrolls its own content now, so make sure the button
      // is actually on screen before pressing it.
      await tester.ensureVisible(find.byKey(const Key('rewrite-process')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rewrite-process')));
      await tester.pump();

      expect(find.text('Processing…'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('rewrite-process')),
      );
      expect(button.onPressed, isNotNull, reason: 'must stay pressable');

      // pump, not pumpAndSettle: the running spinner never settles.
      await tester.ensureVisible(find.byKey(const Key('rewrite-process')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rewrite-process')));
      await tester.pump();

      expect(find.text('Processing cancelled'), findsOneWidget);
      expect(find.text('Processing…'), findsNothing);

      completer.complete('[CASUAL]Late reply must be discarded[/CASUAL]');
      await tester.pumpAndSettle();
      expect(find.text('Late reply must be discarded'), findsNothing);
    });
  });

  group('HomeScreen auto-apply tone', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            null,
          );
    });

    testWidgets('the picker writes what a run reads back', (tester) async {
      // The dropdown writes CorrectionVariantKind.wireValue while a run
      // resolves the preferred index by parsing the label. If the two ever
      // disagree, the chosen tone silently stops being pre-selected.
      SharedPreferences.setMockInitialValues({
        'target_profile_selection_confirmed': true,
        'target_profile_selected_id': 'americanEnglish',
      });
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(MethodChannelMethods.channelName),
            (call) async {
              calls.add(call);
              return switch (call.method) {
                MethodChannelMethods.checkAccessibilityPermissions => false,
                MethodChannelMethods.getDefaultPrompt => 'Default prompt text',
                _ => null,
              };
            },
          );

      await pumpHomeScreen(tester);

      await tester.ensureVisible(find.byKey(const Key('rewrite-auto-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rewrite-auto-apply')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Formal').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('default_variant'), 'Formal');
      expect(
        calls.where((c) => c.method == MethodChannelMethods.setDefaultVariant),
        isNotEmpty,
      );

      // Close the loop: a run must now pre-select that tone.
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            MethodChannelMethods.channelName,
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall(
                MethodChannelMethods.onVariantsGenerated,
                '[BALANCED]Balanced text[/BALANCED][FORMAL]Formal text[/FORMAL]',
              ),
            ),
            (_) {},
          );
      await tester.pumpAndSettle();

      final defaultCard = find.ancestor(
        of: find.text('Default'),
        matching: find.byType(VariantCard),
      );
      expect(defaultCard, findsOneWidget);
      expect(
        tester.widget<VariantCard>(defaultCard).name,
        'Formal',
        reason: 'the tone the picker wrote must be the one a run pre-selects',
      );
    });
  });
}
