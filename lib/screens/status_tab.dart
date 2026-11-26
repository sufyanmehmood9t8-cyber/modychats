import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/status_model.dart';
import '../models/user_profile_model.dart';
import '../services/firebase_service.dart';
import '../services/image_cache_service.dart';
import '../services/status_cache_service.dart';
import '../services/status_service.dart';
import '../theme/app_colors.dart';
import 'status_viewer_screen.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final StatusService _statusService = StatusService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    // Drop offline copies of statuses that already expired.
    StatusCacheService.instance.purgeExpired();
  }

  Future<void> _pickAndUploadStatus(ImageSource source, {required bool isVideo}) async {
    try {
      final XFile? pickedFile = isVideo
          ? await _picker.pickVideo(source: source)
          : await _picker.pickImage(source: source, imageQuality: 80);

      if (pickedFile == null) return;

      final File file = File(pickedFile.path);

      if (!mounted) return;

      // Ask for optional caption
      final String? caption = await _showCaptionDialog();
      if (caption == null) return; // User cancelled

      setState(() {
        _isUploading = true;
      });

      await _statusService.createStatus(
        mediaFile: file,
        mediaType: isVideo ? StatusMediaType.video : StatusMediaType.image,
        caption: caption,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status uploaded successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _showCaptionDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Status Caption', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Type a caption...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentCoral),
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Post Status', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddStatusOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Status Update',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleText,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOptionItem(
                    icon: Icons.camera_alt_rounded,
                    color: Colors.purple,
                    label: 'Camera Photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadStatus(ImageSource.camera, isVideo: false);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.photo_library_rounded,
                    color: Colors.blue,
                    label: 'Gallery Photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadStatus(ImageSource.gallery, isVideo: false);
                    },
                  ),
                  _buildOptionItem(
                    icon: Icons.videocam_rounded,
                    color: Colors.redAccent,
                    label: 'Video',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadStatus(ImageSource.gallery, isVideo: true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.titleText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.avatarPeach,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person,
        color: AppColors.titleText,
        size: 30,
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _statusService.currentUid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed "Status Updates" Header Title
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 38, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Updates',
                style: TextStyle(
                  color: AppColors.titleText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              if (_isUploading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.accentCoral,
                  ),
                ),
            ],
          ),
        ),

        // Scrollable Status Content
        Expanded(
          child: StreamBuilder<List<StatusModel>>(
            stream: _statusService.getMyActiveStatusesStream(currentUid),
            builder: (context, myStatusesSnap) {
              final myStatuses = myStatusesSnap.data ?? [];
              final hasMyStatuses = myStatuses.isNotEmpty;

              return StreamBuilder<List<UserStatusGroup>>(
                stream: _statusService.getRecentUpdatesStream(currentUid),
                builder: (context, recentUpdatesSnap) {
                  final recentGroups = recentUpdatesSnap.data ?? [];

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. MY STATUS TILE
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          if (hasMyStatuses) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StatusViewerScreen(
                                  statuses: myStatuses,
                                  userName: 'My Status',
                                  ownerUserId: currentUid,
                                  isMe: true,
                                ),
                              ),
                            );
                          } else {
                            _showAddStatusOptions(context);
                          }
                        },
                        leading: Stack(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: hasMyStatuses
                                    ? Border.all(color: AppColors.accentCoral, width: 2.5)
                                    : null,
                              ),
                              // My own current profile picture
                              child: StreamBuilder<UserProfile>(
                                stream: _firebaseService
                                    .watchUserProfile(currentUid),
                                builder: (context, myProfileSnap) {
                                  final profile = myProfileSnap.data;
                                  final picUrl =
                                      (profile != null && profile.hasImage)
                                          ? profile.imagePath
                                          : '';
                                  final isNetwork = picUrl
                                          .startsWith('http://') ||
                                      picUrl.startsWith('https://');
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.avatarPeach,
                                      borderRadius: BorderRadius.circular(16),
                                      image: isNetwork
                                          ? DecorationImage(
                                              image:
                                                  CachedNetworkImageProvider(
                                                      picUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: isNetwork
                                        ? null
                                        : const Icon(
                                            Icons.person,
                                            color: AppColors.titleText,
                                            size: 30,
                                          ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => _showAddStatusOptions(context),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.accentCoral,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: const Text(
                          'My Status',
                          style: TextStyle(
                            color: AppColors.titleText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          hasMyStatuses
                              ? 'Tap to view status updates (${myStatuses.length})'
                              : 'Tap to add status update',
                          style: const TextStyle(color: AppColors.subtitleText),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 2. RECENT UPDATES SECTION
                      const Text(
                        'Recent updates',
                        style: TextStyle(
                          color: AppColors.subtitleText,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (recentGroups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No recent status updates',
                              style: TextStyle(
                                color: AppColors.subtitleText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...recentGroups.map((group) {
                          final isAllViewed = group.isAllViewedBy(currentUid);

                          void openViewer() {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StatusViewerScreen(
                                  statuses: group.statuses,
                                  userName: group.displayName,
                                  ownerUserId: group.userId,
                                  ownerAvatar: group.userAvatar,
                                  isMe: false,
                                ),
                              ),
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: InkWell(
                              onTap: openViewer,
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isAllViewed
                                              ? Colors.grey[400]!
                                              : AppColors.accentCoral,
                                          width: 2.5,
                                        ),
                                      ),
                                      // Status owner's CURRENT profile
                                      // picture, loaded by status.userId.
                                      child: StreamBuilder<UserProfile>(
                                        stream: _firebaseService
                                            .watchUserProfile(group.userId),
                                        builder: (context, profileSnap) {
                                          final profile = profileSnap.data;
                                          final picUrl =
                                              (profile != null &&
                                                      profile.hasImage)
                                                  ? profile.imagePath
                                                  : group.userAvatar;
                                          final isNetwork =
                                              picUrl.startsWith('http://') ||
                                                  picUrl.startsWith('https://');

                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: isNetwork
                                                ? Image(
                                                    image:
                                                        CachedNetworkImageProvider(
                                                            picUrl),
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            _avatarFallback(),
                                                  )
                                                : _avatarFallback(),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.displayName,
                                            style: const TextStyle(
                                              color: AppColors.titleText,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(
                                                group.latestTimestamp),
                                            style: const TextStyle(
                                              color: AppColors.subtitleText,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
