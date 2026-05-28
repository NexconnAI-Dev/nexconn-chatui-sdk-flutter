part of '../message_bubble.dart';

extension _MessageBubblePreviewActions on _MessageBubbleBase {
  Future<void> _handleLinkTap(BuildContext context, Uri uri) async {
    final custom = config.messageListConfig.onLinkTap;
    if (custom != null) {
      await custom(context, message, uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handlePhoneTap(BuildContext context, String phoneNumber) async {
    final custom = config.messageListConfig.onPhoneTap;
    if (custom != null) {
      await custom(context, message, phoneNumber);
      return;
    }
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleMediaPreviewTap(
    BuildContext context,
    MediaMessage current,
  ) async {
    final provider = _maybeChatProvider(context);
    if (provider?.multiSelectMode == true) {
      onTap?.call();
      return;
    }
    final images = _previewImages(provider);
    final initialIndex = _initialPreviewIndex(images, current);
    if (current is ShortVideoMessage) {
      final videos = images.whereType<ShortVideoMessage>().toList();
      final videoIndex = videos.indexWhere(
        (candidate) => _isSameMessage(candidate, current),
      );
      await pushNexconnChatUINamedRouteOr<void>(
        context,
        NexconnChatUIRoutes.shortVideoPreview,
        arguments: NexconnShortVideoPreviewRouteArguments(
          videos: videos.isEmpty ? <ShortVideoMessage>[current] : videos,
          initialIndex: videoIndex >= 0 ? videoIndex : 0,
          provider: provider,
        ),
        fallbackRoute: () => MaterialPageRoute<void>(
          builder: (_) => ShortVideoPreviewPage(
            videos: videos.isEmpty ? <ShortVideoMessage>[current] : videos,
            initialIndex: videoIndex >= 0 ? videoIndex : 0,
            provider: provider,
          ),
        ),
      );
      return;
    }
    await pushNexconnChatUINamedRouteOr<void>(
      context,
      NexconnChatUIRoutes.photoPreview,
      arguments: NexconnPhotoPreviewRouteArguments(
        images: images,
        initialIndex: initialIndex,
        provider: provider,
      ),
      fallbackRoute: () => MaterialPageRoute<void>(
        builder: (_) => PhotoPreviewPage(
          images: images,
          initialIndex: initialIndex,
          provider: provider,
        ),
      ),
    );
  }

  Future<void> _handleFilePreviewTap(
    BuildContext context,
    FileMessage file,
  ) async {
    final provider = _maybeChatProvider(context);
    if (provider?.multiSelectMode == true) {
      onTap?.call();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FilePreviewPage(fileMessage: file, provider: provider),
      ),
    );
  }

  ChatProvider? _maybeChatProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<ChatProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  NexconnAudioPlayerProvider? _maybeAudioPlayerProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<NexconnAudioPlayerProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  EngineProvider? _maybeEngineProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<EngineProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<MediaMessage> _previewImages(ChatProvider? provider) {
    final current = message;
    final fallback = current is MediaMessage
        ? <MediaMessage>[current]
        : <MediaMessage>[];
    final providerMessages = provider?.messages ?? const <Message>[];
    final images = providerMessages
        .whereType<MediaMessage>()
        .where(_isPreviewableMediaMessage)
        .toList(growable: false);
    if (images.isEmpty) {
      return fallback;
    }
    if (current is MediaMessage &&
        _isPreviewableMediaMessage(current) &&
        !images.any((candidate) => _isSameMessage(candidate, current))) {
      return [...images, current];
    }
    return images;
  }

  bool _isPreviewableMediaMessage(MediaMessage media) {
    final isImage =
        media is ImageMessage ||
        media is GIFMessage ||
        media is ShortVideoMessage;
    final path = media.remotePath ?? media.localPath;
    return isImage && path != null && path.isNotEmpty;
  }

  int _initialPreviewIndex(List<MediaMessage> images, MediaMessage current) {
    final index = images.indexWhere(
      (candidate) => _isSameMessage(candidate, current),
    );
    return index >= 0 ? index : 0;
  }

  bool _isSameMessage(Message a, Message b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.messageId != null &&
        b.messageId != null &&
        a.messageId == b.messageId) {
      return true;
    }
    if (a.clientId != null && b.clientId != null && a.clientId == b.clientId) {
      return true;
    }
    return a.channelId == b.channelId &&
        a.senderUserId == b.senderUserId &&
        a.sentTime == b.sentTime;
  }

  String _messageKey(Message message) {
    return message.messageId ??
        message.clientId?.toString() ??
        '${message.channelId}:${message.sentTime}:${message.senderUserId}';
  }

  bool _isNetworkPath(String path) {
    return path.startsWith(RegExp(r'https?://', caseSensitive: false));
  }

  File _localFile(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') {
      return File.fromUri(uri);
    }
    return File(path);
  }
}
