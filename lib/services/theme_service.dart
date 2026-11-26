import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

enum AppThemeOption { light, dark, modychat }

class ThemeService extends ChangeNotifier {
  static const String _prefKey = 'app_theme_option';

  AppThemeOption _currentTheme = AppThemeOption.modychat;

  AppThemeOption get currentTheme => _currentTheme;

  String get themeName {
    switch (_currentTheme) {
      case AppThemeOption.light:
        return 'Light';
      case AppThemeOption.dark:
        return 'Dark';
      case AppThemeOption.modychat:
        return 'ModyChat';
    }
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefKey);
    if (value != null) {
      for (final option in AppThemeOption.values) {
        if (option.toString() == value) {
          _currentTheme = option;
          notifyListeners();
          return;
        }
      }
    }
    _currentTheme = AppThemeOption.modychat;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeOption option) async {
    if (_currentTheme == option) return;
    _currentTheme = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, option.toString());
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppThemeOption.light:
        return ThemeMode.light;
      case AppThemeOption.dark:
        return ThemeMode.dark;
      case AppThemeOption.modychat:
        return ThemeMode.light;
    }
  }

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkNavy,
        primary: AppColors.darkNavy,
        secondary: AppColors.accentCoral,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkNavy,
        primary: AppColors.accentCoral,
        secondary: AppColors.accentCoral,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  ThemeData get modychatTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bodyBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.darkNavy,
        primary: AppColors.darkNavy,
        secondary: AppColors.accentCoral,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  ThemeData get currentThemeData {
    switch (_currentTheme) {
      case AppThemeOption.light:
        return lightTheme;
      case AppThemeOption.dark:
        return darkTheme;
      case AppThemeOption.modychat:
        return modychatTheme;
    }
  }
}
