import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/chat_model.dart';
import '../screens/chat_detail_screen.dart';
import 'firebase_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseService _firebaseService = FirebaseService();

  /// ID of conversation currently open in [ChatDetailScreen], if any.
  /// Notifications are suppressed while the user is actively viewing that chat.
  String? activeConversationId;

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  final Set<String> _notifiedMessageIds = {};
  StreamSubscription? _conversationsSub;
  final Map<String, StreamSubscription> _messageSubs = {};

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
    startListeningForMessages();
  }

  void startListeningForMessages() {
    _conversationsSub?.cancel();
    final uid = _firebaseService.currentUid;
    if (uid.isEmpty || uid == 'unknown') return;

    _conversationsSub = _firebaseService
        .getPrivateConversationsStream(uid)
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final convId = doc.id;
        _listenToConversationMessages(convId, uid);
      }
    });
  }

  void _listenToConversationMessages(String conversationId, String currentUid) {
    if (_messageSubs.containsKey(conversationId)) return;

    final sub = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final msgId = doc.id;
        final receiverId = (data['receiverId'] ?? '').toString();
        final senderId = (data['senderId'] ?? '').toString();
        final isRead = data['isRead'] == true;

        if (receiverId == currentUid &&
            !isRead &&
            senderId != currentUid &&
            !_notifiedMessageIds.contains(msgId)) {
          _notifiedMessageIds.add(msgId);

          // Mark message as delivered automatically when synced
          _firebaseService.markMessagesAsDelivered(
            conversationId: conversationId,
            recipientUid: currentUid,
          );

          // Do NOT send notification if recipient is actively viewing this conversation
          if (activeConversationId == conversationId) {
            return;
          }

          // Fetch sender profile to get name
          final senderProfile =
              await _firebaseService.getUserProfileById(senderId);
          final senderName = senderProfile?.displayName.isNotEmpty == true
              ? senderProfile!.displayName
              : (data['senderPhone'] ?? 'ModyChat User').toString();
          final senderPhone = senderProfile?.phone ?? (data['senderPhone'] ?? '');

          String preview = (data['text'] ?? '').toString();
          final type = (data['type'] ?? 'text').toString();
          if (type == 'image') preview = '📷 Photo';
          if (type == 'file') preview = '📄 ${data['fileName'] ?? 'Document'}';
          if (type == 'audio') preview = '🎤 Voice Message';
          if (type == 'contact') preview = '👤 Shared Contact';
          if (type == 'location') preview = '📍 Shared Location';

          _showNotification(
            id: msgId.hashCode,
            title: 'New message from $senderName',
            body: preview,
            payload: '$conversationId|$senderId|$senderPhone|$senderName',
          );
        }
      }
    });

    _messageSubs[conversationId] = sub;
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'modychat_messages_channel',
      'ModyChat Messages',
      channelDescription: 'Notifications for incoming messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Heads-up notification for an incoming call while the app is backgrounded.
  /// The full-screen incoming call UI is already pushed by [CallService], so
  /// tapping this only brings the app forward (empty payload).
  Future<void> showIncomingCallNotification(String title) async {
    const androidDetails = AndroidNotificationDetails(
      'modychat_calls_channel',
      'ModyChat Calls',
      channelDescription: 'Notifications for incoming calls',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      playSound: true,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    await _notifications.show(
      918273,
      title,
      'Incoming call…',
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: '',
    );
  }

  Future<void> cancelIncomingCallNotification() async {
    await _notifications.cancel(918273);
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split('|');
    if (parts.length >= 4) {
      final conversationId = parts[0];
      final senderId = parts[1];
      final senderPhone = parts[2];
      final senderName = parts[3];

      _navigateToChat(
        conversationId: conversationId,
        senderId: senderId,
        senderPhone: senderPhone,
        senderName: senderName,
      );
    }
  }

  void _navigateToChat({
    required String conversationId,
    required String senderId,
    required String senderPhone,
    required String senderName,
  }) {
    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    final chatItem = ChatItemModel(
      id: senderId.isNotEmpty ? senderId : senderPhone,
      name: senderName,
      message: '',
      time: 'Just now',
      unreadCount: 0,
      avatarBgColor: const Color(0xFFFFD1DC),
      avatarType: AvatarType.personMale,
      phone: senderPhone,
    );

    navState.push(
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          contact: chatItem,
          otherUserId: senderId,
        ),
      ),
    );
  }

  void dispose() {
    _conversationsSub?.cancel();
    for (var sub in _messageSubs.values) {
      sub.cancel();
    }
    _messageSubs.clear();
  }
}
