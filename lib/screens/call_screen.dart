import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/agora_config.dart';
import '../models/user_profile_model.dart';
import '../services/call_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/chat_avatar.dart';

/// Which side of the invitation this screen belongs to.
enum CallRole { caller, callee }

/// Real one-to-one audio/video call over Agora RTC.
///
/// The caller creates a Firestore `call_invitations` document (ringing) and
/// joins the Agora channel immediately; the callee's device shows the incoming
/// call screen and joins the same channel on accept. Status changes
/// (accepted / declined / cancelled / ended) travel through Firestore, so
/// both sides always agree on what the call is doing.
class CallScreen extends StatefulWidget {
  /// Firebase UID of the OTHER participant.
  final String otherUserId;

  /// Name used until the live profile arrives.
  final String fallbackName;

  final bool isVideo;

  final CallRole role;

  /// Required for [CallRole.callee]: the already-created invitation.
  final String? invitationId;

  /// Agora channel to join. Required for callee; caller generates it.
  final String? channelName;

  const CallScreen({
    super.key,
    required this.otherUserId,
    this.fallbackName = '',
    this.isVideo = false,
    this.role = CallRole.caller,
    this.invitationId,
    this.channelName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  StreamSubscription<UserProfile>? _profileSub;
  StreamSubscription<dynamic>? _invitationSub;

  RtcEngine? _engine;

  UserProfile? _profile;

  String _invitationId = '';
  String _channelName = '';

  bool _accepted = false;
  bool _connected = false;
  bool _finished = false;
  String? _finishMessage;

  bool _isMuted = false;
  bool _isSpeakerOn = false;

  int _remoteUid = 0;
  int _elapsedSeconds = 0;

  Timer? _ringTimeoutTimer;
  Timer? _connectTimer;
  Timer? _durationTimer;
  Timer? _autoPopTimer;

  bool get _isCaller => widget.role == CallRole.caller;

  @override
  void initState() {
    super.initState();
    CallService.instance.callStarted();

    _invitationId = widget.invitationId ?? '';
    _channelName = widget.channelName ?? '';
    _accepted = !_isCaller;
    _isSpeakerOn = widget.isVideo;

    _profileSub = _firebaseService
        .watchUserProfile(widget.otherUserId)
        .listen((profile) {
      if (!mounted) return;
      setState(() => _profile = profile);
    });

    _bootstrap();
  }

  // ─── SETUP ─────────────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    if (!AgoraConfig.isConfigured) {
      _fail('Agora App ID missing — add it in lib/config/agora_config.dart');
      return;
    }

    if (_isCaller) {
      final granted = await _requestPermissions();
      if (!granted) {
        _fail('Microphone permission is required to talk');
        return;
      }
      if (!mounted) return;

      try {
        final invite = await CallService.instance.createInvitation(
          calleeUid: widget.otherUserId,
          isVideo: widget.isVideo,
        );
        _invitationId = invite['id'] ?? '';
        _channelName = invite['channelName'] ?? '';
      } catch (e) {
        debugPrint('Create invitation error: $e');
        _fail('Could not start the call');
        return;
      }

      // Call history entry for the Calls tab.
      unawaited(_firebaseService.logCall(
        otherUid: widget.otherUserId,
        isVideo: widget.isVideo,
      ));

      // No answer → give up after the ringing window.
      _ringTimeoutTimer = Timer(CallService.ringTimeout, () {
        if (!mounted || _finished || _accepted) return;
        CallService.instance.setStatus(_invitationId, 'cancelled');
        _endWith('No answer', updateStatus: false);
      });
    } else {
      if (_channelName.isEmpty) {
        _fail('Call channel missing');
        return;
      }
    }

    _watchInvitation();
    await _joinChannel();
  }

  Future<bool> _requestPermissions() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (widget.isVideo) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  void _watchInvitation() {
    if (_invitationId.isEmpty) return;
    _invitationSub = CallService.instance.watch(_invitationId).listen(
      (doc) {
        if (!mounted || _finished) return;
        final status = (doc.data()?['status'] ?? '').toString();
        switch (status) {
          case 'accepted':
            if (!_accepted) setState(() => _accepted = true);
            // Accepted, but if the other side never joins (app killed right
            // after answering) the call must still fail instead of hanging.
            _connectTimer ??= Timer(const Duration(seconds: 30), () {
              if (!mounted || _finished || _connected) return;
              CallService.instance.setStatus(_invitationId, 'ended');
              _endWith('Call failed', updateStatus: false);
            });
            break;
          case 'declined':
            _endWith('Call declined', updateStatus: false);
            break;
          case 'cancelled':
            _endWith('No answer', updateStatus: false);
            break;
          case 'ended':
            _endWith('Call ended', updateStatus: false);
            break;
        }
      },
      onError: (e) => debugPrint('Invitation watch error: $e'),
    );
  }

  Future<void> _joinChannel() async {
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(
        appId: AgoraConfig.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            _connectTimer?.cancel();
            setState(() {
              _remoteUid = remoteUid;
              _connected = true;
            });
            _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (!mounted) return;
              setState(() => _elapsedSeconds++);
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted || !_connected) return;
            setState(() => _remoteUid = 0);
            _endWith('Call ended');
          },
          onError: (err, message) {
            debugPrint('Agora error: $err $message');
            if (_finished) return;
            if (err == ErrorCodeType.errInvalidToken ||
                err == ErrorCodeType.errJoinChannelRejected) {
              _endWith('Call failed');
            }
          },
        ),
      );

      await engine.enableAudio();
      if (widget.isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      }
      await engine.setEnableSpeakerphone(_isSpeakerOn);

      await engine.joinChannel(
        token: '',
        channelId: _channelName,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: widget.isVideo,
          publishMicrophoneTrack: true,
          publishCameraTrack: widget.isVideo,
        ),
      );

      if (!mounted) {
        await _disposeEngine(engine);
        return;
      }
      setState(() => _engine = engine);
    } catch (e) {
      debugPrint('Agora join error: $e');
      _endWith('Call failed');
    }
  }

  Future<void> _disposeEngine(RtcEngine engine) async {
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (e) {
      debugPrint('Agora teardown error: $e');
    }
  }

  // ─── CALL LIFECYCLE ────────────────────────────────────────────────────────

  /// Local user taps end / back: close the invitation and leave the channel.
  Future<void> _hangUp() async {
    if (_finished) {
      // The call already ended remotely — just close the screen.
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _finished = true;
    _finishMessage = null;
    _stopTimers();

    if (_invitationId.isNotEmpty) {
      final terminal = (!_isCaller || _accepted) ? 'ended' : 'cancelled';
      unawaited(CallService.instance.setStatus(_invitationId, terminal));
    }

    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(_disposeEngine(engine));

    if (mounted) Navigator.of(context).pop();
  }

  /// Remote side (or a failure) finished the call: show why, then close.
  ///
  /// [updateStatus] is false when the invitation already carries the terminal
  /// status written by the other device (don't overwrite e.g. `declined`).
  void _endWith(String message, {bool updateStatus = true}) {
    if (_finished) return;
    _finished = true;
    _finishMessage = message;
    _stopTimers();

    if (updateStatus && _invitationId.isNotEmpty) {
      final terminal = (!_isCaller || _accepted) ? 'ended' : 'cancelled';
      unawaited(CallService.instance.setStatus(_invitationId, terminal));
    }

    final engine = _engine;
    _engine = null;
    if (engine != null) unawaited(_disposeEngine(engine));

    if (!mounted) return;
    setState(() {});
    _autoPopTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// Fatal setup problem (no App ID, no permission…): message + close.
  void _fail(String message) {
    if (_finished) return;
    _finished = true;
    _stopTimers();

    // Never leave a created invitation stuck in ringing/accepted.
    if (_invitationId.isNotEmpty) {
      final terminal = (!_isCaller || _accepted) ? 'ended' : 'cancelled';
      unawaited(CallService.instance.setStatus(_invitationId, terminal));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.darkNavy),
    );
    Navigator.of(context).pop();
  }

  void _stopTimers() {
    _ringTimeoutTimer?.cancel();
    _connectTimer?.cancel();
    _durationTimer?.cancel();
    _autoPopTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    _invitationSub?.cancel();
    _profileSub?.cancel();

    // Closing without an explicit hang-up (system back / swipe) still has to
    // notify the other side, otherwise their phone keeps ringing.
    if (!_finished && _invitationId.isNotEmpty) {
      final terminal = (!_isCaller || _accepted) ? 'ended' : 'cancelled';
      unawaited(CallService.instance.setStatus(_invitationId, terminal));
    }

    final engine = _engine;
    if (engine != null) _disposeEngine(engine);

    CallService.instance.callFinished();
    super.dispose();
  }

  // ─── CONTROLS ──────────────────────────────────────────────────────────────

  Future<void> _toggleMute() async {
    _isMuted = !_isMuted;
    setState(() {});
    try {
      await _engine?.muteLocalAudioStream(_isMuted);
    } catch (e) {
      debugPrint('Mute error: $e');
    }
  }

  Future<void> _toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    setState(() {});
    try {
      await _engine?.setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {
      debugPrint('Speaker error: $e');
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _engine?.switchCamera();
    } catch (e) {
      debugPrint('Switch camera error: $e');
    }
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  String get _statusText {
    if (_finishMessage != null) return _finishMessage!;
    if (_connected) {
      final mins = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
      final secs = (_elapsedSeconds % 60).toString().padLeft(2, '0');
      return 'Connected  $mins:$secs';
    }
    if (_isCaller && !_accepted) return 'Ringing…';
    return 'Connecting…';
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.darkNavy : Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildVideoStage(UserProfile profile, String name) {
    if (_engine != null && _connected && _remoteUid != 0) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _channelName),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar(
            backgroundColor: profile.avatarBgColor,
            avatarType: profile.avatarType,
            unreadCount: 0,
            size: 150,
            imagePath: profile.hasImage ? profile.imagePath : '',
          ),
          const SizedBox(height: 24),
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
          Text(
            _statusText,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        _profile ?? UserProfile(uid: widget.otherUserId, name: widget.fallbackName);

    final name = profile.name.trim().isNotEmpty
        ? profile.name.trim()
        : (widget.fallbackName.trim().isNotEmpty
            ? widget.fallbackName.trim()
            : profile.displayName);

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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _hangUp,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.isVideo ? 'Video call' : 'Voice call',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              if (widget.isVideo)
                Expanded(
                  child: Stack(
                    children: [
                      _buildVideoStage(profile, name),
                      if (_engine != null && !_finished)
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Container(
                            width: 110,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white24,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(
                                  uid: 0,
                                  sourceType: VideoSourceType.videoSourceCamera,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else ...[
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
                Text(
                  _statusText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
              ],

              // Call controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    isActive: _isMuted,
                    onTap: _toggleMute,
                  ),
                  if (widget.isVideo)
                    _buildControlButton(
                      icon: Icons.cameraswitch_rounded,
                      isActive: false,
                      onTap: _switchCamera,
                    ),
                  _buildControlButton(
                    icon: _isSpeakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    isActive: _isSpeakerOn,
                    onTap: _toggleSpeaker,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // End call
              InkWell(
                onTap: _hangUp,
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_end_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
