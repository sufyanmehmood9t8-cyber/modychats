import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

import 'firebase_service.dart';

/// Tracks the total number of unread incoming messages across ALL conversations
/// for the logged-in user and keeps the Android/iOS launcher badge in sync.
///
/// Usage:
///   • Call [startListening] once after the user signs in.
///   • Call [recalculate] after the user reads a conversation.
///   • Call [clear] on sign-out.
class BadgeService {
  static final BadgeService instance = BadgeService._();
  BadgeService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // Total unread count exposed to listeners (used for in-app badge on Chats tab)
  int _totalUnread = 0;
  int get totalUnread => _totalUnread;

  final StreamController<int> _controller =
      StreamController<int>.broadcast();
  Stream<int> get unreadStream => _controller.stream;

  StreamSubscription? _conversationsSub;
  final Map<String, StreamSubscription> _convMessageSubs = {};
  final Map<String, int> _convUnreadCounts = {};

  bool _started = false;

  // ─── PUBLIC API ────────────────────────────────────────────────────────────

  /// Begin watching all conversations for unread messages.
  void startListening() {
    if (_started) return;
    _started = true;

    final uid = _firebaseService.currentUid;
    if (uid.isEmpty || uid == 'unknown') return;

    _conversationsSub = _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final convId = doc.id;
        _attachConversationListener(convId, uid);
      }
    });
  }

  /// Re-query a specific conversation's unread count (call when user reads chat).
  Future<void> recalculate() async {
    final uid = _firebaseService.currentUid;
    if (uid.isEmpty || uid == 'unknown') return;

    // Re-query all tracked conversations from scratch
    final snapshot = await _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .get();

    _convUnreadCounts.clear();

    for (final doc in snapshot.docs) {
      final convId = doc.id;
      final count = await _queryUnreadCount(convId, uid);
      _convUnreadCounts[convId] = count;
    }

    _publish();
  }

  /// Clear badge on sign-out.
  void clear() {
    _conversationsSub?.cancel();
    for (final sub in _convMessageSubs.values) {
      sub.cancel();
    }
    _convMessageSubs.clear();
    _convUnreadCounts.clear();
    _started = false;
    _totalUnread = 0;
    _controller.add(0);
    _applyBadge(0);
  }

  void dispose() {
    clear();
    _controller.close();
  }

  // ─── INTERNALS ─────────────────────────────────────────────────────────────

  void _attachConversationListener(String conversationId, String uid) {
    if (_convMessageSubs.containsKey(conversationId)) return;

    final sub = _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('receiverId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      // Count only incoming (sender != current user)
      final unread = snap.docs.where((d) {
        final senderId = (d.data()['senderId'] ?? '').toString();
        return senderId != uid;
      }).length;

      _convUnreadCounts[conversationId] = unread;
      _publish();
    });

    _convMessageSubs[conversationId] = sub;
  }

  Future<int> _queryUnreadCount(String conversationId, String uid) async {
    try {
      final snap = await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('receiverId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      return snap.docs.where((d) {
        final senderId = (d.data()['senderId'] ?? '').toString();
        return senderId != uid;
      }).length;
    } catch (_) {
      return 0;
    }
  }

  void _publish() {
    _totalUnread =
        _convUnreadCounts.values.fold(0, (acc, c) => acc + c);
    _controller.add(_totalUnread);
    _applyBadge(_totalUnread);
  }

  void _applyBadge(int count) {
    if (kIsWeb) return; // badges not supported on web
    try {
      if (count <= 0) {
        AppBadgePlus.updateBadge(0);
      } else {
        AppBadgePlus.updateBadge(count);
      }
    } catch (_) {
      // Launcher may not support badges; fail silently
    }
  }
}
