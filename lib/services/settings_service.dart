import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontSize { small, medium, large }

class SettingsService extends ChangeNotifier {
  static const String _keyFontSize = 'setting_font_size';
  static const String _keySecNotif = 'setting_sec_notif';
  static const String _keyTwoStep = 'setting_two_step';

  static const String _keyLastSeen = 'setting_privacy_last_seen';
  static const String _keyProfilePhoto = 'setting_privacy_profile_photo';
  static const String _keyAbout = 'setting_privacy_about';
  static const String _keyReadReceipts = 'setting_privacy_read_receipts';
  static const String _keyDisappearingTimer = 'setting_privacy_disappearing_timer';

  static const String _keyConvTones = 'setting_notif_conv_tones';
  static const String _keyMsgTone = 'setting_notif_msg_tone';
  static const String _keyVibration = 'setting_notif_vibration';
  static const String _keyHighPriority = 'setting_notif_high_priority';
  static const String _keyGroupTone = 'setting_notif_group_tone';
  static const String _keyCallRingtone = 'setting_notif_call_ringtone';

  static const String _keyAutoPhotosMobile = 'setting_auto_photos_mobile';
  static const String _keyAutoAudioMobile = 'setting_auto_audio_mobile';
  static const String _keyAutoVideosMobile = 'setting_auto_videos_mobile';
  static const String _keyAutoDocsMobile = 'setting_auto_docs_mobile';
  static const String _keyUseLessDataCalls = 'setting_use_less_data_calls';

  AppFontSize _fontSize = AppFontSize.medium;
  bool _securityNotifications = true;
  bool _twoStepVerification = false;

  String _lastSeenOption = 'Everyone';
  String _profilePhotoOption = 'Everyone';
  String _aboutOption = 'Everyone';
  bool _readReceipts = true;
  String _disappearingMessagesTimer = 'Off';

  bool _conversationTones = true;
  String _messageTone = 'Default (Chime)';
  String _vibrationLength = 'Default';
  bool _highPriorityNotifications = true;
  String _groupTone = 'Default (Pop)';
  String _callRingtone = 'Modychat Breeze';

  bool _autoPhotosMobile = true;
  bool _autoAudioMobile = true;
  bool _autoVideosMobile = false;
  bool _autoDocsMobile = true;
  bool _useLessDataCalls = false;

  AppFontSize get fontSize => _fontSize;
  double get fontSizeMultiplier {
    switch (_fontSize) {
      case AppFontSize.small:
        return 0.88;
      case AppFontSize.medium:
        return 1.0;
      case AppFontSize.large:
        return 1.15;
    }
  }

  String get fontSizeName {
    switch (_fontSize) {
      case AppFontSize.small:
        return 'Small';
      case AppFontSize.medium:
        return 'Medium';
      case AppFontSize.large:
        return 'Large';
    }
  }

  bool get securityNotifications => _securityNotifications;
  bool get twoStepVerification => _twoStepVerification;

  String get lastSeenOption => _lastSeenOption;
  String get profilePhotoOption => _profilePhotoOption;
  String get aboutOption => _aboutOption;
  bool get readReceipts => _readReceipts;
  String get disappearingMessagesTimer => _disappearingMessagesTimer;

  bool get conversationTones => _conversationTones;
  String get messageTone => _messageTone;
  String get vibrationLength => _vibrationLength;
  bool get highPriorityNotifications => _highPriorityNotifications;
  String get groupTone => _groupTone;
  String get callRingtone => _callRingtone;

  bool get autoPhotosMobile => _autoPhotosMobile;
  bool get autoAudioMobile => _autoAudioMobile;
  bool get autoVideosMobile => _autoVideosMobile;
  bool get autoDocsMobile => _autoDocsMobile;
  bool get autoDocumentsMobile => _autoDocsMobile;
  bool get useLessDataCalls => _useLessDataCalls;
  bool get useLessDataForCalls => _useLessDataCalls;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final fontStr = prefs.getString(_keyFontSize);
    if (fontStr != null) {
      _fontSize = AppFontSize.values.firstWhere(
        (e) => e.toString() == fontStr,
        orElse: () => AppFontSize.medium,
      );
    }

    _securityNotifications = prefs.getBool(_keySecNotif) ?? true;
    _twoStepVerification = prefs.getBool(_keyTwoStep) ?? false;

    _lastSeenOption = prefs.getString(_keyLastSeen) ?? 'Everyone';
    _profilePhotoOption = prefs.getString(_keyProfilePhoto) ?? 'Everyone';
    _aboutOption = prefs.getString(_keyAbout) ?? 'Everyone';
    _readReceipts = prefs.getBool(_keyReadReceipts) ?? true;
    _disappearingMessagesTimer = prefs.getString(_keyDisappearingTimer) ?? 'Off';

    _conversationTones = prefs.getBool(_keyConvTones) ?? true;
    _messageTone = prefs.getString(_keyMsgTone) ?? 'Default (Chime)';
    _vibrationLength = prefs.getString(_keyVibration) ?? 'Default';
    _highPriorityNotifications = prefs.getBool(_keyHighPriority) ?? true;
    _groupTone = prefs.getString(_keyGroupTone) ?? 'Default (Pop)';
    _callRingtone = prefs.getString(_keyCallRingtone) ?? 'Modychat Breeze';

    _autoPhotosMobile = prefs.getBool(_keyAutoPhotosMobile) ?? true;
    _autoAudioMobile = prefs.getBool(_keyAutoAudioMobile) ?? true;
    _autoVideosMobile = prefs.getBool(_keyAutoVideosMobile) ?? false;
    _autoDocsMobile = prefs.getBool(_keyAutoDocsMobile) ?? true;
    _useLessDataCalls = prefs.getBool(_keyUseLessDataCalls) ?? false;

    notifyListeners();
  }

  Future<void> setFontSize(AppFontSize size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontSize, size.toString());
  }

  Future<void> setSecurityNotifications(bool val) async {
    _securityNotifications = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySecNotif, val);
  }

  Future<void> setTwoStepVerification(bool val) async {
    _twoStepVerification = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTwoStep, val);
  }

  Future<void> setLastSeenOption(String val) async {
    _lastSeenOption = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSeen, val);
  }

  Future<void> setProfilePhotoOption(String val) async {
    _profilePhotoOption = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfilePhoto, val);
  }

  Future<void> setAboutOption(String val) async {
    _aboutOption = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAbout, val);
  }

  Future<void> setReadReceipts(bool val) async {
    _readReceipts = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReadReceipts, val);
  }

  Future<void> setDisappearingMessagesTimer(String val) async {
    _disappearingMessagesTimer = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisappearingTimer, val);
  }

  Future<void> setConversationTones(bool val) async {
    _conversationTones = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConvTones, val);
  }

  Future<void> setMessageTone(String val) async {
    _messageTone = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMsgTone, val);
  }

  Future<void> setVibrationLength(String val) async {
    _vibrationLength = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVibration, val);
  }

  Future<void> setHighPriorityNotifications(bool val) async {
    _highPriorityNotifications = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighPriority, val);
  }

  Future<void> setGroupTone(String val) async {
    _groupTone = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroupTone, val);
  }

  Future<void> setCallRingtone(String val) async {
    _callRingtone = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCallRingtone, val);
  }

  Future<void> setAutoPhotosMobile(bool val) async {
    _autoPhotosMobile = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPhotosMobile, val);
  }

  Future<void> setAutoAudioMobile(bool val) async {
    _autoAudioMobile = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoAudioMobile, val);
  }

  Future<void> setAutoVideosMobile(bool val) async {
    _autoVideosMobile = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoVideosMobile, val);
  }

  Future<void> setAutoDocumentsMobile(bool val) async {
    _autoDocsMobile = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDocsMobile, val);
  }

  Future<void> setUseLessDataForCalls(bool val) async {
    _useLessDataCalls = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseLessDataCalls, val);
  }

  Future<void> setAutoMediaMobile({
    bool? photos,
    bool? audio,
    bool? videos,
    bool? docs,
  }) async {
    if (photos != null) _autoPhotosMobile = photos;
    if (audio != null) _autoAudioMobile = audio;
    if (videos != null) _autoVideosMobile = videos;
    if (docs != null) _autoDocsMobile = docs;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoPhotosMobile, _autoPhotosMobile);
    await prefs.setBool(_keyAutoAudioMobile, _autoAudioMobile);
    await prefs.setBool(_keyAutoVideosMobile, _autoVideosMobile);
    await prefs.setBool(_keyAutoDocsMobile, _autoDocsMobile);
  }

  Future<void> setUseLessDataCalls(bool val) async {
    _useLessDataCalls = val;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseLessDataCalls, val);
  }
}

