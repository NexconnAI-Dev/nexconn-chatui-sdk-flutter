part of '../message_input_widget.dart';

extension _MessageInputReferencePreview on _MessageInputWidgetState {
  Widget _buildReferencePreview(
    Message message,
    MessageInputProvider input,
    NexconnThemeTokens theme,
  ) {
    final profileProvider = widget.profileProvider;
    if (profileProvider != null) {
      return FutureBuilder<ChatProfileInfo?>(
        future: profileProvider(
          _referenceProfileChannel(message),
          message: message,
        ),
        initialData: _profileFromReferenceMessage(message),
        builder: (context, snapshot) => _buildReferencePreviewWithName(
          message,
          input,
          theme,
          _referenceSenderName(message, snapshot.data),
        ),
      );
    }
    return _buildReferencePreviewWithName(
      message,
      input,
      theme,
      _referenceSenderName(message, null),
    );
  }

  Widget _buildReferencePreviewWithName(
    Message message,
    MessageInputProvider input,
    NexconnThemeTokens theme,
    String senderName,
  ) {
    final summary = referenceMessageContent(
      message,
      localizations: context.chatUIL10n,
    );
    final previewConfig = widget.config.referencePreviewConfig;
    final customBuilder = previewConfig.builder;
    if (customBuilder != null) {
      return customBuilder(
        context,
        message,
        senderName,
        summary,
        input.clearReferenceMessage,
      );
    }
    final imagePreview = message is ImageMessage
        ? _referenceImagePreview(message, theme)
        : null;
    final titleSummary = imagePreview == null ? summary : '';
    final title =
        '| ${context.chatUIL10n.messageInputReplyTo(senderName, titleSummary)}';
    return Container(
      width: double.infinity,
      height: imagePreview == null ? kInputQuotePreviewHeight : null,
      constraints: imagePreview == null
          ? null
          : const BoxConstraints(minHeight: kInputQuotePreviewHeight),
      color:
          previewConfig.backgroundColor ??
          widget.config.backgroundColor ??
          theme.panelColor,
      padding:
          previewConfig.padding ??
          EdgeInsets.symmetric(
            horizontal: kInputQuotePreviewPaddingH,
            vertical: imagePreview == null ? 0 : 8,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: imagePreview == null
                ? _referenceTitleText(title, previewConfig, theme)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _referenceTitleText(title, previewConfig, theme),
                      const SizedBox(height: 6),
                      imagePreview,
                    ],
                  ),
          ),
          Tooltip(
            message: context.chatUIL10n.messageInputCancelReplyTooltip,
            child: GestureDetector(
              onTap: input.clearReferenceMessage,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child:
                    previewConfig.closeIcon ??
                    ChatUIAsset.image(
                      'NexconnLightIcon/Close.png',
                      width: kInputQuotePreviewCloseIconSize,
                      height: kInputQuotePreviewCloseIconSize,
                      color: theme.secondaryTextColor,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceTitleText(
    String title,
    MessageInputReferencePreviewConfig previewConfig,
    NexconnThemeTokens theme,
  ) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          previewConfig.textStyle ??
          const TextStyle(
            fontSize: kBubbleRefTextFontSize,
          ).copyWith(color: theme.secondaryTextColor),
    );
  }

  Widget _referenceImagePreview(ImageMessage image, NexconnThemeTokens theme) {
    final thumbnailBase64 = _readNullableString(
      () => image.thumbnailBase64String,
    );
    final thumbnail = ChatUIImageUtil.getDecodedBase64(thumbnailBase64);
    final localPath = _readNullableString(() => image.localPath);
    final remotePath = _readNullableString(() => image.remotePath);
    final size = _referenceImagePreviewSize(image, thumbnail, thumbnailBase64);
    final thumbnailWidget = thumbnail != null
        ? Image(
            image: ResizeImage.resizeIfNeeded(
              size.width.ceil(),
              size.height.ceil(),
              MemoryImage(thumbnail),
            ),
            fit: BoxFit.cover,
          )
        : null;
    final previewPath = _hasUsableLocalPreviewPath(localPath)
        ? localPath
        : (remotePath != null && remotePath.isNotEmpty ? remotePath : null);
    final child =
        thumbnailWidget ??
        (previewPath != null
            ? _previewImage(previewPath, theme)
            : _referenceImagePlaceholder(theme));
    return Align(
      alignment: Alignment.center,
      widthFactor: 1,
      heightFactor: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          key: MessageInputWidget.referenceImagePreviewKey,
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    );
  }

  Size _referenceImagePreviewSize(
    ImageMessage image,
    Uint8List? thumbnail,
    String? thumbnailBase64,
  ) {
    double? width = _readNullableInt(() => image.thumWidth)?.toDouble();
    double? height = _readNullableInt(() => image.thumHeight)?.toDouble();
    if ((width == null || width <= 0 || height == null || height <= 0) &&
        thumbnail != null) {
      final size = ChatUIImageUtil.getBase64NaturalSize(thumbnailBase64);
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

  Widget _previewImage(String path, NexconnThemeTokens theme) {
    Widget errorBuilder(_, __, ___) => _referenceImagePlaceholder(theme);
    if (_isNetworkPath(path)) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: errorBuilder);
    }
    return Image.file(
      _localFile(path),
      fit: BoxFit.cover,
      errorBuilder: errorBuilder,
    );
  }

  Widget _referenceImagePlaceholder(NexconnThemeTokens theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.3),
      ),
      child: Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  bool _hasUsableLocalPreviewPath(String? path) {
    if (path == null || path.isEmpty || _isNetworkPath(path)) {
      return false;
    }
    return _localFile(path).existsSync();
  }

  bool _isNetworkPath(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  File _localFile(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && uri.scheme == 'file' ? File.fromUri(uri) : File(path);
  }

  String? _readNullableString(String? Function() read) {
    try {
      final value = read()?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  int? _readNullableInt(int? Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
  }
}
