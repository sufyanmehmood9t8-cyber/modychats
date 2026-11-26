import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/status_model.dart';
import '../models/user_profile_model.dart';
import 'firebase_service.dart';

/// StatusModel viewer — loaded from status_views table.
class StatusViewer {
  final String viewerUserId; // viewer identity (Firebase UID, legacy: phone)
  final DateTime viewedAt;
  String displayName;
  String avatarUrl;

  StatusViewer({
    required this.viewerUserId,
    required this.viewedAt,
    this.displayName = '',
    this.avatarUrl = '',
  });
}

class StatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  CollectionReference get _statusesRef => _firestore.collection('statuses');

  /// Real Firebase UID of the logged-in user.
  String get currentUid => _firebaseService.currentUid;

  // ─── Supabase REST credentials ────────────────────────────────────────────
  static const String _url = 'https://lljoixgiomrmhvhyaiva.supabase.co';
  static const String _key =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxsam9peGdpb21ybWh2aHlhaXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3OTEyNDMsImV4cCI6MjA4MTM2NzI0M30.Y5801BWzFoy41e3bqAFduFUowDzaIlCfnyfTZGWRRoI';
  static const String _bucket = 'statuses';

  Map<String, String> get _headers => {
        'apikey': _key,
        'Authorization': 'Bearer $_key',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  // ─── CREATE STATUS ────────────────────────────────────────────────────────

  Future<void> createStatus({
    required File mediaFile,
    required StatusMediaType mediaType,
    String caption = '',
  }) async {
    final currentPhone = FirebaseService.currentUserPhone;
    final currentName = FirebaseService.currentUserName;
    final statusId = 'status_${DateTime.now().millisecondsSinceEpoch}';

    // Use local UTC time — will be read back immediately and display correctly
    final now = DateTime.now().toUtc();
    final expires = now.add(const Duration(hours: 24));

    final cleanPhone = FirebaseService.normalizePhone(currentPhone);
    final ext = mediaType == StatusMediaType.video ? 'mp4' : 'jpg';
    final mimeType = mediaType == StatusMediaType.video ? 'video/mp4' : 'image/jpeg';
    final storagePath = '$cleanPhone/$statusId.$ext';

    String downloadUrl = '';

    // 1. Supabase Storage (primary)
    try {
      downloadUrl = await _uploadToSupabaseStorage(mediaFile, storagePath, mimeType);
      debugPrint('Status uploaded to Supabase Storage: $downloadUrl');
    } catch (supabaseErr) {
      debugPrint('Supabase err: $supabaseErr — trying fallback...');
      try {
        downloadUrl = await _uploadToVideoCloudStorage(mediaFile, mediaType);
      } catch (cloudErr) {
        try {
          downloadUrl = await _getCompressedBase64(mediaFile, mediaType);
        } catch (base64Err) {
          throw Exception('Upload failed: $base64Err');
        }
      }
    }

    if (downloadUrl.length > 900000) {
      throw Exception('Media too large for Firestore. Please check Supabase Storage RLS policies.');
    }

    // Status owner is identified by the real Firebase UID. Phone number is
    // kept as secondary metadata for legacy rows only.
    final currentUid = _firebaseService.currentUid;
    String currentAvatar = '';
    try {
      final profile = await _firebaseService.getUserProfileById(currentUid);
      if (profile != null) currentAvatar = profile.imagePath;
    } catch (_) {}

    // 2. Save to Firestore — store UTC createdAt as explicit int ms so it's
    //    always available immediately (no null pending-write delay).
    final statusData = {
      'userId': currentUid,
      'userPhone': currentPhone,
      'userName': currentName,
      'userAvatar': currentAvatar,
      'mediaUrl': downloadUrl,
      'mediaType': mediaType == StatusMediaType.video ? 'video' : 'image',
      'caption': caption,
      // Store as integer milliseconds — always present immediately on read
      'createdAtMs': now.millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(), // keep for queries
      'expiresAt': Timestamp.fromDate(expires.toLocal()),
      'viewers': {}, // legacy field, no longer used for counting
    };

    await _statusesRef.doc(statusId).set(statusData);
  }

  // ─── SUPABASE STORAGE UPLOAD ─────────────────────────────────────────────

  Future<String> _uploadToSupabaseStorage(File file, String path, String mimeType) async {
    final uploadUri = Uri.parse('$_url/storage/v1/object/$_bucket/$path');
    final bytes = await file.readAsBytes();

    final response = await http.post(
      uploadUri,
      headers: {
        'Authorization': 'Bearer $_key',
        'apikey': _key,
        'Content-Type': mimeType,
        'x-upsert': 'true',
      },
      body: bytes,
    ).timeout(const Duration(seconds: 60));

    debugPrint('Supabase Storage [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return '$_url/storage/v1/object/public/$_bucket/$path';
    }
    throw Exception('Supabase Storage ${response.statusCode}: ${response.body}');
  }

  Future<String> _uploadToVideoCloudStorage(File file, StatusMediaType mediaType) async {
    if (mediaType == StatusMediaType.image) {
      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=6d207e02198a847aa98d0a2a901485a5');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', file.path));
      final response = await request.send().timeout(const Duration(seconds: 30));
      final data = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final json = jsonDecode(data);
        final url = json['data']['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
    } else {
      final uri = Uri.parse('https://tmpfiles.org/api/v1/upload');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send().timeout(const Duration(seconds: 60));
      final data = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final json = jsonDecode(data);
        final rawUrl = json['data']?['url'] as String?;
        if (rawUrl != null && rawUrl.isNotEmpty) {
          return rawUrl.replaceFirst('tmpfiles.org/', 'tmpfiles.org/dl/');
        }
      }
    }
    throw Exception('Cloud fallback upload failed.');
  }

  Future<String> _getCompressedBase64(File file, StatusMediaType mediaType) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 850000) {
      throw Exception('File too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB) for Base64 fallback.');
    }
    final mime = mediaType == StatusMediaType.video ? 'video/mp4' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  // ─── STREAM: MY STATUSES ─────────────────────────────────────────────────

  /// True when a status belongs to the logged-in user. New rows are matched by
  /// Firebase UID; legacy rows stored the phone number in `userId`, so the
  /// current phone number is compared as well.
  bool _isOwnedByCurrentUser(StatusModel status, String currentUid) {
    if (status.ownerKey == currentUid) return true;
    return FirebaseService.normalizePhone(status.userPhone) ==
        FirebaseService.normalizePhone(FirebaseService.currentUserPhone);
  }

  Stream<List<StatusModel>> getMyActiveStatusesStream(String currentUid) {
    return _statusesRef.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StatusModel.fromFirestore(doc))
          .where((s) => _isOwnedByCurrentUser(s, currentUid) && !s.isExpired)
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  // ─── STREAM: RECENT UPDATES ───────────────────────────────────────────────
  // Grouped by the real status owner identity (status.userId) and enriched
  // with that user's current profile from the shared users collection.

  Stream<List<UserStatusGroup>> getRecentUpdatesStream(String currentUid) {
    return _statusesRef.snapshots().asyncMap((snapshot) async {
      final Map<String, List<StatusModel>> userStatusesMap = {};

      for (var doc in snapshot.docs) {
        final status = StatusModel.fromFirestore(doc);
        final ownerKey = status.ownerKey;
        if (ownerKey.isEmpty) continue;
        if (_isOwnedByCurrentUser(status, currentUid) || status.isExpired) {
          continue;
        }
        userStatusesMap.putIfAbsent(ownerKey, () => []).add(status);
      }

      final groups = <UserStatusGroup>[];
      for (final entry in userStatusesMap.entries) {
        final ownerKey = entry.key;
        final statusesList = entry.value
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Load the owner's live profile by status.userId
        UserProfile? profile;
        try {
          profile = await _firebaseService.getUserProfileById(ownerKey);
        } catch (_) {}

        groups.add(UserStatusGroup(
          userId: ownerKey,
          userPhone: statusesList.first.userPhone,
          displayName: (profile != null && profile.name.isNotEmpty)
              ? profile.name
              : (statusesList.first.userName.isNotEmpty
                  ? statusesList.first.userName
                  : ownerKey),
          userAvatar: (profile != null && profile.hasImage)
              ? profile.imagePath
              : statusesList.first.userAvatar,
          statuses: statusesList,
        ));
      }

      groups.sort((a, b) => b.latestTimestamp.compareTo(a.latestTimestamp));
      return groups;
    });
  }

  // ─── VIEW TRACKING (Supabase status_views table) ─────────────────────────

  /// Record that the current user viewed a status.
  /// - Silently ignores if viewer == owner.
  /// - Silently ignores duplicate (UNIQUE constraint on server side).
  Future<void> markStatusAsViewed(String statusId, String viewerId) async {
    final viewer = viewerId.trim();
    // Determine the status owner from Firestore to guard owner-view
    try {
      final doc = await _statusesRef.doc(statusId).get();
      if (!doc.exists) return;
      final status = StatusModel.fromFirestore(doc);
      if (status.ownerKey == viewer) return; // owner never counts as a view
      if (FirebaseService.normalizePhone(status.userPhone) ==
          FirebaseService.normalizePhone(FirebaseService.currentUserPhone)) {
        return;
      }
    } catch (e) {
      debugPrint('markStatusAsViewed owner check error: $e');
    }

    // Upsert into Supabase status_views (UNIQUE(status_id, viewer_user_id) prevents duplicates)
    try {
      final uri = Uri.parse('$_url/rest/v1/status_views');
      final response = await http.post(
        uri,
        headers: {
          ..._headers,
          'Prefer': 'resolution=ignore-duplicates',
        },
        body: jsonEncode({
          'status_id': statusId,
          'viewer_user_id': viewer,
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('markStatusAsViewed [${response.statusCode}]: ${response.body}');
    } catch (e) {
      debugPrint('markStatusAsViewed error (non-fatal): $e');
    }
  }

  /// Fetch viewers for a status from the status_views table.
  /// Returns list of StatusViewer enriched with the viewer's profile data.
  Future<List<StatusViewer>> getStatusViewers(
      String statusId, String ownerId) async {
    try {
      final uri = Uri.parse(
          '$_url/rest/v1/status_views?status_id=eq.$statusId&order=viewed_at.desc');
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('getStatusViewers error: ${response.statusCode} ${response.body}');
        return [];
      }

      final jsonList = jsonDecode(response.body) as List<dynamic>;
      final normOwner = FirebaseService.normalizePhone(ownerId);

      final viewers = <StatusViewer>[];
      for (final row in jsonList) {
        final viewerUserId = row['viewer_user_id'] as String? ?? '';
        // Guard: do not show owner in their own viewer list
        if (viewerUserId == ownerId ||
            FirebaseService.normalizePhone(viewerUserId) == normOwner) {
          continue;
        }

        final viewedAtStr = row['viewed_at'] as String? ?? '';
        DateTime viewedAt = DateTime.now();
        try {
          viewedAt = DateTime.parse(viewedAtStr).toLocal();
        } catch (_) {}

        viewers.add(StatusViewer(
          viewerUserId: viewerUserId,
          viewedAt: viewedAt,
          displayName: viewerUserId, // default, enriched below
        ));
      }

      // Enrich with the viewer's current profile from the users collection
      for (var v in viewers) {
        try {
          final profile =
              await _firebaseService.getUserProfileById(v.viewerUserId);
          if (profile == null) continue;
          if (profile.name.isNotEmpty) v.displayName = profile.name;
          if (profile.hasImage) v.avatarUrl = profile.imagePath;
        } catch (e) {
          debugPrint('Viewer profile enrichment error (non-fatal): $e');
        }
      }

      return viewers;
    } catch (e) {
      debugPrint('getStatusViewers exception: $e');
      return [];
    }
  }

  /// Get view count for a status from status_views table.
  Future<int> getViewCount(String statusId) async {
    try {
      final response = await http.head(
        Uri.parse('$_url/rest/v1/status_views?status_id=eq.$statusId'),
        headers: {
          ..._headers,
          'Prefer': 'count=exact',
        },
      ).timeout(const Duration(seconds: 10));

      final countHeader = response.headers['content-range'];
      if (countHeader != null && countHeader.contains('/')) {
        return int.tryParse(countHeader.split('/').last) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── DELETE STATUS ────────────────────────────────────────────────────────

  Future<void> deleteStatus(String statusId, String mediaUrl) async {
    // Delete view records first
    try {
      final uri = Uri.parse('$_url/rest/v1/status_views?status_id=eq.$statusId');
      await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('deleteStatus views error (non-fatal): $e');
    }
    // Delete Firestore doc
    try {
      await _statusesRef.doc(statusId).delete();
    } catch (e) {
      debugPrint('deleteStatus Firestore error: $e');
      rethrow;
    }
  }
}
