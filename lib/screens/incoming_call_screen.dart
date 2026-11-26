import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_profile_model.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_avatar.dart';
import 'call_screen.dart';

/// Full-screen incoming call: rings (looping ringtone + heads-up
/// notification when backgrounded) and lets the callee accept or decline.
///
/// Accept → the invitation turns `accepted` and the real [CallScreen] opens,
/// which joins the Agora channel created by the caller. Decline / caller
/// cancel → the call is closed and recorded in history as incoming/missed.
class IncomingCallScreen extends StatefulWidget {
  final String invitationId;
  final String callerUid;
  final bool isVideo;
  final String channelName;

  /// Remaining ringing time before the invitation is treated as missed.
  final Duration maxRing;

  const IncomingCallScreen({
    super.key,
    required this.invitationId,
    required this.callerUid,
    required this.isVideo,
    required this.channelName,
    this.maxRing = CallService.ringTimeout,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final AudioPlayer _ringtone = AudioPlayer();

  StreamSubscription<UserProfile>? _profileSub;
  StreamSubscription<dynamic>? _invitationSub;
  Timer? _missedTimer;

  UserProfile? _profile;
  bool _responded = false;
  bool _notificationShown = false;

  @override
  void initState() {
    super.initState();
    CallService.instance.callStarted();
    _startRinging();

    _profileSub =
        _firebaseService.watchUserProfile(widget.callerUid).listen((profile) {
      if (!mounted) return;
      setState(() => _profile = profile);
      _showNotificationOnce(profile.displayName);
    });

    // React when the caller cancels / the invitation dies.
    _invitationSub = CallService.instance.watch(widget.invitationId).listen(
      (doc) {
        final status = (doc.data()?['status'] ?? '').toString();
        if (status == 'cancelled' || status == 'declined') {
          _dismissAsMissed();
        }
      },
    );

    // Local safety net: never ring forever if the caller's device vanished.
    _missedTimer = Timer(widget.maxRing, _dismissAsMissed);
  }

  Future<void> _startRinging() async {
    try {
      await _ringtone.setReleaseMode(ReleaseMode.loop);
      await _ringtone.play(AssetSource('ringtones/ring.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Ringtone error: $e');
    }
  }

  Future<void> _stopRinging() async {
    try {
      await _ringtone.stop();
    } catch (_) {}
    await NotificationService.instance.cancelIncomingCallNotification();
  }

  void _showNotificationOnce(String name) {
    if (_notificationShown) return;
    _notificationShown = true;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    NotificationService.instance.showIncomingCallNotification(
      name.trim().isEmpty ? 'ModyChat' : name.trim(),
    );
  }

  /// Caller cancelled or vanished: record the missed call and close.
  Future<void> _dismissAsMissed() async {
    if (_responded) return;
    _responded = true;
    _missedTimer?.cancel();
    await _stopRinging();

    try {
      await _firebaseService.logCall(
        otherUid: widget.callerUid,
        isVideo: widget.isVideo,
        outgoing: false,
      );
    } catch (e) {
      debugPrint('Call history error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    if (_responded) return;
    _responded = true;
    _missedTimer?.cancel();
    await _stopRinging();
    await CallService.instance.setStatus(widget.invitationId, 'declined');

    try {
      await _firebaseService.logCall(
        otherUid: widget.callerUid,
        isVideo: widget.isVideo,
        outgoing: false,
      );
    } catch (e) {
      debugPrint('Call history error: $e');
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _accept() async {
    if (_responded) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to talk'),
            backgroundColor: AppColors.darkNavy,
          ),
        );
      }
      await _decline();
      return;
    }
    if (widget.isVideo) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required for video calls'),
              backgroundColor: AppColors.darkNavy,
            ),
          );
        }
        await _decline();
        return;
      }
    }

    _responded = true;
    _missedTimer?.cancel();
    await _stopRinging();
    await CallService.instance.setStatus(widget.invitationId, 'accepted');

    try {
      await _firebaseService.logCall(
        otherUid: widget.callerUid,
        isVideo: widget.isVideo,
        outgoing: false,
      );
    } catch (e) {
      debugPrint('Call history error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUserId: widget.callerUid,
          fallbackName: _profile?.displayName ?? '',
          isVideo: widget.isVideo,
          role: CallRole.callee,
          invitationId: widget.invitationId,
          channelName: widget.channelName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _missedTimer?.cancel();
    _invitationSub?.cancel();
    _profileSub?.cancel();
    _ringtone.dispose();
    CallService.instance.callFinished();
    NotificationService.instance.cancelIncomingCallNotification();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? UserProfile(uid: widget.callerUid);
    final name = profile.displayName.trim().isEmpty
        ? 'Unknown'
        : profile.displayName.trim();

    return Scaffold(
      backgroundColor: AppColors.activeTabBg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.darkNavy, AppColors.activeTabBg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Text(
                widget.isVideo ? 'Incoming video call' : 'Incoming voice call',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              ChatAvatar(
              backgroundColor: profile.avatarBgColor,
              avatarType: profile.avatarType,
              unreadCount: 0,
              size: 150,
              imagePath: profile.hasImage ? profile.imagePath : '',
              ),
              const SizedBox(height: 28),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'is calling…',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _roundButton(
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFE53935),
                    onTap: _decline,
                  ),
                  _roundButton(
                    icon: widget.isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: const Color(0xFF25D366),
                    onTap: _accept,
                  ),
                ],
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}
