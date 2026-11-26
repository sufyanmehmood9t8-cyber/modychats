import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_util;

import '../models/chat_message_model.dart';
import '../models/chat_model.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_service.dart';
import '../services/image_cache_service.dart';
import '../services/badge_service.dart';
import '../services/notification_service.dart';
import '../services/wallpaper_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/supabase_storage_service.dart';
import '../theme/app_colors.dart';
import 'call_screen.dart';
import '../widgets/bottom_attachment_clipper.dart';
import '../widgets/chat_avatar.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatItemModel contact;

  /// Firebase UID of the OTHER participant. This is the identity used for the
  /// conversation and for loading the header profile — never the logged-in
  /// user's own UID, never a contact id.
  final String otherUserId;

  const ChatDetailScreen({
    super.key,
    required this.contact,
    this.otherUserId = '',
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _imagePicker = ImagePicker();

  /// Live profile of the OTHER participant, loaded from the shared profile
  /// source (Firestore `users`) using the selected user's Firebase UID.
  ///
  /// This is a SINGLE-SUBSCRIPTION stream, so exactly one listener is allowed.
  /// The subscription in [initState] is the only one; the whole screen renders
  /// from the latest value in [_otherProfile].
  late final Stream<UserProfile> _otherProfileStream;
  StreamSubscription<UserProfile>? _otherProfileSub;
  UserProfile? _otherProfile;

  /// Conversation identity and its Firestore streams are created ONCE in
  /// [initState]. Creating them inside build() would attach a brand new
  /// Firestore listener on every rebuild.
  late final String _conversationId;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _conversationStream;
  late final Stream<QuerySnapshot> _messagesStream;

  // Audio Recording & Playback
  late final AudioRecorder _audioRecorder;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool _isPlayingAudio = false;
  String? _currentlyPlayingMsgId;

  // Other participant state (loaded from the shared profile source)
  late bool _isOnline;
  late String _displayName;
  late String _targetPhone;
  late String _otherUserId;
  String _otherImagePath = '';
  Color _otherAvatarBgColor = AppColors.avatarPeach;
  AvatarType _otherAvatarType = AvatarType.personMale;

  late List<ChatMessageModel> _localMessages;
  // Stage 1 Action States
  ChatMessageModel? _replyingToMessage;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _isOnline = true; // Default online
    _displayName = widget.contact.displayName;
    _targetPhone = widget.contact.phone;
    _otherUserId = widget.otherUserId.isNotEmpty
        ? widget.otherUserId
        : (widget.contact.id.contains('+') ? '' : widget.contact.id);
    _otherProfileStream = _firebaseService.watchUserProfile(_otherUserId);

    // Deterministic conversation id + its live streams, built once so that a
    // rebuild never re-subscribes to Firestore.
    _conversationId = FirebaseService.getConversationId(
      _firebaseService.currentUid,
      _otherUserId,
    );
    _conversationStream = _firebaseService.watchConversationStream(_conversationId);
    _messagesStream = _firebaseService.getPrivateMessagesStream(_conversationId);

    // No placeholder messages: a brand new conversation must render empty and
    // only ever show messages that were actually stored in Firestore.
    _localMessages = <ChatMessageModel>[];

    // The one and only listener of the OTHER user's profile stream. Header,
    // message bubbles and the info sheet all render from [_otherProfile], so
    // a profile edit is reflected everywhere in this screen.
    _otherProfileSub = _otherProfileStream.listen((profile) {
      if (!mounted) return;
      _otherProfile = profile;
      _isOnline = profile.isOnline;
      if (profile.name.isNotEmpty) _displayName = profile.name;
      if (profile.phone.isNotEmpty) _targetPhone = profile.phone;
      if (profile.hasImage) _otherImagePath = profile.imagePath;
      _otherAvatarBgColor = profile.avatarBgColor;
      _otherAvatarType = profile.avatarType;
      setState(() {});
    });

    NotificationService.instance.activeConversationId = _conversationId;
    _firebaseService.markMessagesAsRead(
      conversationId: _conversationId,
      recipientUid: _firebaseService.currentUid,
    );

    // Listen to audio player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _currentlyPlayingMsgId = null;
          }
        });
      }
    });
  }

  /// Shows the selected user's live profile (name, phone, about).
  /// Profile edits are only possible from that user's own Profile screen.
  void _showProfileInfoDialog(UserProfile profile) {
    final imagePath = profile.hasImage ? profile.imagePath : _otherImagePath;
    final isNetwork = imagePath.startsWith('http://') || imagePath.startsWith('https://');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.person_rounded, color: AppColors.accentCoral),
              SizedBox(width: 8),
              Text('Contact Info',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.avatarPeach,
                  backgroundImage:
                      isNetwork ? CachedNetworkImageProvider(imagePath) : null,
                  child: isNetwork
                      ? null
                      : const Icon(Icons.person_rounded,
                          color: AppColors.titleText, size: 38),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleText,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 16, color: AppColors.subtitleText),
                  const SizedBox(width: 8),
                  Text(
                    profile.phone.isNotEmpty ? profile.phone : _targetPhone,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.subtitleText),
                  ),
                ],
              ),
              if (profile.about.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.subtitleText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        profile.about,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.subtitleText),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Opens the call screen for the OTHER participant. The call attempt itself
  /// is recorded there, so both the screen and the Calls tab share one source.
  void _startCall({bool isVideo = false}) {
    if (_otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This contact is not available for calls')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUserId: _otherUserId,
          fallbackName: _displayName,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (NotificationService.instance.activeConversationId == _conversationId) {
      NotificationService.instance.activeConversationId = null;
    }
    // Recalculate launcher badge now that the user has left this conversation.
    // Messages marked as read during the session are excluded from the count.
    BadgeService.instance.recalculate();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    _otherProfileSub?.cancel();
    super.dispose();
  }

  // ─── AUDIO RECORDING LOGIC ──────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingSeconds++;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
      });

      if (path != null && path.isNotEmpty) {
        final durationSecs = _recordingSeconds > 0 ? _recordingSeconds : 1;
        final msgId = DateTime.now().millisecondsSinceEpoch.toString();
        final fileName = 'voice_$msgId.m4a';

        final String mediaUrl;
        try {
          mediaUrl = await SupabaseStorageService.uploadChatMedia(
            file: File(path),
            conversationId: _conversationId,
            messageId: msgId,
            fileName: fileName,
            mimeType: 'audio/mp4',
          );
        } on SupabaseStorageException catch (e) {
          _showUploadError('Voice note not sent', e.message);
          return;
        } catch (e) {
          debugPrint('Error uploading voice note: $e');
          _showUploadError('Voice note not sent', 'Unexpected upload error.');
          return;
        }

        _dispatchMessage(
          text: '🎤 Voice Message (${durationSecs}s)',
          type: 'audio',
          mediaPath: mediaUrl,
          audioDurationSeconds: durationSecs,
          messageType: MessageType.audio,
        );
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  Future<void> _playVoiceNote(String msgId, String filePath) async {
    try {
      if (_currentlyPlayingMsgId == msgId) {
        if (_isPlayingAudio) {
          await _audioPlayer.pause();
          setState(() {
            _isPlayingAudio = false;
          });
        } else {
          await _audioPlayer.resume();
          setState(() {
            _isPlayingAudio = true;
          });
        }
        return;
      }

      final resolvedUrl = SupabaseStorageService.resolveMediaUrl(filePath);
      if (resolvedUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice message URL is invalid')),
          );
        }
        return;
      }

      await _audioPlayer.stop();

      if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
        await _audioPlayer.play(UrlSource(resolvedUrl));
        if (mounted) {
          setState(() {
            _isPlayingAudio = true;
            _currentlyPlayingMsgId = msgId;
          });
        }
      } else if (filePath.isNotEmpty && File(filePath).existsSync()) {
        await _audioPlayer.play(DeviceFileSource(filePath));
        if (mounted) {
          setState(() {
            _isPlayingAudio = true;
            _currentlyPlayingMsgId = msgId;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice message file could not be played')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error playing voice note: $e');
    }
  }

  // Send Text Message
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _dispatchMessage(
      text: text,
      type: 'text',
      messageType: MessageType.text,
    );
  }

/// Tells the user why an attachment was not sent. A message is never stored
  /// with a media path that cannot be loaded.
  void _showUploadError(String title, String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $reason'),
        backgroundColor: AppColors.darkNavy,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Full-screen, zoomable preview of a picture message.
  void _openImageViewer(ChatMessageModel msg) {
    final resolved =
        SupabaseStorageService.resolveMediaUrl(msg.mediaPath);
    final isNetwork =
        resolved.startsWith('http://') || resolved.startsWith('https://');
    final isLocal = resolved.isNotEmpty && File(resolved).existsSync();

    ImageProvider? provider;
    if (isNetwork) {
      provider = NetworkImage(resolved);
    } else if (isLocal) {
      provider = FileImage(File(resolved));
    }

    if (provider == null) {
      _showUploadError('Picture unavailable', 'This picture is missing.');
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image(
                  image: provider!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(
                      color: Colors.white,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'Could not load this picture',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 1. Gallery Attachment Handler
  Future<void> _pickGalleryImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      final msgId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = path_util.basename(image.path);

      // The photo must exist in Storage BEFORE the message is written,
      // otherwise the message would point at media nobody can load.
      final String mediaPath;
      try {
        mediaPath = await SupabaseStorageService.uploadChatMedia(
          file: File(image.path),
          conversationId: _conversationId,
          messageId: msgId,
          fileName: fileName,
          mimeType: 'image/jpeg',
        );
      } on SupabaseStorageException catch (e) {
        _showUploadError('Photo not sent', e.message);
        return;
      } catch (e) {
        debugPrint('Error uploading image: $e');
        _showUploadError('Photo not sent', 'Unexpected upload error.');
        return;
      }

      _dispatchMessage(
        text: '📷 Photo',
        type: 'image',
        mediaPath: mediaPath,
        messageType: MessageType.image,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  // 2. Document Attachment Handler
  Future<void> _pickDocumentFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final sizeKb = (file.size / 1024).toStringAsFixed(1);
        final msgId = DateTime.now().millisecondsSinceEpoch.toString();

        final String mediaPath;
        try {
          mediaPath = await SupabaseStorageService.uploadChatMedia(
            file: File(file.path!),
            conversationId: _conversationId,
            messageId: msgId,
            fileName: file.name,
            mimeType: 'application/octet-stream',
          );
        } on SupabaseStorageException catch (e) {
          _showUploadError('File not sent', e.message);
          return;
        } catch (e) {
          debugPrint('Error uploading file: $e');
          _showUploadError('File not sent', 'Unexpected upload error.');
          return;
        }

        _dispatchMessage(
          text: '📄 ${file.name}',
          type: 'file',
          mediaPath: mediaPath,
          fileName: file.name,
          fileSize: '$sizeKb KB',
          messageType: MessageType.file,
        );
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  // 3. Contact Dialog Handler
  void _pickContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Share Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Contact Name'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final cName = nameCtrl.text.trim();
                final cPhone = phoneCtrl.text.trim();

                if (cName.isNotEmpty && cPhone.isNotEmpty) {
                  _dispatchMessage(
                    text: '👤 Contact: $cName',
                    type: 'contact',
                    contactName: cName,
                    contactPhone: cPhone,
                    messageType: MessageType.contact,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Share'),
            ),
          ],
        );
      },
    );
  }

  // 4. Location Dialog Handler
  void _pickLocationDialog() {
    final addressCtrl = TextEditingController(text: 'Islamabad, Pakistan');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Share Location'),
          content: TextField(
            controller: addressCtrl,
            decoration: const InputDecoration(labelText: 'Address / Coordinates'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final addr = addressCtrl.text.trim();
                if (addr.isNotEmpty) {
                  _dispatchMessage(
                    text: '📍 Location: $addr',
                    type: 'location',
                    locationAddress: addr,
                    messageType: MessageType.location,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Share Location'),
            ),
          ],
        );
      },
    );
  }

  // Helper dispatcher to send message either to Firebase or Local list
  Future<void> _dispatchMessage({
    required String text,
    required String type,
    String mediaPath = '',
    String fileName = '',
    String fileSize = '',
    String contactName = '',
    String contactPhone = '',
    String locationAddress = '',
    int audioDurationSeconds = 0,
    required MessageType messageType,
  }) async {
    final currentPhone = FirebaseService.currentUserPhone;
    final currentUid = _firebaseService.currentUid;

    final replyId = _replyingToMessage?.id;
    final replyText = _replyingToMessage?.text;
    final replySenderId = _replyingToMessage?.senderPhone;

    if (_otherUserId.isNotEmpty) {
      try {
        await _firebaseService.sendMessage(
          senderPhone: currentPhone,
          receiverPhone: _targetPhone,
          senderUid: currentUid,
          receiverUid: _otherUserId,
          text: text,
          type: type,
          mediaPath: mediaPath,
          fileName: fileName,
          fileSize: fileSize,
          contactName: contactName,
          contactPhone: contactPhone,
          locationAddress: locationAddress,
          audioDurationSeconds: audioDurationSeconds,
          replyToMessageId: replyId,
          replyToText: replyText,
          replyToSenderId: replySenderId,
        );
      } catch (e) {
        debugPrint('Firebase dispatch error: $e');
      }
    } else {
      setState(() {
        _localMessages.add(
          ChatMessageModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderName: 'Me',
            senderPhone: currentPhone,
            receiverPhone: _targetPhone,
            text: text,
            time: 'Just now',
            isMe: true,
            isRead: true,
            type: messageType,
            mediaPath: mediaPath,
            fileName: fileName,
            fileSize: fileSize,
            contactName: contactName,
            contactPhone: contactPhone,
            locationAddress: locationAddress,
            audioDurationSeconds: audioDurationSeconds,
            replyToMessageId: replyId,
            replyToText: replyText,
            replyToSenderId: replySenderId,
          ),
        );
      });
    }

    if (_replyingToMessage != null) {
      setState(() {
        _replyingToMessage = null;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── STAGE 1: LONG PRESS OPTIONS & REACTIONS ────────────────────────────────

  void _showMessageOptionsMenu(ChatMessageModel msg, String conversationId) {
    final currentUid = _firebaseService.currentUid;
    final isOwner = msg.isMe;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reaction Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['❤️', '😂', '👍', '😢', '😮', '😡', '🙏'].map((emoji) {
                    final bool isSelected = msg.reactions[currentUid] == emoji;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _firebaseService.toggleReaction(
                          conversationId: conversationId,
                          messageId: msg.id,
                          uid: currentUid,
                          emoji: emoji,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentCoral.withValues(alpha: 0.2) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Action Items
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppColors.titleText),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingToMessage = msg;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.titleText),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied to clipboard')),
                  );
                },
              ),
              if (isOwner && !msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: AppColors.titleText),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditMessageDialog(msg, conversationId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.push_pin_outlined, color: AppColors.titleText),
                title: const Text('Pin Message'),
                onTap: () {
                  Navigator.pop(context);
                  _firebaseService.pinMessage(
                    conversationId: conversationId,
                    messageId: msg.id,
                    messageText: msg.text,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete for me', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _firebaseService.deleteMessageForMe(
                    conversationId: conversationId,
                    messageId: msg.id,
                    uid: currentUid,
                  );
                },
              ),
              if (isOwner && !msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                  title: const Text('Delete for everyone', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _firebaseService.deleteMessageForEveryone(
                      conversationId: conversationId,
                      messageId: msg.id,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(ChatMessageModel msg, String conversationId) {
    final editController = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Message'),
          content: TextField(
            controller: editController,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != msg.text) {
                  _firebaseService.editMessage(
                    conversationId: conversationId,
                    messageId: msg.id,
                    newText: newText,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReplyPreviewBar() {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: const Border(left: BorderSide(color: AppColors.accentCoral, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _replyingToMessage!.isMe ? 'Replying to yourself' : 'Replying to $_displayName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentCoral),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingToMessage!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.titleText),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _replyingToMessage = null;
              });
            },
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.subtitleText),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageHeader(String conversationId, String? pinnedText) {
    if (pinnedText == null || pinnedText.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          const Icon(Icons.push_pin_rounded, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pinned: $pinnedText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          IconButton(
            onPressed: () => _firebaseService.unpinMessage(conversationId: conversationId),
            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPhone = FirebaseService.currentUserPhone;
    final currentUid = _firebaseService.currentUid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header rendered from the OTHER user's live profile (by UID).
            // The profile stream is already subscribed once in initState, so
            // this section must not subscribe to it again.
            Builder(
              builder: (context) {
                final profile = _otherProfile ??
                    UserProfile(
                      uid: _otherUserId,
                      name: _displayName,
                      phone: _targetPhone,
                      imagePath: _otherImagePath,
                    );

                final headerName = profile.name.isNotEmpty
                    ? profile.name
                    : (profile.phone.isNotEmpty ? profile.phone : _displayName);
                final headerImage = profile.hasImage
                    ? profile.imagePath
                    : _otherImagePath;
                final headerPhone = profile.phone.isNotEmpty
                    ? profile.phone
                    : _targetPhone;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.titleText,
                          size: 32,
                        ),
                      ),
                      ChatAvatar(
                        backgroundColor: profile.avatarBgColor,
                        avatarType: profile.avatarType,
                        unreadCount: 0,
                        size: 44,
                        imagePath: headerImage,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    headerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.titleText,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _showProfileInfoDialog(profile),
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.subtitleText,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isOnline
                                        ? const Color(0xFF2ECC71)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isOnline
                                      ? 'Online'
                                      : (headerPhone.isNotEmpty
                                          ? headerPhone
                                          : 'Offline'),
                                  style: TextStyle(
                                    color: _isOnline
                                        ? AppColors.accentCoral
                                        : AppColors.subtitleText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _startCall(),
                        tooltip: 'Voice call',
                        icon: const Icon(
                          Icons.call_rounded,
                          color: AppColors.titleText,
                          size: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchQuery = '';
                              _searchController.clear();
                            }
                          });
                        },
                        icon: Icon(
                          _isSearching
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          color: AppColors.titleText,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // In-Chat Search Bar Widget
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search messages in chat...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accentCoral),
                    filled: true,
                    fillColor: const Color(0xFFF0F4F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),

            // 2. Real-Time Firebase Message List View with Pinned Banner & Actions
            //    Both streams below were created once in initState, so opening
            //    the chat attaches exactly one Firestore listener each and
            //    rebuilds reuse the same subscription.
            Expanded(
              child: Consumer<WallpaperService>(
                builder: (context, wallpaperService, _) {
                  return Container(
                    decoration: wallpaperService.getChatBackgroundDecoration(),
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _conversationStream,
                      builder: (context, convSnap) {
                        String? pinnedText;
                        if (convSnap.hasData && convSnap.data!.exists) {
                          final cData = convSnap.data!.data() ?? {};
                          pinnedText = cData['pinnedText']?.toString();
                        }

                        return Column(
                          children: [
                            _buildPinnedMessageHeader(_conversationId, pinnedText),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _messagesStream,
                                builder: (context, snapshot) {
                                  List<ChatMessageModel> messagesList = _localMessages;

                                  final docs = snapshot.data?.docs ?? [];

                                  if (docs.isNotEmpty) {
                                    messagesList = docs.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;

                                      MessageType type = MessageType.text;
                                      final typeStr = data['type'] ?? 'text';
                                      if (typeStr == 'image') type = MessageType.image;
                                      if (typeStr == 'file') type = MessageType.file;
                                      if (typeStr == 'contact') type = MessageType.contact;
                                      if (typeStr == 'location') type = MessageType.location;
                                      if (typeStr == 'audio') type = MessageType.audio;

                                      final senderId = (data['senderId'] ?? '').toString();
                                      final senderPhone = (data['senderPhone'] ?? '').toString();

                                      final bool isMe = (senderId.isNotEmpty)
                                          ? (senderId == currentUid)
                                          : (FirebaseService.normalizePhone(senderPhone) == FirebaseService.normalizePhone(currentPhone));

                                      final List<dynamic> delFor = data['deletedFor'] ?? [];

                                      return ChatMessageModel(
                                        id: doc.id,
                                        senderName: isMe ? 'Me' : _displayName,
                                        senderPhone: senderPhone,
                                        senderId: senderId,
                                        receiverPhone: (data['receiverPhone'] ?? '').toString(),
                                        receiverId: (data['receiverId'] ?? '').toString(),
                                        text: data['text'] ?? '',
                                        time: data['time'] ?? 'Just now',
                                        isMe: isMe,
                                        isDelivered: data['isDelivered'] == true,
                                        isRead: data['isRead'] == true,
                                        sentAt: data['sentAt'],
                                        deliveredAt: data['deliveredAt'],
                                        readAt: data['readAt'],
                                        type: type,
                                        mediaPath: data['mediaPath'] ?? '',
                                        fileName: data['fileName'] ?? '',
                                        fileSize: data['fileSize'] ?? '',
                                        contactName: data['contactName'] ?? '',
                                        contactPhone: data['contactPhone'] ?? '',
                                        locationAddress: data['locationAddress'] ?? '',
                                        audioDurationSeconds: data['audioDurationSeconds'] ?? 0,
                                        replyToMessageId: data['replyToMessageId']?.toString(),
                                        replyToText: data['replyToText']?.toString(),
                                        replyToSenderId: data['replyToSenderId']?.toString(),
                                        isEdited: data['isEdited'] ?? false,
                                        editedAt: data['editedAt'],
                                        isDeleted: data['isDeleted'] ?? false,
                                        deletedFor: delFor.map((e) => e.toString()).toList(),
                                        reactions: Map<String, String>.from(data['reactions'] ?? {}),
                                      );
                                    }).where((msg) => !msg.deletedFor.contains(currentUid)).toList();
                                  }

                                  // Apply Search Filter if active
                                  if (_searchQuery.isNotEmpty) {
                                    messagesList = messagesList.where((m) => m.text.toLowerCase().contains(_searchQuery)).toList();
                                  }

                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    itemCount: messagesList.length,
                                    itemBuilder: (context, index) {
                                      final msg = messagesList[index];
                                      return GestureDetector(
                                        onLongPress: () => _showMessageOptionsMenu(msg, _conversationId),
                                        child: _buildMessageBubble(msg),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Reply Preview Banner if active
            _buildReplyPreviewBar(),

            // 3. Message Input Row with Voice Recording Support
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _isRecording
                  ? _buildVoiceRecordingRow()
                  : _buildNormalInputRow(),
            ),

            // 4. Curved Bottom Attachment Bar
            ClipPath(
              clipper: BottomAttachmentClipper(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 36, bottom: 20, left: 24, right: 24),
                color: AppColors.darkNavy,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      tooltip: 'Gallery Image',
                      onTap: _pickGalleryImage,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      tooltip: 'PDF / File',
                      onTap: _pickDocumentFile,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.person_rounded,
                      label: 'Contact',
                      tooltip: 'Contact',
                      onTap: _pickContactDialog,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      tooltip: 'Location',
                      onTap: _pickLocationDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildNormalInputRow() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEFFC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: () {
              _messageController.clear();
            },
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.accentCoral,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEFFC),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: _startRecording,
            icon: const Icon(
              Icons.mic_rounded,
              color: AppColors.accentCoral,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEFFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: AppColors.titleText,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Write a message',
                      hintStyle: TextStyle(
                        color: AppColors.subtitleText,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                GestureDetector(
                  onTap: _sendMessage,
                  child: const Icon(
                    Icons.send_rounded,
                    color: AppColors.accentCoral,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceRecordingRow() {
    final mins = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordingSeconds % 60).toString().padLeft(2, '0');

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentCoral, width: 1.5),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$mins:$secs',
            style: const TextStyle(
              color: AppColors.titleText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _stopAndSendRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            label: const Text('Send Voice', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    return Column(
      crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (msg.isMe)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.accentCoral,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: _buildBubbleContent(msg, isMe: true),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 12, right: 40),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatAvatar(
                  backgroundColor: _otherAvatarBgColor,
                  avatarType: _otherAvatarType,
                  unreadCount: 0,
                  size: 32,
                  imagePath: _otherImagePath,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2ECC71),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: _buildBubbleContent(msg, isMe: false),
                  ),
                ),
              ],
            ),
          ),

        // Reaction Bar Badge below bubble
        if (msg.reactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: msg.isMe ? 0 : 42, right: msg.isMe ? 24 : 0, bottom: 8),
            child: Wrap(
              spacing: 4,
              children: msg.reactions.values.toSet().map((emoji) {
                final count = msg.reactions.values.where((e) => e == emoji).length;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text('$emoji ${count > 1 ? count : ''}', style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// Tick marks on an outgoing message.
  ///
  /// The number of ticks follows the OTHER user's live presence: one grey tick
  /// while they are offline, two ticks once they are online, and both ticks
  /// turn green the moment the message is marked as read.
  Widget _buildCheckMarkIcon(ChatMessageModel msg) {
    if (msg.isRead) {
      return const Icon(
        Icons.done_all_rounded,
        color: Color(0xFF2ECC71),
        size: 18,
      );
    }

    if (_isOnline) {
      return const Icon(
        Icons.done_all_rounded,
        color: Colors.white70,
        size: 18,
      );
    }

    return const Icon(
      Icons.done_rounded,
      color: Colors.white54,
      size: 18,
    );
  }

  Widget _buildBubbleContent(ChatMessageModel msg, {required bool isMe}) {
    final textColor = Colors.white;

    if (msg.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block_rounded, color: Colors.white70, size: 16),
          SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply Box inside bubble
        if (msg.replyToText != null && msg.replyToText!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: Colors.white, width: 3)),
            ),
            child: Text(
              msg.replyToText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),

        switch (msg.type) {
          MessageType.image => Builder(
              builder: (context) {
                final resolvedUrl = SupabaseStorageService.resolveMediaUrl(msg.mediaPath);
                final isNetwork = resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://');
                final isLocal = msg.mediaPath.isNotEmpty && File(msg.mediaPath).existsSync();

                Widget imageWidget;
                if (isNetwork) {
                  imageWidget = Image.network(
                    resolvedUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.white24,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.white24,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 48),
                        ),
                      );
                    },
                  );
                } else if (isLocal) {
                  imageWidget = Image.file(
                    File(msg.mediaPath),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  );
                } else {
                  imageWidget = Container(
                    height: 140,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.image_rounded, color: Colors.white, size: 48),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _openImageViewer(msg),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageWidget,
                      ),
                    ),
                    if (msg.text.isNotEmpty && msg.text != '📷 Photo') ...[
                      const SizedBox(height: 6),
                      Text(
                        msg.text,
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                );
              },
            ),
          MessageType.file => GestureDetector(
              onTap: () async {
                final resolvedUrl = SupabaseStorageService.resolveMediaUrl(msg.mediaPath);
                if (resolvedUrl.isNotEmpty) {
                  final uri = Uri.parse(resolvedUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.fileName.isNotEmpty ? msg.fileName : msg.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (msg.fileSize.isNotEmpty)
                          Text(
                            msg.fileSize,
                            style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          MessageType.contact => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      msg.contactName.isNotEmpty ? msg.contactName : 'Shared Contact',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  msg.contactPhone,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          MessageType.location => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Location Shared',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  msg.locationAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          MessageType.audio => Builder(builder: (context) {
              final isThisPlaying = _isPlayingAudio && _currentlyPlayingMsgId == msg.id;
              final seconds = msg.audioDurationSeconds > 0 ? msg.audioDurationSeconds : 5;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _playVoiceNote(msg.id, msg.mediaPath),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.graphic_eq_rounded, color: isThisPlaying ? Colors.yellowAccent : Colors.white70, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            isThisPlaying ? 'Playing...' : 'Voice Message',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '0:$seconds',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              );
            }),
          MessageType.text => Text(
              msg.text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.3,
              ),
            ),
        },

        if (msg.isEdited)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Edited',
              style: TextStyle(color: Colors.white70, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ),

        // Sent-at + delivery ticks live INSIDE the outgoing bubble so they can
        // never be pushed off-screen or lost next to the bubble.
        if (isMe)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 6),
                _buildCheckMarkIcon(msg),
              ],
            ),
          ),
      ],
    );
  }
}
