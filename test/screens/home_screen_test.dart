import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHomeScreen(WidgetTester tester) async {
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

      expect(find.text('API key required for corrections'), findsNothing);
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

      expect(find.text('API key required for corrections'), findsOneWidget);
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

      expect(find.text('API key required for corrections'), findsOneWidget);
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
        expect(find.text('Applied'), findsOneWidget);
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

      expect(find.text('Processing...'), findsOneWidget);

      completer.complete(markedVariants);
      await tester.pumpAndSettle();

      expect(find.text('Processing...'), findsNothing);
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
}
