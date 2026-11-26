import 'package:flutter/material.dart';
import 'package:modychat/screens/onboarding/splash_screen.dart';
import 'package:modychat/services/call_service.dart';
import 'package:modychat/services/image_cache_service.dart';
import 'package:modychat/services/notification_service.dart';
import 'package:modychat/services/presence_manager.dart';
import 'package:modychat/services/settings_service.dart';
import 'package:modychat/services/theme_service.dart';
import 'package:modychat/services/wallpaper_service.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: 'https://lljoixgiomrmhvhyaiva.supabase.co',
    // ignore: deprecated_member_use
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxsam9peGdpb21ybWh2aHlhaXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3OTEyNDMsImV4cCI6MjA4MTM2NzI0M30.Y5801BWzFoy41e3bqAFduFUowDzaIlCfnyfTZGWRRoI',
  );

  // Automatic Presence Listener (online/offline based on app lifecycle)
  AppPresenceManager.instance.initialize();

  // Local Push Notification Service
  NotificationService.instance.initialize(navigatorKey);

  // Incoming call listener (Agora call invitations over Firestore)
  CallService.instance.initialize(navigatorKey);

  // Best-effort cleanup of stale cached profile pictures.
  CachedNetworkImageProvider.purgeOld();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()..loadTheme()),
        ChangeNotifierProvider(
            create: (_) => WallpaperService()..loadWallpaper()),
        ChangeNotifierProvider(
            create: (_) => SettingsService()..loadSettings()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Modychat',
      debugShowCheckedModeBanner: false,
      theme: themeService.currentThemeData,
      darkTheme: themeService.darkTheme,
      themeMode: themeService.themeMode,
      home: const SplashScreen(),
    );
  }
}
