import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:make_it_sound_natural/constants/app_defaults.dart';
import 'package:make_it_sound_natural/constants/method_channel_methods.dart';
import 'package:make_it_sound_natural/l10n/gen/app_localizations.dart';
import 'package:make_it_sound_natural/screens/settings_screen.dart';
import 'package:make_it_sound_natural/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = [];
    SharedPreferences.setMockInitialValues({
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'americanEnglish',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(MethodChannelMethods.channelName),
          (call) async {
            methodCalls.add(call);
            switch (call.method) {
              case MethodChannelMethods.checkAccessibilityPermissions:
                return true;
              case MethodChannelMethods.getDefaultPrompt:
                return 'Default prompt';
              case 'getAppVersion':
                return {'version': '1.0.0', 'build': '1'};
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

  Widget createTestApp({ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.light(menuFontSize: AppDefaults.menuFontSize),
      darkTheme: AppTheme.dark(menuFontSize: AppDefaults.menuFontSize),
      themeMode: themeMode,
      home: const SettingsScreen(),
    );
  }

  Future<void> openLanguage(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settingsNav-language')));
    await tester.pumpAndSettle();
  }

  testWidgets('selects built-in target profile from searchable picker', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    await openLanguage(tester);

    expect(find.text('Target Language'), findsOneWidget);
    expect(find.text('American English'), findsOneWidget);

    await tester.tap(find.byKey(const Key('targetProfilePickerButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('targetProfileSearchField')),
      'british',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('British English'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('target_profile_selected_id'), 'britishEnglish');
    expect(find.text('British English'), findsOneWidget);
    expect(
      methodCalls.where(
        (call) => call.method == MethodChannelMethods.setTargetProfile,
      ),
      isNotEmpty,
    );
  });

  testWidgets('shows empty state when target profile search has no matches', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    await openLanguage(tester);

    await tester.tap(find.byKey(const Key('targetProfilePickerButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('targetProfileSearchField')),
      'klingon',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching target profiles'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('American English'),
      ),
      findsNothing,
    );
  });

  testWidgets('target profile picker title is readable in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();
    await openLanguage(tester);

    await tester.tap(find.byKey(const Key('targetProfilePickerButton')));
    await tester.pumpAndSettle();

    final titleFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('Choose Target Language'),
    );
    final title = tester.widget<Text>(titleFinder);

    expect(title.style?.color, isNot(AppColors.textPrimary));
    expect(title.style?.color?.computeLuminance(), greaterThan(0.7));
  });

  testWidgets('target profile editor title is readable in dark mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'target_profile_selection_confirmed': true,
      'target_profile_selected_id': 'custom_gopnik',
      'target_profile_custom_profiles': jsonEncode([
        {
          'id': 'custom_gopnik',
          'name': 'гопник',
          'instruction': 'разговаривай на русском языке как гопник',
          'source': 'custom',
        },
      ]),
    });

    await tester.pumpWidget(createTestApp(themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();
    await openLanguage(tester);

    await tester.tap(find.byKey(const Key('editSelectedTargetProfileButton')));
    await tester.pumpAndSettle();

    final titleFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('Edit'),
    );
    final title = tester.widget<Text>(titleFinder);

    expect(title.style?.color, isNot(AppColors.textPrimary));
    expect(title.style?.color?.computeLuminance(), greaterThan(0.7));
  });

  testWidgets('explains required custom profile fields before save', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    await openLanguage(tester);

    await tester.tap(find.byKey(const Key('targetProfilePickerButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('addTargetProfileButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTargetProfileButton')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(2));
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('creates selected custom profile and removes it with fallback', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    await openLanguage(tester);

    await tester.tap(find.byKey(const Key('targetProfilePickerButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('addTargetProfileButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTargetProfileButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('targetProfileNameField')),
      'Canadian English',
    );
    await tester.enterText(
      find.byKey(const Key('targetProfileInstructionField')),
      'Rewrite in natural Canadian English.',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Canadian English'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('target_profile_selected_id'), 'americanEnglish');
    expect(find.text('American English'), findsOneWidget);
    expect(find.text('Target profile reset to default'), findsOneWidget);
  });

  testWidgets('edits selected custom profile and syncs updated instruction', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();
    await openLanguage(tester);

    await tester.tap(find.byKey(const Key('targetProfilePickerButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('addTargetProfileButton')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addTargetProfileButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('targetProfileNameField')),
      'Canadian English',
    );
    await tester.enterText(
      find.byKey(const Key('targetProfileInstructionField')),
      'Rewrite in natural Canadian English.',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editSelectedTargetProfileButton')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Canadian English'),
      ),
      findsOneWidget,
    );
    expect(find.text('Rewrite in natural Canadian English.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('targetProfileNameField')),
      'Canadian Workplace English',
    );
    await tester.enterText(
      find.byKey(const Key('targetProfileInstructionField')),
      'Rewrite in concise Canadian workplace English.',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Canadian Workplace English'), findsOneWidget);
    final targetProfileCalls = methodCalls
        .where((call) => call.method == MethodChannelMethods.setTargetProfile)
        .toList();
    final arguments =
        targetProfileCalls.last.arguments as Map<Object?, Object?>;
    expect(arguments['name'], 'Canadian Workplace English');
    expect(
      arguments['instruction'],
      'Rewrite in concise Canadian workplace English.',
    );
  });
}
