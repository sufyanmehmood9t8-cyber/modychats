import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/status_model.dart';

/// WhatsApp-style local cache for status media.
///
/// The first time a status is played (online) its media is copied into
/// `<documents>/status_cache/`, so the very same status can be re-watched
/// later without any network. Copies are dropped again when the status is
/// deleted or when it has outlived its 24h expiry window.
class StatusCacheService {
  StatusCacheService._();
  static final StatusCacheService instance = StatusCacheService._();

  /// Hard cap so a huge video cannot fill the phone's storage.
  static const int _maxBytes = 100 * 1024 * 1024;

  /// Statuses live 24h — keep the offline copy a little bit longer.
  static const Duration _maxAge = Duration(hours: 26);

  static const String _folderName = 'status_cache';

  Directory? _dir;

  /// Guards against double-downloading the same status at once.
  final Set<String> _inFlight = {};

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  String _sanitizedId(String statusId) =>
      statusId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  String _extension(StatusModel status) {
    if (status.mediaType == StatusMediaType.video) return 'mp4';
    final url = status.mediaUrl.toLowerCase().split('?').first;
    if (url.endsWith('.png')) return 'png';
    if (url.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  Future<File> _targetFile(StatusModel status) async {
    final dir = await _directory();
    return File('${dir.path}/${_sanitizedId(status.id)}.${_extension(status)}');
  }

  /// Returns the downloaded copy of [status], or null when it was never
  /// played (or the copy was already cleaned up).
  Future<File?> fileFor(StatusModel status) async {
    if (status.id.isEmpty) return null;
    try {
      final file = await _targetFile(status);
      if (await file.exists() && await file.length() > 0) return file;
      return null;
    } catch (e) {
      debugPrint('StatusCache.fileFor error: $e');
      return null;
    }
  }

  /// Downloads the media of [status] into the local cache so it stays
  /// available offline. Silently does nothing for base64/local sources,
  /// already-cached statuses, oversized files or network failures.
  Future<void> cache(StatusModel status) async {
    final url = status.mediaUrl;
    if (status.id.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return;

    final key = '${status.id}#$url';
    if (!_inFlight.add(key)) return;

    File? partial;
    try {
      if (await fileFor(status) != null) return;

      final target = await _targetFile(status);
      partial = File('${target.path}.part');

      final client = http.Client();
      try {
        final response = await client
            .send(http.Request('GET', Uri.parse(url)))
            .timeout(const Duration(seconds: 90));
        if (response.statusCode != 200) return;
        if (response.contentLength != null &&
            response.contentLength! > _maxBytes) {
          return;
        }

        final sink = partial.openWrite();
        var written = 0;
        try {
          await for (final chunk in response.stream) {
            written += chunk.length;
            if (written > _maxBytes) break;
            sink.add(chunk);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }

        if (written <= 0 || written > _maxBytes) {
          if (await partial.exists()) await partial.delete();
          return;
        }

        if (await target.exists()) await target.delete();
        await partial.rename(target.path);
        partial = null;
        debugPrint('Status cached offline: ${target.path} ($written bytes)');
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('StatusCache.cache error: $e');
    } finally {
      _inFlight.remove(key);
      if (partial != null) {
        try {
          if (await partial.exists()) await partial.delete();
        } catch (_) {}
      }
    }
  }

  /// Drops the offline copy of one status (used after the user deletes it).
  Future<void> remove(String statusId) async {
    if (statusId.isEmpty) return;
    try {
      final dir = await _directory();
      final prefix = _sanitizedId(statusId);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name == prefix || name.startsWith('$prefix.')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('StatusCache.remove error: $e');
    }
  }

  /// Deletes copies whose status has expired (or that are otherwise stale).
  Future<void> purgeExpired() async {
    try {
      final dir = await _directory();
      final cutoff = DateTime.now().subtract(_maxAge);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('StatusCache.purgeExpired error: $e');
    }
  }
}
