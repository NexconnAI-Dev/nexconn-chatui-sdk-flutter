part of '../message_bubble.dart';

extension _MessageBubbleImageMessageMediaBubble on _MessageBubbleBase {
  Widget _imageBubble(
    BuildContext context,
    MediaMessage media,
    MessageStyleConfig style,
  ) {
    final previewConfig = config.bubbleConfig.imagePreviewConfig;
    if (_isGifMedia(media)) {
      return _gifBubble(context, media, style);
    }
    final thumbnailBase64 = media is ImageMessage
        ? _readNullableString(() => media.thumbnailBase64String)
        : null;
    final localPath = _readNullableString(() => media.localPath);
    final remotePath = _readNullableString(() => media.remotePath);
    final hasUsableLocalPreview = _hasUsableLocalPreviewPath(localPath);
    final previewPath = remotePath != null && remotePath.isNotEmpty
        ? remotePath
        : null;
    final size = _imagePreviewSize(media);
    final cacheSize = _previewCacheSize(context, size);
    final preferAnimation = media is GIFMessage;
    final thumbnailWidget =
        thumbnailBase64 != null && thumbnailBase64.isNotEmpty
        ? _DeferredBase64Thumbnail(
            thumbnailBase64: thumbnailBase64,
            cacheSize: cacheSize,
            fit: previewConfig.fit,
            placeholder: _mediaLoadingPlaceholder(style),
          )
        : null;
    final child = hasUsableLocalPreview
        ? _previewImage(
            context,
            localPath!,
            style,
            fit: previewConfig.fit,
            cacheSize: cacheSize,
            preferAnimation: preferAnimation,
          )
        : media is ImageMessage && previewPath != null && previewPath.isNotEmpty
        ? _previewImage(
            context,
            previewPath,
            style,
            fit: previewConfig.fit,
            cacheSize: cacheSize,
            preferAnimation: preferAnimation,
            loadingPlaceholder: thumbnailWidget,
            errorFallback: thumbnailWidget,
          )
        : thumbnailWidget ??
              (previewPath != null && previewPath.isNotEmpty
                  ? _previewImage(
                      context,
                      previewPath,
                      style,
                      fit: previewConfig.fit,
                      cacheSize: cacheSize,
                      preferAnimation: preferAnimation,
                    )
                  : _mediaLoadingPlaceholder(style));
    return GestureDetector(
      key: MessageBubble.mediaPreviewContentKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleMediaPreviewTap(context, media),
      child: Semantics(
        key: MessageBubble.mediaPreviewKey,
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(previewConfig.borderRadius),
            border: Border.all(color: const Color(0x14000000), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(previewConfig.borderRadius),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gifBubble(
    BuildContext context,
    MediaMessage media,
    MessageStyleConfig style,
  ) {
    final previewConfig = config.bubbleConfig.imagePreviewConfig;
    final localPath = _readNullableString(() => media.localPath);
    final remotePath = _readNullableString(() => media.remotePath);
    final previewPath = _hasUsableLocalPreviewPath(localPath)
        ? localPath
        : (remotePath != null && remotePath.isNotEmpty ? remotePath : null);
    final size = _imagePreviewSize(media);
    final child = previewPath != null
        ? _previewImage(
            context,
            previewPath,
            style,
            fit: previewConfig.fit,
            preferAnimation: true,
          )
        : _mediaLoadingPlaceholder(style);
    return GestureDetector(
      key: MessageBubble.mediaPreviewContentKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleMediaPreviewTap(context, media),
      child: Semantics(
        key: MessageBubble.mediaPreviewKey,
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(previewConfig.borderRadius),
            border: Border.all(color: const Color(0x14000000), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(previewConfig.borderRadius),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _referencedImagePreview(
    BuildContext context,
    ImageMessage image,
    MessageStyleConfig style,
  ) {
    final thumbnailBase64 = _readNullableString(
      () => image.thumbnailBase64String,
    );
    final localPath = _readNullableString(() => image.localPath);
    final remotePath = _readNullableString(() => image.remotePath);
    final size = _referencedImagePreviewSize(image, thumbnailBase64);
    final cacheSize = _previewCacheSize(context, size);
    final previewPath = _hasUsableLocalPreviewPath(localPath)
        ? localPath
        : (remotePath != null && remotePath.isNotEmpty ? remotePath : null);
    final previewWidget = previewPath != null
        ? _previewImage(
            context,
            previewPath,
            style,
            fit: BoxFit.cover,
            cacheSize: cacheSize,
            errorFallback: _mediaLoadingPlaceholder(style),
          )
        : _mediaLoadingPlaceholder(style);
    final child = thumbnailBase64 != null && thumbnailBase64.isNotEmpty
        ? _DeferredBase64Thumbnail(
            thumbnailBase64: thumbnailBase64,
            cacheSize: cacheSize,
            fit: BoxFit.cover,
            placeholder: previewWidget,
          )
        : previewWidget;
    return Align(
      alignment: Alignment.center,
      widthFactor: 1,
      heightFactor: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          key: MessageBubble.referenceImagePreviewKey,
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    );
  }

  bool _isGifMedia(MediaMessage media) {
    return media is GIFMessage || media.messageType == MessageType.gif;
  }

  bool _hasUsableLocalPreviewPath(String? localPath) {
    if (localPath == null || localPath.isEmpty || _isNetworkPath(localPath)) {
      return false;
    }
    final uri = Uri.tryParse(localPath);
    final file = uri != null && uri.scheme == 'file'
        ? File.fromUri(uri)
        : File(localPath);
    return file.existsSync();
  }

  Size _imagePreviewSize(MediaMessage media) {
    final previewConfig = config.bubbleConfig.imagePreviewConfig;
    double? width;
    double? height;
    final path =
        _readNullableString(() => media.localPath) ??
        _readNullableString(() => media.remotePath);
    if (media is ImageMessage) {
      width = _readNullableInt(() => media.thumWidth)?.toDouble();
      height = _readNullableInt(() => media.thumHeight)?.toDouble();
    } else if (media is GIFMessage) {
      width = _readNullableInt(() => media.width)?.toDouble();
      height = _readNullableInt(() => media.height)?.toDouble();
    }
    if (width == null || width <= 0 || height == null || height <= 0) {
      final size = ChatUIImageUtil.getCachedBase64NaturalSize(
        media is ImageMessage
            ? _readNullableString(() => media.thumbnailBase64String)
            : null,
      );
      width = size?.width;
      height = size?.height;
    }
    if ((width == null || width <= 0 || height == null || height <= 0) &&
        path != null &&
        path.isNotEmpty &&
        !_isNetworkPath(path)) {
      final size = ChatUIImageUtil.getFileNaturalSize(path);
      width = size?.width;
      height = size?.height;
    }
    final ratio = width != null && width > 0 && height != null && height > 0
        ? width / height
        : media is GIFMessage
        ? 1.0
        : 3 / 4;
    var previewWidth = previewConfig.maxWidth;
    var previewHeight = previewWidth / ratio;
    if (previewHeight > previewConfig.maxHeight) {
      previewHeight = previewConfig.maxHeight;
      previewWidth = previewHeight * ratio;
    }
    return Size(previewWidth, previewHeight);
  }

  Size _referencedImagePreviewSize(
    ImageMessage image,
    String? thumbnailBase64,
  ) {
    double? width = _readNullableInt(() => image.thumWidth)?.toDouble();
    double? height = _readNullableInt(() => image.thumHeight)?.toDouble();
    if (width == null || width <= 0 || height == null || height <= 0) {
      final size = ChatUIImageUtil.getCachedBase64NaturalSize(thumbnailBase64);
      width = size?.width;
      height = size?.height;
    }
    if (width != null && width > 0 && height != null && height > 0) {
      return ChatUIImageUtil.referenceThumbnailDisplaySize(
        width / 2,
        height / 2,
      );
    }
    final path =
        _readNullableString(() => image.localPath) ??
        _readNullableString(() => image.remotePath);
    if (path != null && path.isNotEmpty && !_isNetworkPath(path)) {
      final size = ChatUIImageUtil.getFileNaturalSize(path);
      width = size?.width;
      height = size?.height;
    }
    final ratio = width != null && width > 0 && height != null && height > 0
        ? width / height
        : 1.0;
    return ChatUIImageUtil.referenceThumbnailDisplaySizeForRatio(ratio);
  }

}

class _DeferredBase64Thumbnail extends StatefulWidget {
  const _DeferredBase64Thumbnail({
    required this.thumbnailBase64,
    required this.cacheSize,
    required this.fit,
    required this.placeholder,
  });

  final String thumbnailBase64;
  final _ImageCacheSize cacheSize;
  final BoxFit fit;
  final Widget placeholder;

  @override
  State<_DeferredBase64Thumbnail> createState() =>
      _DeferredBase64ThumbnailState();
}

class _DeferredBase64ThumbnailState extends State<_DeferredBase64Thumbnail> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _decodeThumbnail();
  }

  @override
  void didUpdateWidget(covariant _DeferredBase64Thumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbnailBase64 != widget.thumbnailBase64) {
      _thumbnailFuture = _decodeThumbnail();
    }
  }

  Future<Uint8List?> _decodeThumbnail() async {
    final cached = ChatUIImageUtil.getCachedDecodedBase64(
      widget.thumbnailBase64,
    );
    if (cached != null) {
      return cached;
    }
    await Future<void>.delayed(Duration.zero);
    return ChatUIImageUtil.getDecodedBase64(widget.thumbnailBase64);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      initialData: ChatUIImageUtil.getCachedDecodedBase64(
        widget.thumbnailBase64,
      ),
      builder: (context, snapshot) {
        final thumbnail = snapshot.data;
        if (thumbnail == null) {
          return widget.placeholder;
        }
        return Image(
          image: ResizeImage.resizeIfNeeded(
            widget.cacheSize.width,
            widget.cacheSize.height,
            MemoryImage(thumbnail),
          ),
          fit: widget.fit,
        );
      },
    );
  }
}
