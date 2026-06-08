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

  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = [];
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('requires target profile selection on first launch', (
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
        locale: Locale('en'),
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Target Language'), findsOneWidget);

    await tester.tap(find.text('British English'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('target_profile_selection_confirmed'), isTrue);
    expect(prefs.getString('target_profile_selected_id'), 'britishEnglish');
    expect(find.text('Choose Target Language'), findsNothing);
    expect(
      methodCalls.where(
        (call) => call.method == MethodChannelMethods.setTargetProfile,
      ),
      isNotEmpty,
    );
  });
}
