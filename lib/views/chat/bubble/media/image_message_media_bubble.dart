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
    Widget buildFullPreview() => hasUsableLocalPreview
        ? _previewImage(
            context,
            localPath!,
            style,
            fit: previewConfig.fit,
            cacheSize: cacheSize,
            preferAnimation: preferAnimation,
          )
        : previewPath != null && previewPath.isNotEmpty
        ? _previewImage(
            context,
            previewPath,
            style,
            fit: previewConfig.fit,
            cacheSize: cacheSize,
            preferAnimation: preferAnimation,
          )
        : _mediaLoadingPlaceholder(style);
    final child = thumbnailBase64 != null && thumbnailBase64.isNotEmpty
        ? _DeferredBase64Thumbnail(
            thumbnailBase64: thumbnailBase64,
            cacheSize: cacheSize,
            fit: previewConfig.fit,
            loadingPlaceholder: _mediaLoadingPlaceholder(style),
            fallbackBuilder: buildFullPreview,
          )
        : buildFullPreview();
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
    final gif = media is GIFMessage ? media : null;
    if (gif != null && (_gifDataSize(gif) ?? 0) > 1024 * 1024) {
      final provider = _maybeChatProvider(context);
      return _LargeGifDownloadBubble(
        gif: gif,
        provider: provider,
        style: style,
        size: _imagePreviewSize(media),
        onPreview: () => _handleMediaPreviewTap(context, media),
      );
    }
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

  int? _gifDataSize(GIFMessage gif) {
    try {
      return gif.dataSize;
    } on NoSuchMethodError {
      return null;
    }
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
            loadingPlaceholder: _mediaLoadingPlaceholder(style),
            fallbackBuilder: () => previewWidget,
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

class _LargeGifDownloadBubble extends StatefulWidget {
  final GIFMessage gif;
  final ChatProvider? provider;
  final MessageStyleConfig style;
  final Size size;
  final VoidCallback onPreview;

  const _LargeGifDownloadBubble({
    required this.gif,
    required this.provider,
    required this.style,
    required this.size,
    required this.onPreview,
  });

  @override
  State<_LargeGifDownloadBubble> createState() =>
      _LargeGifDownloadBubbleState();
}

class _LargeGifDownloadBubbleState extends State<_LargeGifDownloadBubble> {
  bool _downloading = false;
  double? _progress;
  Object? _error;

  bool get _hasLocal => widget.gif.localPath?.isNotEmpty == true;

  Future<void> _download() async {
    final provider = widget.provider;
    if (provider == null || _downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });
    try {
      await provider.downloadMediaMessage(
        widget.gif,
        onDownloading: (_, progress) {
          if (!mounted) return;
          setState(() => _progress = progress.clamp(0, 100) / 100);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewConfig = context
        .findAncestorWidgetOfExactType<MessageBubble>()
        ?.config
        .bubbleConfig
        .imagePreviewConfig;
    final borderRadius = previewConfig?.borderRadius ?? 8;
    final fit = previewConfig?.fit ?? BoxFit.cover;
    final child = _hasLocal
        ? Image.file(
            File(widget.gif.localPath!),
            fit: fit,
            errorBuilder: (_, __, ___) => _fallback(context),
          )
        : _fallback(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _hasLocal ? widget.onPreview : null,
      child: Semantics(
        button: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: const Color(0x14000000), width: 0.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              width: widget.size.width,
              height: widget.size.height,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final label = _error != null ? '下载失败，点击重试' : 'GIF 过大，点击下载';
    return ColoredBox(
      color: widget.style.backgroundColor,
      child: Center(
        child: InkWell(
          key: MessageBubble.gifDownloadKey,
          onTap: _downloading ? null : _download,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _downloading
                ? SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 2,
                      color: widget.style.textColor,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: widget.style.textColor),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DeferredBase64Thumbnail extends StatefulWidget {
  const _DeferredBase64Thumbnail({
    required this.thumbnailBase64,
    required this.cacheSize,
    required this.fit,
    required this.loadingPlaceholder,
    required this.fallbackBuilder,
  });

  final String thumbnailBase64;
  final _ImageCacheSize cacheSize;
  final BoxFit fit;
  final Widget loadingPlaceholder;
  final Widget Function() fallbackBuilder;

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
          return snapshot.connectionState == ConnectionState.done
              ? widget.fallbackBuilder()
              : widget.loadingPlaceholder;
        }
        return Image(
          image: ResizeImage.resizeIfNeeded(
            widget.cacheSize.width,
            widget.cacheSize.height,
            MemoryImage(thumbnail),
          ),
          fit: widget.fit,
          errorBuilder: (_, __, ___) => widget.fallbackBuilder(),
        );
      },
    );
  }
}
