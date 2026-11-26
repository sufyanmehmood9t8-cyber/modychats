import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Raised when a Supabase Storage operation fails.
///
/// Uploads used to "succeed" silently: the failure was only printed and a
/// public URL was returned anyway, so the chat stored a broken media path and
/// the picture / document never appeared. Callers now get this exception with
/// the real reason and can tell the user what went wrong.
class SupabaseStorageException implements Exception {
  final String message;

  const SupabaseStorageException(this.message);

  @override
  String toString() => message;
}

class SupabaseStorageService {
  static const String _url = 'https://lljoixgiomrmhvhyaiva.supabase.co';
  static const String _key =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxsam9peGdpb21ybWh2aHlhaXZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3OTEyNDMsImV4cCI6MjA4MTM2NzI0M30.Y5801BWzFoy41e3bqAFduFUowDzaIlCfnyfTZGWRRoI';

  /// Buckets used by the app. All of them must exist AND be public, otherwise
  /// media can be uploaded but never read back.
  static const String chatMediaBucket = 'chat-media';
  static const String profileBucket = 'profiles';
  static const String statusBucket = 'statuses';

  static const Set<String> _knownBuckets = {
    chatMediaBucket,
    profileBucket,
    statusBucket,
  };

  static Map<String, String> get _headers => {
        'Authorization': 'Bearer $_key',
        'apikey': _key,
      };

  /// Publicly readable URL of a stored object.
  static String publicObjectUrl(String storagePath) =>
      '$_url/storage/v1/object/public/$storagePath';

  /// Whether the chat-media bucket exists on the project.
  ///
  /// A missing bucket is the single most common reason attachments never show
  /// up, so the UI can check it once and report the problem instead of sending
  /// a message whose media can never be loaded.
  static Future<bool> isChatMediaReady() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_url/storage/v1/object/list/$chatMediaBucket'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Supabase bucket probe failed: $e');
      return false;
    }
  }

  /// Upload a chat attachment file to Supabase Storage:
  /// chat-media/{conversationId}/{messageId}/{filename}
  ///
  /// Throws [SupabaseStorageException] when the upload fails.
  static Future<String> uploadChatMedia({
    required File file,
    required String conversationId,
    required String messageId,
    required String fileName,
    required String mimeType,
  }) async {
    final storagePath =
        '$chatMediaBucket/$conversationId/$messageId/$fileName';

    return _upload(
      storagePath: storagePath,
      file: file,
      mimeType: mimeType,
    );
  }

  /// Upload profile picture to Supabase Storage: profiles/{userId}/profile.jpg
  ///
  /// Throws [SupabaseStorageException] when the upload fails.
  static Future<String> uploadProfilePicture({
    required File file,
    required String userId,
  }) async {
    return _upload(
      storagePath: '$profileBucket/$userId/profile.jpg',
      file: file,
      mimeType: 'image/jpeg',
    );
  }

  /// Single upload path for every bucket, so a failure is never swallowed.
  static Future<String> _upload({
    required String storagePath,
    required File file,
    required String mimeType,
  }) async {
    final uploadUri = Uri.parse('$_url/storage/v1/object/$storagePath');

    final bytes = await file.readAsBytes();

    http.Response response;
    try {
      response = await http
          .post(
            uploadUri,
            headers: {
              ..._headers,
              'Content-Type':
                  mimeType.isNotEmpty ? mimeType : 'application/octet-stream',
              'x-upsert': 'true',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw SupabaseStorageException('Upload failed (no connection): $e');
    }

    debugPrint('Supabase Upload [$storagePath] [${response.statusCode}]');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SupabaseStorageException(describeFailure(response, storagePath));
    }

    return publicObjectUrl(storagePath);
  }

  /// Turns a failed upload response into a message that is actually useful.
  static String describeFailure(http.Response response, String storagePath) {
    var reason = 'HTTP ${response.statusCode}';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        reason = decoded['message'].toString();
      }
    } catch (_) {}

    final bucket = storagePath.split('/').first;
    if (response.statusCode == 404 || reason.contains('Bucket not found')) {
      return 'Storage bucket "$bucket" does not exist on the Supabase project.';
    }
    return 'Upload of $storagePath failed ($reason)';
  }

  /// Turn any stored media reference into something loadable.
  ///
  /// Older profile rows stored only the Supabase *storage path* (for example
  /// `profiles/923001234567/1712.jpg`) instead of a full URL. Those rows are
  /// resolved into the public object URL so avatars keep working, while
  /// already-correct values (full URLs, data URIs, local file paths) are
  /// returned untouched.
  static String resolveMediaUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';

    // Already a full URL, a data URI, or a local file path — leave as-is.
    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('data:') ||
        raw.startsWith('file://')) {
      return raw;
    }

    // Windows/Unix absolute local file path.
    if (raw.contains(r':\') || raw.startsWith('/')) return raw;

    // A bare storage path: profiles/... , statuses/... , chat-media/...
    if (RegExp(r'^[A-Za-z0-9_\-]+/[A-Za-z0-9_\-./]+$').hasMatch(raw)) {
      // A stored path that already carries its bucket must keep it. Prepending
      // a bucket to it (profiles/chat-media/...) produced URLs that always 404.
      final firstSegment = raw.split('/').first;
      final pathWithBucket =
          _knownBuckets.contains(firstSegment) ? raw : '$profileBucket/$raw';
      return publicObjectUrl(pathWithBucket);
    }

    return raw;
  }
}