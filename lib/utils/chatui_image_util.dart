import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart' as image_size_getter;

class ChatUIImageUtil {
  static const int _maxBase64CacheEntries = 200;
  static const int _maxSizeCacheEntries = 200;
  static const double referenceThumbnailDefaultMaxSize = 120;
  static const double referenceThumbnailDefaultMinSize = 50;

  static final LinkedHashMap<String, Uint8List> _base64Cache =
      LinkedHashMap<String, Uint8List>();
  static final LinkedHashMap<String, ui.Size> _base64SizeCache =
      LinkedHashMap<String, ui.Size>();
  static final LinkedHashMap<String, ui.Size> _fileSizeCache =
      LinkedHashMap<String, ui.Size>();

  static Uint8List? getDecodedBase64(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final cached = _base64Cache.remove(value);
    if (cached != null) {
      _base64Cache[value] = cached;
      return cached;
    }
    try {
      final bytes = base64Decode(value);
      _base64Cache[value] = bytes;
      _trimCache(_base64Cache, _maxBase64CacheEntries);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? getCachedDecodedBase64(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final cached = _base64Cache.remove(value);
    if (cached != null) {
      _base64Cache[value] = cached;
    }
    return cached;
  }

  static ui.Size? getCachedBase64NaturalSize(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final cached = _base64SizeCache.remove(value);
    if (cached != null) {
      _base64SizeCache[value] = cached;
    }
    return cached;
  }

  static ui.Size? getBase64NaturalSize(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final cached = _base64SizeCache.remove(value);
    if (cached != null) {
      _base64SizeCache[value] = cached;
      return cached;
    }
    final bytes = getDecodedBase64(value);
    if (bytes == null) {
      return null;
    }
    try {
      final result = image_size_getter.ImageSizeGetter.getSizeResult(
        image_size_getter.MemoryInput(bytes),
      );
      final size = ui.Size(
        result.size.width.toDouble(),
        result.size.height.toDouble(),
      );
      _base64SizeCache[value] = size;
      _trimCache(_base64SizeCache, _maxSizeCacheEntries);
      return size;
    } catch (_) {
      return null;
    }
  }

  static ui.Size? getFileNaturalSize(String? path) {
    if (kIsWeb || path == null || path.isEmpty) {
      return null;
    }
    final normalizedPath = _normalizeFilePath(path);
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }
    final cached = _fileSizeCache.remove(normalizedPath);
    if (cached != null) {
      _fileSizeCache[normalizedPath] = cached;
      return cached;
    }
    try {
      final file = File(normalizedPath);
      if (!file.existsSync()) {
        return null;
      }
      final result = image_size_getter.ImageSizeGetter.getSizeResult(
        FileInput(file),
      );
      final size = ui.Size(
        result.size.width.toDouble(),
        result.size.height.toDouble(),
      );
      _fileSizeCache[normalizedPath] = size;
      _trimCache(_fileSizeCache, _maxSizeCacheEntries);
      return size;
    } catch (_) {
      return null;
    }
  }

  static ui.Size referenceThumbnailDisplaySize(
    double width,
    double height, {
    double maxLength = referenceThumbnailDefaultMaxSize,
    double minLength = referenceThumbnailDefaultMinSize,
  }) {
    if (width <= 0 || height <= 0) {
      return ui.Size(maxLength, minLength);
    }
    if (width < minLength || height < minLength) {
      return _referenceThumbnailBelowStandardSize(
        width,
        height,
        minLength,
        maxLength,
      );
    }
    if (width < maxLength &&
        height < maxLength &&
        width >= minLength &&
        height >= minLength) {
      return width > height
          ? ui.Size(maxLength, maxLength * height / width)
          : ui.Size(maxLength * width / height, maxLength);
    }
    if (width >= maxLength || height >= maxLength) {
      return _referenceThumbnailAboveStandardSize(
        width,
        height,
        minLength,
        maxLength,
      );
    }
    return ui.Size(maxLength, minLength);
  }

  static ui.Size referenceThumbnailDisplaySizeForRatio(
    double ratio, {
    double maxLength = referenceThumbnailDefaultMaxSize,
    double minLength = referenceThumbnailDefaultMinSize,
  }) {
    final normalizedRatio = ratio > 0 ? ratio : 1.0;
    final width = maxLength;
    final height = width / normalizedRatio;
    return referenceThumbnailDisplaySize(
      width,
      height,
      maxLength: maxLength,
      minLength: minLength,
    );
  }

  static String? _normalizeFilePath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') {
      return uri.toFilePath();
    }
    return path;
  }

  static void _trimCache<K, V>(LinkedHashMap<K, V> cache, int maxEntries) {
    while (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
  }

  static ui.Size _referenceThumbnailBelowStandardSize(
    double width,
    double height,
    double minLength,
    double maxLength,
  ) {
    if (width < height) {
      final scaledHeight = minLength * height / width;
      return ui.Size(
        minLength,
        scaledHeight > maxLength ? maxLength : scaledHeight,
      );
    }
    final scaledWidth = minLength * width / height;
    return ui.Size(
      scaledWidth > maxLength ? maxLength : scaledWidth,
      minLength,
    );
  }

  static ui.Size _referenceThumbnailAboveStandardSize(
    double width,
    double height,
    double minLength,
    double maxLength,
  ) {
    if (width > height) {
      if (width / height < maxLength / minLength) {
        return ui.Size(maxLength, maxLength * height / width);
      }
      final scaledWidth = minLength * width / height;
      return ui.Size(
        scaledWidth > maxLength ? maxLength : scaledWidth,
        minLength,
      );
    }
    if (height / width < maxLength / minLength) {
      return ui.Size(maxLength * width / height, maxLength);
    }
    final scaledHeight = minLength * height / width;
    return ui.Size(
      minLength,
      scaledHeight > maxLength ? maxLength : scaledHeight,
    );
  }
}
