// Temporary verification harness for the new ModyChat splash screen.
// Renders SplashScreen at several real device sizes, pumps the entrance
// animations, and fails loudly on asset load errors or RenderFlex overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:modychat/screens/onboarding/splash_screen.dart';

void main() {
  // SharedPreferences is read by the splash's startup timer.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final sizes = <String, Size>{
    'small_android': Size(360, 640),
    'tall_android': Size(412, 915),
    'very_short': Size(320, 480),
    'large_android': Size(480, 1067),
  };

  for (final entry in sizes.entries) {
    testWidgets('splash renders on ${entry.key} ${entry.value}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SplashScreen(),
        ),
      );

      // Asset resolution happens on the first frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Any missing asset surfaces as a FlutterError here.
      expect(
        tester.takeException(),
        isNull,
        reason: 'asset/shader error on ${entry.key}',
      );

      // Walk the entrance timeline. Stop at 1.9s — before the splash's 2.8s
      // navigation timer, which would mount a Firebase-dependent screen.
      for (var t = 100; t <= 1900; t += 100) {
        await tester.pump(Duration(milliseconds: 100));
        expect(
          tester.takeException(),
          isNull,
          reason: 'exception at ${t}ms on ${entry.key}',
        );
      }

      // All required copy is present.
      expect(find.text('Mody'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Simple. Secure. Real-Time Chat.'), findsOneWidget);
      expect(find.text('from ModyTech'), findsOneWidget);

      // "Chat" uses a real gradient shader, not a solid colour.
      expect(find.byType(ShaderMask), findsOneWidget);

      // Gradient ring loader is a CustomPaint, not CircularProgressIndicator.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // The asset image is really being used (not a fallback icon).
      expect(find.byType(Image), findsWidgets);

      // Old design must be gone.
      expect(find.byIcon(Icons.chat_bubble_rounded), findsNothing);
      expect(find.text('Modychat'), findsNothing);
    });
  }
}
