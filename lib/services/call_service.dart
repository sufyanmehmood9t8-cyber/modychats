import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/incoming_call_screen.dart';

/// Real call signalling over Firestore (`call_invitations` collection).
///
/// Flow:
///  1. Caller creates a document with `status: ringing` and a unique Agora
///     [channelName].
///  2. The callee's device listens for ringing invitations addressed to them
///     and shows the incoming call screen.
///  3. Accept → `status: accepted`, both sides join the same Agora channel.
///  4. Decline / cancel / no-answer / end → terminal status, both sides react.
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  static const String collectionName = 'call_invitations';

  /// How long a call rings before the caller gives up.
  static const Duration ringTimeout = Duration(seconds: 45);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomingSub;

  /// IDs of invitations this device already reacted to.
  final Set<String> _handled = {};

  /// Depth of active call screens (incoming ring screen + call screen), so a
  /// second incoming call is auto-declined while this user is already busy.
  int _callDepth = 0;

  bool get inCall => _callDepth > 0;

  void callStarted() => _callDepth++;

  void callFinished() {
    if (_callDepth > 0) _callDepth--;
  }

  GlobalKey<NavigatorState>? _navigatorKey;

  String get _myUid => _auth.currentUser?.uid ?? '';

  // ─── CREATION / STATE ──────────────────────────────────────────────────────

  /// Creates a ringing invitation and returns `{id, channelName}`.
  Future<Map<String, String>> createInvitation({
    required String calleeUid,
    required bool isVideo,
  }) async {
    final callerUid = _myUid;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final channel = 'mc$ts${callerUid.hashCode.toUnsigned(32).toRadixString(16)}';

    final doc = _db.collection(collectionName).doc();
    await doc.set({
      'callerUid': callerUid,
      'calleeUid': calleeUid,
      'channelName': channel,
      'isVideo': isVideo,
      'status': 'ringing',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {'id': doc.id, 'channelName': channel};
  }

  Future<void> setStatus(String invitationId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'accepted') {
      updates['answeredAt'] = FieldValue.serverTimestamp();
    }
    if (status != 'ringing') {
      updates['endedAt'] = FieldValue.serverTimestamp();
    }
    try {
      await _db.collection(collectionName).doc(invitationId).update(updates);
    } catch (e) {
      debugPrint('Call status update error: $e');
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String invitationId) =>
      _db.collection(collectionName).doc(invitationId).snapshots();

  // ─── INCOMING CALL LISTENER ────────────────────────────────────────────────

  /// Starts watching for ringing invitations addressed to the signed-in user.
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;

    // Android 13+/iOS need the runtime notification grant for the incoming
    // call heads-up notification.
    Permission.notification.request();

    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _incomingSub?.cancel();
        _incomingSub = null;
        return;
      }
      _listenIncoming();
    });
  }

  void _listenIncoming() {
    if (_incomingSub != null) return;
    final uid = _myUid;
    if (uid.isEmpty) return;

    _incomingSub = _db
        .collection(collectionName)
        .where('calleeUid', isEqualTo: uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        _handleRinging(doc);
      }
    }, onError: (e) => debugPrint('Incoming call listener error: $e'));
  }

  Future<void> _handleRinging(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final id = doc.id;
    if (_handled.contains(id)) return;

    final data = doc.data();
    final createdAt = data['createdAt'];
    if (createdAt is! Timestamp) return;

    final age = DateTime.now().toUtc().difference(createdAt.toDate());

    // Stale invitation (caller app died or gave up): close it for good.
    if (age > ringTimeout + const Duration(seconds: 10)) {
      _handled.add(id);
      await setStatus(id, 'cancelled');
      return;
    }

    if (inCall) {
      // Busy: auto-decline so the caller hears "declined" instead of silence.
      _handled.add(id);
      await setStatus(id, 'declined');
      return;
    }

    final callerUid = (data['callerUid'] ?? '').toString();
    if (callerUid.isEmpty || callerUid == _myUid) return;
    _handled.add(id);

    _showIncoming(
      invitationId: id,
      callerUid: callerUid,
      isVideo: data['isVideo'] == true,
      channelName: (data['channelName'] ?? '').toString(),
      maxRing: ringTimeout - age,
    );
  }

  void _showIncoming({
    required String invitationId,
    required String callerUid,
    required bool isVideo,
    required String channelName,
    required Duration maxRing,
  }) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          invitationId: invitationId,
          callerUid: callerUid,
          isVideo: isVideo,
          channelName: channelName,
          maxRing: maxRing > Duration.zero ? maxRing : ringTimeout,
        ),
      ),
    );
  }

  void dispose() {
    _incomingSub?.cancel();
    _incomingSub = null;
  }
}
