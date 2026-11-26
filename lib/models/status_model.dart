import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusMediaType { image, video }

class StatusModel {
  final String id;
  final String userId;
  final String userPhone;
  final String userName;
  final String userAvatar;
  final String mediaUrl;
  final StatusMediaType mediaType;
  final String caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  // viewCount is now fetched separately from status_views table.
  // The viewers map is kept only for legacy compatibility — do not use for counting.
  final Map<String, DateTime> viewers;

  StatusModel({
    required this.id,
    required this.userId,
    required this.userPhone,
    this.userName = '',
    this.userAvatar = '',
    required this.mediaUrl,
    required this.mediaType,
    this.caption = '',
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Identity of the status owner. New rows use the Firebase UID in
  /// `userId`; older rows stored the phone number there, so both are accepted.
  String get ownerKey {
    final id = userId.toString().trim();
    if (id.isNotEmpty) return id;
    return userPhone.toString().trim();
  }

  // Legacy view count from old viewers map — kept for UI compat
  int get viewCount => viewers.length;

  bool isViewedBy(String currentUserId) => viewers.containsKey(currentUserId);

  factory StatusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // media type
    StatusMediaType type = StatusMediaType.image;
    final typeStr = (data['mediaType'] ?? 'image').toString().toLowerCase();
    if (typeStr == 'video') type = StatusMediaType.video;

    // ── createdAt resolution ──────────────────────────────────────────────
    // Priority:
    //   1. createdAtMs (int milliseconds) — always present immediately after write
    //   2. createdAt Timestamp — set by serverTimestamp, may be null on pending writes
    //   3. fallback to now
    DateTime created;
    if (data['createdAtMs'] is int) {
      // stored as UTC ms — convert to local
      created = DateTime.fromMillisecondsSinceEpoch(data['createdAtMs'] as int, isUtc: true).toLocal();
    } else if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate().toLocal();
    } else {
      created = DateTime.now();
    }

    // expiresAt
    DateTime expires = created.add(const Duration(hours: 24));
    if (data['expiresAt'] is Timestamp) {
      expires = (data['expiresAt'] as Timestamp).toDate().toLocal();
    } else if (data['expiresAt'] is int) {
      expires = DateTime.fromMillisecondsSinceEpoch(data['expiresAt'] as int, isUtc: true).toLocal();
    }

    // Legacy viewers map (not used for counting anymore)
    Map<String, DateTime> viewersMap = {};
    if (data['viewers'] is Map) {
      final raw = data['viewers'] as Map<String, dynamic>;
      raw.forEach((key, val) {
        viewersMap[key] = val is Timestamp ? val.toDate() : DateTime.now();
      });
    }

    return StatusModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userPhone: (data['userPhone'] ?? data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      userAvatar: (data['userAvatar'] ?? '').toString(),
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: type,
      caption: data['caption'] ?? '',
      createdAt: created,
      expiresAt: expires,
      viewers: viewersMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> rawViewers = {};
    viewers.forEach((key, val) {
      rawViewers[key] = Timestamp.fromDate(val);
    });

    return {
      'userId': userId,
      'userPhone': userPhone,
      'userName': userName,
      'userAvatar': userAvatar,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType == StatusMediaType.video ? 'video' : 'image',
      'caption': caption,
      'createdAtMs': createdAt.toUtc().millisecondsSinceEpoch,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewers': rawViewers,
    };
  }
}

class UserStatusGroup {
  /// The real identity of the status owner (status.userId — Firebase UID).
  final String userId;
  final String userPhone;
  final String displayName;
  final String userAvatar;
  final List<StatusModel> statuses;

  UserStatusGroup({
    required this.userId,
    required this.userPhone,
    required this.displayName,
    this.userAvatar = '',
    required this.statuses,
  });

  StatusModel get latestStatus => statuses.last;
  DateTime get latestTimestamp => latestStatus.createdAt;

  bool isAllViewedBy(String currentUserId) {
    return statuses.every((s) => s.isViewedBy(currentUserId));
  }
}
