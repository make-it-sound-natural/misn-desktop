import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/models/appearance_preferences.dart';
import 'package:make_it_sound_natural/screens/home_screen.dart';
import 'package:make_it_sound_natural/services/appearance_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppDefaults.appearancePreferencesKey: jsonEncode({
        AppearancePreferences.schemaVersionField:
            AppDefaults.appearanceSchemaVersion,
        AppearancePreferences.themeModeField: 'system',
        AppearancePreferences.menuFontSizeField: 16,
        AppearancePreferences.editorFontSizeField: 21,
      }),
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          (call) async {
            if (call.method == MethodChannelMethods.getStoredApiKey) {
              return 'openai-key';
            }
            if (call.method ==
                MethodChannelMethods.checkAccessibilityPermissions) {
              return true;
            }
            if (call.method == MethodChannelMethods.getDefaultPrompt) {
              return 'Default prompt';
            }
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

  testWidgets('uses editor font size for rewrite and context inputs', (
    tester,
  ) async {
    final controller = AppearanceController();
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppearanceScope(
        controller: controller,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.where((field) => field.style?.fontSize == 21), hasLength(2));
  });
}
