part of '../message_bubble.dart';

extension _MessageBubbleVideoMediaBubble on _MessageBubbleBase {
  Widget _videoBubble(
    BuildContext context,
    ShortVideoMessage video,
    MessageStyleConfig style,
  ) {
    final previewSize = _videoPreviewSize(video);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: previewSize.width,
        height: previewSize.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _videoThumbnail(context, video, style),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
            Center(
              child: ChatUIAsset.image(
                'sight_message_play.png',
                width: kBubbleSightIconSize,
                height: kBubbleSightIconSize,
              ),
            ),
            if ((video.duration ?? 0) > 0)
              Positioned(
                right: 8,
                bottom: 6,
                child: Text(
                  _durationText(video.duration ?? 0),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Size _videoPreviewSize(ShortVideoMessage video) {
    var natural = ChatUIImageUtil.getCachedBase64NaturalSize(
      _readNullableString(() => video.thumbnailBase64String),
    );
    if (natural == null) {
      final localPath = _readNullableString(() => video.localPath);
      if (localPath != null &&
          localPath.isNotEmpty &&
          !_isNetworkVideoPath(localPath)) {
        natural = ChatUIImageUtil.getFileNaturalSize(localPath);
      }
    }
    final ratio = natural != null && natural.width > 0 && natural.height > 0
        ? natural.width / natural.height
        : 1.0;
    // Align iOS Nexconn ChatUI's NCSightMessageCell: preserve the thumbnail
    // ratio and cap the long side at 160 logical pixels.
    const maxLongSide = 160.0;
    var width = maxLongSide;
    var height = width / ratio;
    if (height > maxLongSide) {
      height = maxLongSide;
      width = height * ratio;
    }
    return Size(width, height);
  }

  Widget _videoThumbnail(
    BuildContext context,
    ShortVideoMessage video,
    MessageStyleConfig style,
  ) {
    final thumbnailBytes = ChatUIImageUtil.getDecodedBase64(
      _readNullableString(() => video.thumbnailBase64String),
    );
    final cacheSize = _previewCacheSize(context, _videoPreviewSize(video));
    if (thumbnailBytes != null) {
      return Image(
        image: ResizeImage.resizeIfNeeded(
          cacheSize.width,
          cacheSize.height,
          MemoryImage(thumbnailBytes),
        ),
        fit: BoxFit.cover,
      );
    }
    final path =
        _readNullableString(() => video.localPath) ??
        _readNullableString(() => video.remotePath);
    if (path != null && path.isNotEmpty && !_isNetworkVideoPath(path)) {
      return _previewImage(context, path, style, cacheSize: cacheSize);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF333333)),
      child: Center(
        child: ChatUIAsset.image(
          'NexconnLightIcon/Video-play.png',
          width: 44,
          height: 44,
        ),
      ),
    );
  }

  String? _readNullableString(String? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _readNullableInt(int? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return null;
    }
  }

  Widget _previewImage(
    BuildContext context,
    String path,
    MessageStyleConfig style, {
    BoxFit fit = BoxFit.cover,
    _ImageCacheSize? cacheSize,
    bool preferAnimation = false,
    Widget? loadingPlaceholder,
    Widget? errorFallback,
  }) {
    Widget errorBuilder(_, __, ___) {
      return errorFallback ??
          _mediaLabel(
            'NexconnLightIcon/Thumbnail-failed.png',
            messageSummary(message, localizations: context.chatUIL10n),
            style,
          );
    }

    if (_isNetworkPath(path)) {
      if (preferAnimation) {
        return Image.network(
          path,
          fit: fit,
          errorBuilder: errorBuilder,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return loadingPlaceholder ?? _mediaLoadingPlaceholder(style);
          },
        );
      }
      return Image(
        image: ResizeImage.resizeIfNeeded(
          cacheSize?.width,
          cacheSize?.height,
          CachedNetworkImageProvider(path),
        ),
        fit: fit,
        errorBuilder: errorBuilder,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return loadingPlaceholder ?? _mediaLoadingPlaceholder(style);
        },
      );
    }
    if (preferAnimation) {
      return Image.file(
        _localFile(path),
        fit: fit,
        errorBuilder: errorBuilder,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return child;
          }
          return loadingPlaceholder ?? _mediaLoadingPlaceholder(style);
        },
      );
    }
    return Image(
      image: ResizeImage.resizeIfNeeded(
        cacheSize?.width,
        cacheSize?.height,
        FileImage(_localFile(path)),
      ),
      fit: fit,
      errorBuilder: errorBuilder,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return loadingPlaceholder ?? _mediaLoadingPlaceholder(style);
      },
    );
  }

  Widget _mediaLoadingPlaceholder(MessageStyleConfig style) {
    return DecoratedBox(
      decoration: BoxDecoration(color: style.backgroundColor),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: style.textColor.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  bool _isNetworkVideoPath(String path) {
    return _isNetworkPath(path) &&
        path.toLowerCase().contains(RegExp(r'\.(mp4|mov|m4v|webm)(\?|$)'));
  }
}
