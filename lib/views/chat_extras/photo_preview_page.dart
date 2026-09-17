import 'dart:async';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../providers/chat_provider.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/chatui_image_util.dart';

/// Previews image and short-video media from chat messages.
class PhotoPreviewPage extends StatefulWidget {
  static const Key previewAreaKey = ValueKey('photo-preview-area');
  static const Key pageIndicatorKey = ValueKey('photo-preview-indicator');
  static const Key videoPreviewKey = ValueKey('photo-preview-video');

  final List<MediaMessage> images;
  final int initialIndex;
  final ChatProvider? provider;

  const PhotoPreviewPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.provider,
  });

  @override
  State<PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<PhotoPreviewPage> {
  late final PageController _controller;
  late int _currentIndex;
  ChatProvider? _chatProvider;
  String? _downloadingMediaKey;
  double? _downloadProgress;
  final Map<String, String> _resolvedLocalPaths = <String, String>{};
  final Set<String> _failedDownloadMediaKeys = <String>{};
  final bool _chromeVisible = true;
  bool _isSaving = false;
  bool _handledRecallForCurrentPreview = false;
  VideoPlayerController? _videoController;
  String? _videoPath;
  int _videoPrepareToken = 0;

  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };
  static const Set<String> _videoExtensions = {
    'mp4',
    'mov',
    'm4v',
    '3gp',
    'webm',
  };

  @override
  void initState() {
    super.initState();
    final boundedIndex = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _currentIndex = boundedIndex;
    _controller = PageController(initialPage: boundedIndex);
    _chatProvider = widget.provider;
    _attachDeletedMessageListener();
    _startCurrentMediaDownload();
    _prepareCurrentVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = widget.provider ?? _maybeChatProvider(context);
    if (identical(_chatProvider, provider)) {
      return;
    }
    _detachDeletedMessageListener();
    _chatProvider = provider;
    _attachDeletedMessageListener();
    _startCurrentMediaDownload();
    _prepareCurrentVideo();
  }

  @override
  void dispose() {
    _cancelCurrentDownload();
    _detachDeletedMessageListener();
    unawaited(_disposeVideoController());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _EmptyPhotoState(text: context.chatUIL10n.photoImageUnavailable),
      );
    }

    final currentMediaKey = _mediaKey(widget.images[_currentIndex]);
    final currentDownloadFailed = _failedDownloadMediaKeys.contains(
      currentMediaKey,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            scrollPhysics: const BouncingScrollPhysics(),
            itemCount: widget.images.length,
            onPageChanged: (index) {
              if (_currentIndex == index) {
                return;
              }
              _cancelCurrentDownload();
              setState(() {
                _currentIndex = index;
                _handledRecallForCurrentPreview = false;
              });
              _startCurrentMediaDownload();
              _prepareCurrentVideo();
            },
            loadingBuilder: (context, event) {
              final expected = event?.expectedTotalBytes;
              final progress = expected == null
                  ? null
                  : event!.cumulativeBytesLoaded / expected;
              return _PhotoLoading(progress: progress);
            },
            builder: (context, index) {
              final media = widget.images[index];
              final path = _displayPathFor(
                media,
                isCurrent: index == _currentIndex,
              );
              if (path == null || path.isEmpty) {
                final thumbnail = _thumbnailBytes(media);
                final progress = _downloadProgressFor(media);
                if (progress != null) {
                  return PhotoViewGalleryPageOptions.customChild(
                    child: _PhotoLoading(progress: progress),
                  );
                }
                if (thumbnail != null) {
                  return PhotoViewGalleryPageOptions.customChild(
                    child: Center(
                      child: PhotoView(
                        key: PhotoPreviewPage.previewAreaKey,
                        imageProvider: MemoryImage(thumbnail),
                        minScale: PhotoViewComputedScale.contained,
                        initialScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                        heroAttributes: PhotoViewHeroAttributes(
                          tag: 'thumbnail-$index',
                        ),
                        onTapUp: (_, __, ___) =>
                            Navigator.of(context).maybePop(),
                      ),
                    ),
                  );
                }
                return PhotoViewGalleryPageOptions.customChild(
                  child: _EmptyPhotoState(
                    text: context.chatUIL10n.photoImageUnavailable,
                  ),
                );
              }
              if (media is ShortVideoMessage) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: GestureDetector(
                    key: PhotoPreviewPage.previewAreaKey,
                    behavior: HitTestBehavior.opaque,
                    child: Center(child: _buildVideoPreview(path, media)),
                  ),
                  onTapUp: (_, __, ___) => Navigator.of(context).maybePop(),
                );
              }
              if (_isGifMedia(media)) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: _buildGifPreview(path),
                  childSize: _previewChildSize(media, path),
                  onTapUp: (_, __, ___) => Navigator.of(context).maybePop(),
                );
              }
              final provider = _imageProviderForPath(path);
              if (provider == null) {
                return PhotoViewGalleryPageOptions.customChild(
                  child: _EmptyPhotoState(
                    text: context.chatUIL10n.photoImageUnavailable,
                  ),
                );
              }
              return PhotoViewGalleryPageOptions.customChild(
                child: Center(
                  child: PhotoView(
                    key: PhotoPreviewPage.previewAreaKey,
                    imageProvider: provider,
                    minScale: PhotoViewComputedScale.contained,
                    initialScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: '$path-$index',
                    ),
                    errorBuilder: (_, __, ___) => _EmptyPhotoState(
                      text: context.chatUIL10n.photoImageUnavailable,
                    ),
                    onTapUp: (_, __, ___) => Navigator.of(context).maybePop(),
                  ),
                ),
              );
            },
          ),
          if (currentDownloadFailed)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: _PhotoDownloadFailed(
                  text: context.chatUIL10n.photoImageLoadFailed,
                  retryText: context.chatUIL10n.commonRetry,
                  onRetry: _startCurrentMediaDownload,
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: _chromeVisible ? 0 : -88,
            child: _TopChrome(
              isSaving: _isSaving,
              canSave: _canSaveCurrentMedia,
              onSave: _saveCurrentMedia,
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: _chromeVisible ? 0 : -72,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  key: PhotoPreviewPage.pageIndicatorKey,
                  '${_currentIndex + 1} / ${widget.images.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(String path, ShortVideoMessage video) {
    final controller = _videoController;
    if (path == _videoPath && controller?.value.isInitialized == true) {
      return SizedBox(
        key: PhotoPreviewPage.videoPreviewKey,
        width: double.infinity,
        child: AspectRatio(
          aspectRatio: controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              IconButton(
                color: Colors.white,
                iconSize: 56,
                onPressed: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                  setState(() {});
                },
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final duration = video.duration;
    return Container(
      key: PhotoPreviewPage.videoPreviewKey,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
          const SizedBox(height: 12),
          Text(
            context.chatUIL10n.photoVideoPreview,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (duration != null) ...[
            const SizedBox(height: 6),
            Text(
              context.chatUIL10n.photoVideoDuration(duration),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
              ),
              onPressed: () => _openExternal(path),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(context.chatUIL10n.photoOpenVideo),
            ),
          ),
        ],
      ),
    );
  }

  void _prepareCurrentVideo() {
    unawaited(_prepareCurrentVideoController());
  }

  Future<void> _prepareCurrentVideoController() async {
    final token = ++_videoPrepareToken;
    await _disposeVideoController();
    final media = _currentMedia;
    if (media is! ShortVideoMessage) {
      return;
    }
    final path = _displayPathFor(media, isCurrent: true);
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final controller = _isNetworkPath(path)
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(_localFile(path));
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted || token != _videoPrepareToken) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handleVideoControllerChanged);
      setState(() {
        _videoController = controller;
        _videoPath = path;
      });
      await controller.play();
    } catch (_) {
      if (mounted && token == _videoPrepareToken) {
        setState(() {
          _videoController = null;
          _videoPath = null;
        });
      }
    }
  }

  void _handleVideoControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    _videoController = null;
    _videoPath = null;
    if (controller != null) {
      controller.removeListener(_handleVideoControllerChanged);
      await controller.dispose();
    }
  }

  Widget _buildGifPreview(String path) {
    final provider = _imageProviderForPath(path);
    if (provider == null) {
      return _EmptyPhotoState(text: context.chatUIL10n.photoImageUnavailable);
    }
    return Center(
      child: Image(
        image: provider,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            _EmptyPhotoState(text: context.chatUIL10n.photoImageUnavailable),
      ),
    );
  }

  ImageProvider? _imageProviderForPath(String path) {
    if (_isNetworkPath(path)) {
      return NetworkImage(path);
    }
    final file = _localFile(path);
    return file.path.isEmpty ? null : FileImage(file);
  }

  bool _isGifMedia(MediaMessage media) {
    return media is GIFMessage || media.messageType == MessageType.gif;
  }

  Size? _previewChildSize(MediaMessage media, String path) {
    if (media is GIFMessage) {
      final width = _readGifDimension(() => media.width?.toDouble());
      final height = _readGifDimension(() => media.height?.toDouble());
      if (width != null && width > 0 && height != null && height > 0) {
        return Size(width, height);
      }
    }
    return null;
  }

  double? _readGifDimension(double? Function() reader) {
    try {
      return reader();
    } on NoSuchMethodError {
      return null;
    }
  }

  bool _isNetworkPath(String path) {
    return path.startsWith(RegExp(r'https?://', caseSensitive: false));
  }

  String _mediaKey(MediaMessage media) {
    final messageId = media.messageId;
    if (messageId != null && messageId.isNotEmpty) {
      return 'uid:$messageId';
    }
    final clientId = media.clientId;
    if (clientId != null) {
      return 'client:$clientId';
    }
    return '${media.channelType?.name}:${media.channelId}:${media.sentTime}:${media.senderUserId}';
  }

  String? _displayPathFor(MediaMessage media, {required bool isCurrent}) {
    final latestMedia = _latestMediaFor(media);
    final localPath =
        _resolvedLocalPaths[_mediaKey(media)] ??
        latestMedia?.localPath ??
        media.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      return localPath;
    }
    if (_isPreviewSdkDownloadTarget(media) && _chatProvider != null) {
      return null;
    }
    return latestMedia?.remotePath ?? media.remotePath;
  }

  double? _downloadProgressFor(MediaMessage media) {
    if (_downloadingMediaKey != _mediaKey(media)) {
      return null;
    }
    return _downloadProgress;
  }

  bool _isPreviewSdkDownloadTarget(MediaMessage media) {
    return media is ImageMessage || _isGifMedia(media);
  }

  void _startCurrentMediaDownload() {
    unawaited(_ensureCurrentMediaAvailable());
  }

  Future<void> _ensureCurrentMediaAvailable() async {
    final provider = _chatProvider;
    final media = _currentMedia;
    if (provider == null || !_isPreviewSdkDownloadTarget(media)) {
      return;
    }
    final key = _mediaKey(media);
    final latestMedia = _latestMediaFor(media);
    final localPath =
        _resolvedLocalPaths[key] ?? latestMedia?.localPath ?? media.localPath;
    if (localPath?.isNotEmpty == true || _downloadingMediaKey == key) {
      return;
    }
    final targetMedia = latestMedia ?? media;
    if (targetMedia.remotePath?.isNotEmpty != true) {
      return;
    }
    if (mounted) {
      setState(() {
        _failedDownloadMediaKeys.remove(key);
        _downloadingMediaKey = key;
        _downloadProgress = 0;
      });
    }
    try {
      await provider.downloadMediaMessage(
        targetMedia,
        onDownloading: (_, progress) {
          if (!mounted || _downloadingMediaKey != key) {
            return;
          }
          setState(() {
            _downloadProgress = (progress.clamp(0, 100)) / 100;
          });
        },
        onDownloaded: (downloaded) {
          final path = downloaded.localPath;
          if (path == null || path.isEmpty || !mounted) {
            return;
          }
          setState(() {
            _resolvedLocalPaths[key] = path;
          });
        },
      );
      if (!mounted || _downloadingMediaKey != key) {
        return;
      }
      setState(() {
        final resolvedPath =
            _resolvedLocalPaths[key] ??
            _latestMediaFor(media)?.localPath ??
            targetMedia.localPath ??
            media.localPath;
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          _resolvedLocalPaths[key] = resolvedPath;
        }
        _downloadingMediaKey = null;
        _downloadProgress = null;
      });
    } catch (_) {
      if (!mounted || _downloadingMediaKey != key) {
        return;
      }
      setState(() {
        _failedDownloadMediaKeys.add(key);
        _downloadingMediaKey = null;
        _downloadProgress = null;
      });
    }
  }

  MediaMessage? _latestMediaFor(MediaMessage media) {
    final provider = _chatProvider;
    if (provider == null) {
      return null;
    }
    for (final candidate in provider.messages.whereType<MediaMessage>()) {
      if (_isSameMessage(candidate, media)) {
        return candidate;
      }
    }
    return null;
  }

  void _cancelCurrentDownload() {
    final key = _downloadingMediaKey;
    final provider = _chatProvider;
    if (key == null || provider == null) {
      return;
    }
    final media = widget.images.firstWhere(
      (candidate) => _mediaKey(candidate) == key,
      orElse: () => _currentMedia,
    );
    _downloadingMediaKey = null;
    _downloadProgress = null;
    unawaited(provider.cancelMediaDownload(media));
  }

  Uint8List? _thumbnailBytes(MediaMessage media) {
    if (media is! ImageMessage) {
      return null;
    }
    return ChatUIImageUtil.getDecodedBase64(
      media.thumbnailBase64String?.trim(),
    );
  }

  File _localFile(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') {
      return File.fromUri(uri);
    }
    return File(path);
  }

  Future<void> _openExternal(String path) async {
    final uri = _uriForPath(path);
    if (uri == null) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.chatUIL10n.photoOpenFailed)),
      );
    }
  }

  bool get _canSaveCurrentMedia {
    final media = _currentMedia;
    return media.localPath?.isNotEmpty == true ||
        media.remotePath?.isNotEmpty == true;
  }

  MediaMessage get _currentMedia => widget.images[_currentIndex];

  Future<void> _saveCurrentMedia() async {
    if (_isSaving) {
      return;
    }
    if (kIsWeb || !_canSaveCurrentMedia) {
      _showSaveUnsupported();
      return;
    }
    final l10n = context.chatUIL10n;
    setState(() => _isSaving = true);
    try {
      final localPath = await _localMediaPathForSave(_currentMedia);
      final result = await ImageGallerySaverPlus.saveFile(localPath);
      _showSnackBar(
        _saveResultSucceeded(result)
            ? l10n.photoSaveSucceeded
            : l10n.photoSaveFailed,
      );
    } catch (_) {
      _showSnackBar(l10n.photoSaveFailed);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String> _localMediaPathForSave(MediaMessage media) async {
    final sourcePath = media.localPath?.trim();
    if (sourcePath != null && sourcePath.isNotEmpty) {
      return _ensureSaveExtension(
        _localFile(sourcePath),
        extension: _preferredExtension(media, sourcePath),
      );
    }
    final remotePath = media.remotePath?.trim();
    if (remotePath == null ||
        remotePath.isEmpty ||
        !_isNetworkPath(remotePath)) {
      throw StateError('Media path is unavailable.');
    }
    final extension = _preferredExtension(media, remotePath);
    final tempFile = File(
      '${Directory.systemTemp.path}/nexconn_photo_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await Dio().download(remotePath, tempFile.path);
    return tempFile.path;
  }

  Future<String> _ensureSaveExtension(
    File originalFile, {
    required String extension,
  }) async {
    if (!await originalFile.exists()) {
      throw StateError('Media file does not exist.');
    }
    final normalizedExtension = extension.toLowerCase();
    if (originalFile.path.toLowerCase().endsWith('.$normalizedExtension')) {
      return originalFile.path;
    }
    final tempFile = File(
      '${Directory.systemTemp.path}/nexconn_photo_${DateTime.now().microsecondsSinceEpoch}.$normalizedExtension',
    );
    await originalFile.copy(tempFile.path);
    return tempFile.path;
  }

  String _preferredExtension(MediaMessage media, String path) {
    if (media is ShortVideoMessage || media.messageType == MessageType.sight) {
      final extension = _pathExtension(path);
      if (extension != null && _videoExtensions.contains(extension)) {
        return extension;
      }
      return 'mp4';
    }
    if (media is GIFMessage || media.messageType == MessageType.gif) {
      return 'gif';
    }
    final extension = _pathExtension(path);
    if (extension != null && _imageExtensions.contains(extension)) {
      return extension;
    }
    return 'jpg';
  }

  String? _pathExtension(String path) {
    final uri = Uri.tryParse(path);
    final candidate = (uri?.path ?? path).split('/').last;
    final index = candidate.lastIndexOf('.');
    if (index < 0 || index == candidate.length - 1) {
      return null;
    }
    return candidate.substring(index + 1).toLowerCase();
  }

  void _showSaveUnsupported() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.chatUIL10n.photoSaveUnsupported)),
    );
  }

  void _showSnackBar(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _saveResultSucceeded(dynamic result) {
    if (result is Map) {
      final explicit = result['isSuccess'] ?? result['success'];
      if (_asSuccessFlag(explicit)) {
        return true;
      }
      final savedPath =
          result['filePath'] ??
          result['savedFilePath'] ??
          result['path'] ??
          result['uri'];
      return savedPath is String && savedPath.trim().isNotEmpty;
    }
    return _asSuccessFlag(result);
  }

  bool _asSuccessFlag(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'success':
          return true;
      }
    }
    return false;
  }

  Uri? _uriForPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      return uri;
    }
    if (path.isEmpty) {
      return null;
    }
    return Uri.file(path);
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

  void _attachDeletedMessageListener() {
    _chatProvider?.engineProvider.deletedMessagesNotifier.addListener(
      _handleDeletedMessagesChanged,
    );
  }

  void _detachDeletedMessageListener() {
    _chatProvider?.engineProvider.deletedMessagesNotifier.removeListener(
      _handleDeletedMessagesChanged,
    );
  }

  void _handleDeletedMessagesChanged() {
    if (_handledRecallForCurrentPreview || _chatProvider == null) {
      return;
    }
    final currentMedia = _currentMedia;
    final deletedMessages =
        _chatProvider!.engineProvider.deletedMessagesNotifier.value;
    if (deletedMessages == null || deletedMessages.isEmpty) {
      return;
    }
    final recalled = deletedMessages.any(
      (message) => _isSameMessage(message, currentMedia),
    );
    if (!recalled) {
      return;
    }
    _handledRecallForCurrentPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final l10n = context.chatUIL10n;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(l10n.messageDeletedForEveryone),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonConfirm),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    });
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
}

class _TopChrome extends StatelessWidget {
  final bool isSaving;
  final bool canSave;
  final VoidCallback onSave;

  const _TopChrome({
    required this.isSaving,
    required this.canSave,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: ChatUIAsset.image(
                  'NexconnLightIcon/Left-arrow.png',
                  width: 24,
                  height: 24,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: canSave && !isSaving ? onSave : null,
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.chatUIL10n.commonSave,
                        style: TextStyle(
                          color: canSave ? Colors.white : Colors.white54,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoLoading extends StatelessWidget {
  final double? progress;

  const _PhotoLoading({this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 3,
          color: Colors.white,
          backgroundColor: Colors.white24,
        ),
      ),
    );
  }
}

class _EmptyPhotoState extends StatelessWidget {
  final String text;

  const _EmptyPhotoState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/Thumbnail-failed.png',
            width: 44,
            height: 44,
            color: Colors.white54,
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _PhotoDownloadFailed extends StatelessWidget {
  final String text;
  final String retryText;
  final VoidCallback onRetry;

  const _PhotoDownloadFailed({
    required this.text,
    required this.retryText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/Thumbnail-failed.png',
            width: 44,
            height: 44,
            color: Colors.white54,
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(retryText)),
        ],
      ),
    );
  }
}
