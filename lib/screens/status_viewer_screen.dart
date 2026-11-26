import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/status_model.dart';
import '../models/user_profile_model.dart';
import '../services/image_cache_service.dart';
import '../services/status_cache_service.dart';
import '../services/status_service.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';


class StatusViewerScreen extends StatefulWidget {
  final List<StatusModel> statuses;
  final int initialIndex;
  final String userName;

  /// Firebase UID of the status owner (status.userId). Used to load the
  /// owner's current profile — never the logged-in user's profile.
  final String ownerUserId;
  final String ownerAvatar;
  final bool isMe;

  const StatusViewerScreen({
    super.key,
    required this.statuses,
    this.initialIndex = 0,
    required this.userName,
    this.ownerUserId = '',
    this.ownerAvatar = '',
    this.isMe = false,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  late int _currentIndex;
  final StatusService _statusService = StatusService();
  final StatusCacheService _statusCache = StatusCacheService.instance;
  final _firebaseService = FirebaseService();
  late final Stream<UserProfile> _ownerProfileStream;

  /// statusId → source actually played (local cached file once the status
  /// has been downloaded, otherwise the original URL).
  final Map<String, String> _mediaSources = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _ownerProfileStream = _firebaseService.watchUserProfile(
      widget.ownerUserId.isNotEmpty
          ? widget.ownerUserId
          : (widget.statuses.isNotEmpty
              ? widget.statuses.first.ownerKey
              : ''),
    );
    _pageController = PageController(initialPage: _currentIndex);

    // Duration will be overridden by video widget if needed
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStatus();
      }
    });

    _markCurrentAsViewed();
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _markCurrentAsViewed() {
    if (widget.statuses.isNotEmpty && _currentIndex < widget.statuses.length) {
      final currentStatus = widget.statuses[_currentIndex];
      final viewerId = _firebaseService.currentUid;
      if (viewerId.isNotEmpty) {
        _statusService.markStatusAsViewed(currentStatus.id, viewerId);
      }

      // Play once → keep an offline copy (WhatsApp behaviour).
      _prepareSource(currentStatus);
      if (_currentIndex + 1 < widget.statuses.length) {
        _prepareSource(widget.statuses[_currentIndex + 1]);
      }
    }
  }

  /// Resolves what to play for [status]: a previously downloaded copy when
  /// one exists (so the status still works with no network), otherwise the
  /// remote URL. When only the remote URL is available the download is
  /// started in the background for the next offline viewing.
  Future<void> _prepareSource(StatusModel status) async {
    if (status.id.isEmpty) return;

    final file = await _statusCache.fileFor(status);
    final source = file?.path ?? status.mediaUrl;

    if (!mounted || _mediaSources[status.id] == source) return;
    setState(() => _mediaSources[status.id] = source);

    if (file == null) {
      unawaited(_statusCache.cache(status));
    }
  }

  String? _sourceFor(StatusModel status) {
    if (status.id.isEmpty) return status.mediaUrl;
    return _mediaSources[status.id];
  }

  void _nextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animController.reset();
      _markCurrentAsViewed();
      _animController.forward();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStatus() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animController.reset();
      _markCurrentAsViewed();
      _animController.forward();
    } else {
      _animController.reset();
      _animController.forward();
    }
  }

  void _showViewersSheet(StatusModel status) {
    _animController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ViewersSheet(
        status: status,
        statusService: _statusService,
        ownerId: _firebaseService.currentUid,
        formatTimestamp: _formatTimestamp,
      ),
    ).then((_) {
      if (mounted) _animController.forward();
    });
  }

  Future<void> _confirmDeleteStatus(StatusModel status) async {
    _animController.stop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Status?'),
          content: const Text('Are you sure you want to delete this status update?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await _statusService.deleteStatus(status.id, status.mediaUrl);
      await _statusCache.remove(status.id);
      _mediaSources.remove(status.id);
      if (mounted) {
        Navigator.pop(context);
      }
    } else if (mounted) {
      _animController.forward();
    }
  }

  /// Formats a local DateTime into a human-readable relative string.
  /// Uses the local representation of the timestamp — no manual UTC offset.
  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    // Ensure we compare in the same timezone — both should be local
    final localDt = dt.isUtc ? dt.toLocal() : dt;
    final diff = now.difference(localDt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Older: show date
    return '${localDt.day}/${localDt.month}/${localDt.year}';
  }

  /// Determines if a status URL/type should be treated as video
  bool _isVideoStatus(StatusModel status) {
    final url = status.mediaUrl.toLowerCase();
    return status.mediaType == StatusMediaType.video ||
        url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.endsWith('.webm') ||
        url.contains('/mp4') ||
        status.mediaUrl.startsWith('data:video');
  }

  Widget _buildMediaWidget(StatusModel status) {
    final source = _sourceFor(status);
    // Source not resolved yet (offline copy still being looked up).
    if (source == null) return const StatusLoadingIndicator();

    if (_isVideoStatus(status)) {
      return StatusVideoWidget(
        key: ValueKey('video_${status.id}_$source'),
        url: source,
        onVideoReady: (duration) {
          // Sync the progress bar with video length
          if (mounted && duration.inSeconds > 0) {
            _animController.duration = duration;
            if (_animController.isAnimating) {
              _animController.reset();
              _animController.forward();
            }
          }
        },
      );
    }
    return _buildImageWidget(source);
  }

  Widget _buildImageWidget(String url) {
    // Base64 image
    if (url.startsWith('data:image')) {
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _buildErrorWidget('Failed to render status image.'),
        );
      } catch (_) {
        return _buildErrorWidget('Corrupted status image.');
      }
    }

    // Network image — animated loader until the first frame arrives
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        // Loader while the (possibly slow) download is still running
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame == null) {
            return const StatusLoadingIndicator();
          }
          return child;
        },
        errorBuilder: (_, __, ___) =>
            _buildErrorWidget('Failed to load image.\nCheck your internet connection.'),
      );
    }

    // Local file
    if (url.isNotEmpty) {
      try {
        final file = File(url);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            // Loader while the first frame is being decoded
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame == null) {
                return const StatusLoadingIndicator();
              }
              return child;
            },
            errorBuilder: (_, __, ___) => _buildErrorWidget('Unable to load local file.'),
          );
        }
      } catch (_) {}
    }

    return _buildErrorWidget(
      url.isEmpty ? 'No media available.' : 'Media not found.\nPlease delete and re-upload this status.',
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_rounded, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final currentStatus = widget.statuses[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 3) {
              _previousStatus();
            } else {
              _nextStatus();
            }
          },
          onLongPressStart: (_) => _animController.stop(),
          onLongPressEnd: (_) => _animController.forward(),
          child: Stack(
            children: [
              // 1. Media Page View
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.statuses.length,
                itemBuilder: (context, index) => _buildMediaWidget(widget.statuses[index]),
              ),

              // 2. Top Bar
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Column(
                  children: [
                    Row(
                      children: List.generate(widget.statuses.length, (idx) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: AnimatedBuilder(
                              animation: _animController,
                              builder: (context, _) {
                                double progress = 0.0;
                                if (idx < _currentIndex) {
                                  progress = 1.0;
                                } else if (idx == _currentIndex) {
                                  progress = _animController.value;
                                }
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 3,
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        ),
                        StreamBuilder<UserProfile>(
                          stream: _ownerProfileStream,
                          builder: (context, profileSnap) {
                            final profile = profileSnap.data;
                            final avatarUrl = (profile != null && profile.hasImage)
                                ? profile.imagePath
                                : widget.ownerAvatar;
                            final isNetwork = avatarUrl.startsWith('http://') ||
                                avatarUrl.startsWith('https://');
                            return CircleAvatar(
                              backgroundColor: AppColors.avatarPeach,
                              radius: 18,
                              backgroundImage:
                                  isNetwork
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                              child: isNetwork
                                  ? null
                                  : const Icon(Icons.person,
                                      color: AppColors.titleText, size: 20),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isMe ? 'My Status' : widget.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatTimestamp(currentStatus.createdAt),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isMe)
                          IconButton(
                            onPressed: () => _confirmDeleteStatus(currentStatus),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.white, size: 24),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. Caption
              if (currentStatus.caption.isNotEmpty)
                Positioned(
                  bottom: widget.isMe ? 85 : 40,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      currentStatus.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // 4. View Count (owner only)
              if (widget.isMe)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _StatusViewCountButton(
                      status: currentStatus,
                      statusService: _statusService,
                      onTap: () => _showViewersSheet(currentStatus),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Instant Video Player Widget
// - Controller initialized once on mount
// - No visible spinner; shows video as soon as first frame is ready
// - Notifies parent of video duration to sync progress bar
// ─────────────────────────────────────────────────────────────────────────────
class StatusVideoWidget extends StatefulWidget {
  final String url;
  final void Function(Duration duration)? onVideoReady;

  const StatusVideoWidget({
    super.key,
    required this.url,
    this.onVideoReady,
  });

  @override
  State<StatusVideoWidget> createState() => _StatusVideoWidgetState();
}

class _StatusVideoWidgetState extends State<StatusVideoWidget> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      VideoPlayerController ctrl;
      if (widget.url.startsWith('http://') || widget.url.startsWith('https://')) {
        ctrl = VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else if (widget.url.startsWith('data:video')) {
        // Base64 video — save to temp file
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/status_tmp_${DateTime.now().millisecondsSinceEpoch}.mp4');
        final base64Data = widget.url.split(',').last;
        await tempFile.writeAsBytes(base64Decode(base64Data));
        ctrl = VideoPlayerController.file(tempFile);
      } else {
        ctrl = VideoPlayerController.file(File(widget.url));
      }

      _controller = ctrl;
      await ctrl.initialize();

      if (!mounted) {
        ctrl.dispose();
        return;
      }

      ctrl.setLooping(true);
      await ctrl.play();

      widget.onVideoReady?.call(ctrl.value.duration);

      setState(() => _isReady = true);
    } catch (e) {
      debugPrint('StatusVideoWidget error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = e.toString().contains('Source error') || e.toString().contains('404')
              ? 'Video could not be loaded.\nCheck that the file exists in Supabase Storage.'
              : 'Unable to play this video.';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Animated loader while the video buffers/initializes (slow network)
    if (!_isReady || _controller == null) {
      return const StatusLoadingIndicator();
    }

    // Video is ready — render it
    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated loader — shown while status media is still being fetched
// ─────────────────────────────────────────────────────────────────────────────
class StatusLoadingIndicator extends StatefulWidget {
  const StatusLoadingIndicator({super.key});

  @override
  State<StatusLoadingIndicator> createState() => _StatusLoadingIndicatorState();
}

class _StatusLoadingIndicatorState extends State<StatusLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: const Text(
              'Loading…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Count Button — loads real count from Supabase status_views
// ─────────────────────────────────────────────────────────────────────────────
class _StatusViewCountButton extends StatelessWidget {
  final StatusModel status;
  final StatusService statusService;
  final VoidCallback onTap;

  const _StatusViewCountButton({
    required this.status,
    required this.statusService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: statusService.getViewCount(status.id),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$count views',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewers Sheet — loads viewer list from Supabase status_views table
// ─────────────────────────────────────────────────────────────────────────────
class _ViewersSheet extends StatefulWidget {
  final StatusModel status;
  final StatusService statusService;
  final String ownerId;
  final String Function(DateTime) formatTimestamp;

  const _ViewersSheet({
    required this.status,
    required this.statusService,
    required this.ownerId,
    required this.formatTimestamp,
  });

  @override
  State<_ViewersSheet> createState() => _ViewersSheetState();
}

class _ViewersSheetState extends State<_ViewersSheet> {
  List<StatusViewer>? _viewers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final viewers = await widget.statusService
        .getStatusViewers(widget.status.id, widget.ownerId);
    if (mounted) {
      setState(() {
        _viewers = viewers;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _viewers?.length ?? 0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.remove_red_eye_rounded,
                        color: AppColors.accentCoral),
                    const SizedBox(width: 8),
                    Text(
                      _loading ? 'Loading views...' : '$count views',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              // Viewer list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentCoral))
                    : (_viewers == null || _viewers!.isEmpty)
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No views yet',
                                style: TextStyle(
                                    color: AppColors.subtitleText,
                                    fontSize: 15),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: _viewers!.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 72),
                            itemBuilder: (context, idx) {
                              final viewer = _viewers![idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.avatarPeach,
                                  child: viewer.avatarUrl.isNotEmpty
                                      ? ClipOval(
                                          child: Image(
                                            image:
                                                CachedNetworkImageProvider(
                                                    viewer.avatarUrl),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.person,
                                                    color: AppColors.titleText),
                                          ),
                                        )
                                      : const Icon(Icons.person,
                                          color: AppColors.titleText),
                                ),
                                title: Text(
                                  viewer.displayName.isNotEmpty
                                      ? viewer.displayName
                                      : viewer.viewerUserId,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  widget.formatTimestamp(viewer.viewedAt),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.subtitleText),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
