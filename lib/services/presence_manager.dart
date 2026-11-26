import 'package:flutter/material.dart';
import 'firebase_service.dart';

/// Manages automatic online/offline user presence using Flutter's AppLifecycleState.
///
/// When the app is resumed (active in foreground), presence is set to online.
/// When the app is paused, inactive, or detached (backgrounded/closed), presence is set to offline.
class AppPresenceManager with WidgetsBindingObserver {
  static final AppPresenceManager instance = AppPresenceManager._();
  AppPresenceManager._();

  final FirebaseService _firebaseService = FirebaseService();
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    _firebaseService.setUserPresence(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _firebaseService.setUserPresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _firebaseService.setUserPresence(false);
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firebaseService.setUserPresence(false);
  }
}
