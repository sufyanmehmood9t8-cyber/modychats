import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperService extends ChangeNotifier {
  static const String _prefKeyName = 'chat_wallpaper_name';
  static const String _prefKeyType = 'chat_wallpaper_type';
  static const String _prefKeyPath = 'chat_wallpaper_path';

  String _wallpaperName = 'Classic Doodle';
  WallpaperType _wallpaperType = WallpaperType.classicDoodle;
  String _wallpaperPath = '';

  String get wallpaperName => _wallpaperName;
  WallpaperType get wallpaperType => _wallpaperType;
  String get wallpaperPath => _wallpaperPath;

  Future<void> loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    _wallpaperName = prefs.getString(_prefKeyName) ?? 'Classic Doodle';
    final typeStr = prefs.getString(_prefKeyType);
    _wallpaperType = WallpaperType.values.firstWhere(
      (e) => e.toString() == (typeStr ?? WallpaperType.classicDoodle.toString()),
      orElse: () => WallpaperType.classicDoodle,
    );
    _wallpaperPath = prefs.getString(_prefKeyPath) ?? '';
    notifyListeners();
  }

  Future<void> setClassicDoodle() async {
    _wallpaperName = 'Classic Doodle';
    _wallpaperType = WallpaperType.classicDoodle;
    _wallpaperPath = '';
    await _save();
    notifyListeners();
  }

  Future<void> setModyChatDefault() async {
    _wallpaperName = 'ModyChat Default';
    _wallpaperType = WallpaperType.modychatDefault;
    _wallpaperPath = '';
    await _save();
    notifyListeners();
  }

  Future<void> setGalleryImage(String imagePath) async {
    _wallpaperName = 'Gallery';
    _wallpaperType = WallpaperType.gallery;
    _wallpaperPath = imagePath;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyName, _wallpaperName);
    await prefs.setString(_prefKeyType, _wallpaperType.toString());
    await prefs.setString(_prefKeyPath, _wallpaperPath);
  }

  BoxDecoration? getChatBackgroundDecoration() {
    if (_wallpaperType == WallpaperType.gallery && _wallpaperPath.isNotEmpty) {
      final file = File(_wallpaperPath);
      if (file.existsSync()) {
        return BoxDecoration(
          image: DecorationImage(
            image: FileImage(file),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.25),
              BlendMode.darken,
            ),
          ),
        );
      }
      // Fallback if image missing
      _wallpaperType = WallpaperType.modychatDefault;
      _wallpaperName = 'ModyChat Default';
      notifyListeners();
    }

    if (_wallpaperType == WallpaperType.modychatDefault) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4F5F9), Color(0xFFEDEEF3)],
        ),
      );
    }

    // Classic Doodle (default)
    return const BoxDecoration(
      color: Color(0xFFFDFBF7),
    );
  }
}

enum WallpaperType {
  classicDoodle,
  modychatDefault,
  gallery,
}
