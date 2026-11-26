import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Disk-backed replacement for `NetworkImage`, used for profile pictures.
///
/// The first successful download is stored in `<documents>/image_cache/`, so
/// every later display — including while the phone is offline — reads the
/// local copy (WhatsApp behaviour). Only when there is neither a local copy
/// nor a network does the provider fail, which surfaces as the usual
/// `errorBuilder` / fallback icon.
class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  CachedNetworkImageProvider(this.url, {this.scale = 1.0});

  /// Remote URL of the picture.
  final String url;

  /// Scale of the decoded image.
  final double scale;

  static const String _folderName = 'image_cache';
  static const int _maxBytes = 15 * 1024 * 1024;
  static const Duration _maxAge = Duration(days: 30);

  static Directory? _dir;

  /// Deduplicates concurrent downloads of the same picture.
  static final Map<String, Future<Uint8List?>> _inFlight = {};

  @override
  Future<CachedNetworkImageProvider> obtainKey(
          ImageConfiguration configuration) =>
      SynchronousFuture<CachedNetworkImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(CachedNetworkImageProvider key,
      ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_load(key, decode));
  }

  Future<ImageInfo> _load(
      CachedNetworkImageProvider key, ImageDecoderCallback decode) async {
    final bytes = await _bytesFor(key.url);
    if (bytes == null) {
      throw NetworkImageLoadException(
        uri: Uri.parse(key.url),
        statusCode: 0,
      );
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image, scale: key.scale);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedNetworkImageProvider &&
          other.url == url &&
          other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  // ─── DISK CACHE ────────────────────────────────────────────────────────────

  static Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Stable 64-bit FNV-1a style hash → file name (independent of VM runs).
  static String _keyFor(String url) {
    var h1 = 0x811c9dc5;
    var h2 = 0x01000193;
    for (final unit in url.codeUnits) {
      h1 = 0xffffffff & ((h1 ^ unit) * 0x01000193);
      h2 = 0xffffffff & ((h2 ^ unit) * 0x01000197);
    }
    return '${h1.toRadixString(16).padLeft(8, '0')}'
        '${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<File> _localFile(String url) async {
    final dir = await _directory();
    return File('${dir.path}/${_keyFor(url)}.img');
  }

  /// Local copy first, otherwise download (and store for later offline use).
  static Future<Uint8List?> _bytesFor(String url) async {
    if (url.isEmpty) return null;

    File? file;
    try {
      file = await _localFile(url);
      if (await file.exists()) {
        final cached = await file.readAsBytes();
        if (cached.isNotEmpty) return cached;
      }
    } catch (_) {
      file = null;
    }

    final pending = _inFlight[url];
    if (pending != null) return pending;

    final future = _download(url, file);
    _inFlight[url] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(url);
    }
  }

  static Future<Uint8List?> _download(String url, File? file) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;

      final response =
          await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;

      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > _maxBytes) return null;

      if (file != null) unawaited(_save(file, bytes));
      return bytes;
    } catch (e) {
      debugPrint('ImageCache download failed ($url): $e');
      return null;
    }
  }

  static Future<void> _save(File file, Uint8List bytes) async {
    try {
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(bytes, flush: true);
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('ImageCache save error: $e');
    }
  }

  /// Drops pictures that have not been needed for a long time. Safe to call
  /// at every app start — failures are ignored.
  static Future<void> purgeOld() async {
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
    } catch (_) {}
  }
}
