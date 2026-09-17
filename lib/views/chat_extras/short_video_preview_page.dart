import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../providers/chat_provider.dart';

/// Plays a short-video message.
class ShortVideoPreviewPage extends StatefulWidget {
  static const Key playerKey = ValueKey('short-video-preview-player');
  static const Key closeButtonKey = ValueKey('short-video-preview-close');
  static const Key controlsKey = ValueKey('short-video-preview-controls');
  static const Key playPauseKey = ValueKey('short-video-preview-play-pause');
  static const Key saveButtonKey = ValueKey('short-video-preview-save');
  static const Key retryButtonKey = ValueKey('short-video-preview-retry');

  final List<ShortVideoMessage> videos;
  final int initialIndex;
  final ChatProvider? provider;

  const ShortVideoPreviewPage({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.provider,
  });

  @override
  State<ShortVideoPreviewPage> createState() => _ShortVideoPreviewPageState();
}

class _ShortVideoPreviewPageState extends State<ShortVideoPreviewPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late int _currentIndex;
  ChatProvider? _chatProvider;
  VideoPlayerController? _videoController;
  String? _downloadingVideoKey;
  double? _downloadProgress;
  final Map<String, String> _resolvedLocalPaths = <String, String>{};
  int _prepareToken = 0;
  bool _didResolveProvider = false;
  bool _controlsVisible = true;
  bool _isPreparing = false;
  bool _hasError = false;
  Object? _downloadError;
  bool _isSaving = false;
  bool _handledRecallForCurrentPreview = false;

  ShortVideoMessage? get _currentVideo =>
      widget.videos.isEmpty ? null : widget.videos[_currentIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final boundedIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1);
    _currentIndex = boundedIndex;
    _pageController = PageController(initialPage: boundedIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = widget.provider ?? _maybeChatProvider(context);
    if (_didResolveProvider && identical(_chatProvider, provider)) {
      return;
    }
    _didResolveProvider = true;
    _detachDeletedMessageListener();
    _chatProvider = provider;
    _attachDeletedMessageListener();
    unawaited(_prepareCurrentVideo());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _videoController?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelCurrentDownload();
    _detachDeletedMessageListener();
    _pageController.dispose();
    unawaited(_disposeVideoController());
    super.dispose();
  }

  Future<void> _prepareCurrentVideo() async {
    final token = ++_prepareToken;
    final video = _currentVideo;
    await _disposeVideoController();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparing = true;
      _hasError = false;
      _downloadError = null;
    });
    final path = await _resolveVideoPath(video, token);
    if (!mounted || token != _prepareToken) {
      return;
    }
    if (video == null || path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _isPreparing = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final controller = _controllerForPath(path);
      await controller.setLooping(false);
      controller.addListener(_handleVideoChanged);
      await _initializeVideoController(controller, path);
      if (token != _prepareToken) {
        await controller.dispose();
        return;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _isPreparing = false;
        _hasError = false;
      });
      unawaited(_ensureVideoPlayback(controller, retryIfNeeded: true));
    } catch (_) {
      if (mounted && token == _prepareToken) {
        setState(() {
          _isPreparing = false;
          _hasError = true;
          _downloadError = null;
        });
      }
    }
  }

  Future<void> _initializeVideoController(
    VideoPlayerController controller,
    String path,
  ) async {
    if (!_isLocalVideoPath(path)) {
      await controller.initialize();
      return;
    }
    await _waitForLocalVideoReady(path);
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await controller.initialize();
        return;
      } catch (error) {
        lastError = error;
        if (attempt == 2) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 160 * (attempt + 1)));
      }
    }
    throw lastError ?? StateError('Failed to initialize local video.');
  }

  VideoPlayerController _controllerForPath(String path) {
    final uri = Uri.tryParse(path);
    final isNetwork =
        uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    if (isNetwork) {
      return VideoPlayerController.networkUrl(uri);
    }
    if (kIsWeb) {
      throw UnsupportedError('Local video files are not supported on web.');
    }
    if (uri != null && uri.scheme.toLowerCase() == 'file') {
      return VideoPlayerController.file(File.fromUri(uri));
    }
    return VideoPlayerController.file(File(path));
  }

  bool _isLocalVideoPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null || !uri.hasScheme) {
      return true;
    }
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'file';
  }

  Future<void> _waitForLocalVideoReady(String path) async {
    final file = _localVideoFile(path);
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await file.exists()) {
        final length = await file.length();
        if (length > 0) {
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  File _localVideoFile(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme.toLowerCase() == 'file') {
      return File.fromUri(uri);
    }
    return File(path);
  }

  void _handleVideoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    _videoController = null;
    if (controller == null) {
      return;
    }
    controller.removeListener(_handleVideoChanged);
    await controller.dispose();
  }

  Future<void> _pauseCurrentVideo() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }
    if (!controller.value.isInitialized || !controller.value.isPlaying) {
      return;
    }
    await controller.pause();
  }

  Future<void> _handleClose() async {
    await _pauseCurrentVideo();
    if (!mounted) {
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Video unavailable',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return PopScope<void>(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          return;
        }
        unawaited(_pauseCurrentVideo());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final videoFrame = _videoFrame(constraints.biggest);
            return Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.videos.length,
                  onPageChanged: (index) {
                    _cancelCurrentDownload();
                    setState(() {
                      _currentIndex = index;
                      _handledRecallForCurrentPreview = false;
                    });
                    unawaited(_prepareCurrentVideo());
                  },
                  itemBuilder: (context, index) {
                    if (index != _currentIndex) {
                      return const ColoredBox(color: Colors.black);
                    }
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() => _controlsVisible = !_controlsVisible);
                      },
                      onLongPress: _showSaveSheet,
                      child: Center(child: _videoContent()),
                    );
                  },
                ),
                if (_controlsVisible) _topChrome(videoFrame),
                if (_controlsVisible) _timelineControls(videoFrame),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _videoContent() {
    final controller = _videoController;
    if (_isPreparing) {
      return _videoLoading();
    }
    if (_hasError || controller == null || !controller.value.isInitialized) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _downloadError == null ? '视频不可用' : '下载失败，点击重试',
            style: const TextStyle(color: Colors.white70),
          ),
          if (_downloadError != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              key: ShortVideoPreviewPage.retryButtonKey,
              onPressed: _prepareCurrentVideo,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('重试', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      );
    }
    final rotatedAspectRatio = _displayAspectRatio(controller.value);
    final quarterTurns = _quarterTurns(controller.value);
    return AspectRatio(
      key: ShortVideoPreviewPage.playerKey,
      aspectRatio: rotatedAspectRatio,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _videoLoading() {
    final progress = _downloadProgress;
    return SizedBox.square(
      dimension: 44,
      child: CircularProgressIndicator(
        value: progress,
        color: Colors.white,
        strokeWidth: 3,
      ),
    );
  }

  Widget _topChrome(Rect videoFrame) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final top = math.max(safeTop + 12, videoFrame.top - 44);
    return Positioned(
      left: videoFrame.left + 12,
      top: top,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          key: ShortVideoPreviewPage.closeButtonKey,
          padding: EdgeInsets.zero,
          color: const Color(0xFF8D8F98),
          iconSize: 34,
          icon: const Icon(Icons.close),
          onPressed: _handleClose,
        ),
      ),
    );
  }

  Widget _timelineControls(Rect videoFrame) {
    final controller = _videoController;
    final value = controller?.value;
    final initialized = value?.isInitialized ?? false;
    final position = initialized ? _displayPosition(value!) : Duration.zero;
    final duration = initialized ? value!.duration : Duration.zero;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final controlsWidth = math.min(
      viewportWidth - 16,
      math.max(344.0, videoFrame.width - 16),
    );
    final controlsLeft = (viewportWidth - controlsWidth) / 2;

    return Positioned(
      left: controlsLeft,
      width: controlsWidth,
      top: _controlsTop(videoFrame),
      child: SizedBox(
        key: ShortVideoPreviewPage.controlsKey,
        height: 64,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 64,
              child: IconButton(
                key: ShortVideoPreviewPage.playPauseKey,
                padding: EdgeInsets.zero,
                color: Colors.white,
                iconSize: 44,
                icon: Icon(
                  value?.isPlaying == true ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: initialized ? _togglePlayPause : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${_formatDuration(position)} / ${_formatDuration(duration)}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 5,
                    activeTrackColor: const Color(0xFF3F7BFF),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
                    disabledActiveTrackColor: const Color(0xFF3F7BFF),
                    disabledInactiveTrackColor: Colors.white.withValues(
                      alpha: 0.16,
                    ),
                    thumbColor: Colors.white,
                    disabledThumbColor: Colors.white70,
                    overlayColor: const Color(0x333F7BFF),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                      disabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds == 0
                        ? 0
                        : position.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble(),
                    max: duration.inMilliseconds == 0
                        ? 1
                        : duration.inMilliseconds.toDouble(),
                    onChanged: initialized
                        ? (value) => controller?.seekTo(
                            Duration(milliseconds: value.round()),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 64,
              child: IconButton(
                key: ShortVideoPreviewPage.saveButtonKey,
                padding: EdgeInsets.zero,
                color: Colors.white,
                iconSize: 44,
                icon: _isSaving
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                onPressed: _isSaving ? null : _saveCurrentVideo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _controlsTop(Rect videoFrame) {
    final targetTop = videoFrame.bottom - 50;
    final minTop = videoFrame.top + 24;
    final maxTop = videoFrame.bottom - 72;
    return targetTop.clamp(minTop, maxTop);
  }

  Rect _videoFrame(Size viewport) {
    final controller = _videoController;
    final aspectRatio = controller != null && controller.value.isInitialized
        ? _displayAspectRatio(controller.value)
        : 9 / 16;
    final safeAspectRatio = aspectRatio > 0 ? aspectRatio : 9 / 16;
    final viewportAspectRatio = viewport.width / viewport.height;
    final width = viewportAspectRatio > safeAspectRatio
        ? viewport.height * safeAspectRatio
        : viewport.width;
    final height = viewportAspectRatio > safeAspectRatio
        ? viewport.height
        : viewport.width / safeAspectRatio;
    return Rect.fromLTWH(
      (viewport.width - width) / 2,
      (viewport.height - height) / 2,
      width,
      height,
    );
  }

  Future<void> _togglePlayPause() async {
    final controller = _videoController;
    if (controller == null) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      final duration = controller.value.duration;
      final position = controller.value.position;
      if (duration > Duration.zero && position >= duration) {
        await controller.seekTo(Duration.zero);
      }
      await _ensureVideoPlayback(controller, retryIfNeeded: true);
    }
  }

  Future<void> _ensureVideoPlayback(
    VideoPlayerController controller, {
    required bool retryIfNeeded,
  }) async {
    if (!controller.value.isInitialized) {
      return;
    }
    await controller.play();
    if (!retryIfNeeded || !mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted || _videoController != controller) {
      return;
    }
    if (!controller.value.isPlaying) {
      await controller.play();
    }
  }

  Future<void> _showSaveSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Save video'),
          onTap: () {
            Navigator.of(context).pop();
            unawaited(_saveCurrentVideo());
          },
        ),
      ),
    );
  }

  Future<void> _saveCurrentVideo() async {
    if (_isSaving) {
      return;
    }
    final path = _videoPath(_currentVideo);
    if (path == null || path.isEmpty) {
      return;
    }
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final localPath = await _localVideoPath(path);
      await ImageGallerySaverPlus.saveFile(localPath);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Video saved')));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to save video')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String> _localVideoPath(String path) async {
    final uri = Uri.tryParse(path);
    final isNetwork =
        uri != null &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    if (!isNetwork) {
      return uri?.scheme.toLowerCase() == 'file'
          ? File.fromUri(uri!).path
          : path;
    }
    final directory = await getTemporaryDirectory();
    final fileName =
        'nexconn_short_video_${DateTime.now().microsecondsSinceEpoch}.mp4';
    final outputPath = '${directory.path}/$fileName';
    await Dio().download(path, outputPath);
    return outputPath;
  }

  Future<String?> _resolveVideoPath(ShortVideoMessage? video, int token) async {
    if (video == null) {
      return null;
    }
    final path = _videoPath(video);
    if (path != null && path.isNotEmpty && !_isNetworkPath(path)) {
      return path;
    }
    final provider = _chatProvider;
    final remotePath = _latestVideoFor(video)?.remotePath ?? video.remotePath;
    if (provider == null || remotePath == null || remotePath.isEmpty) {
      return path;
    }
    return _downloadVideo(video, provider, token);
  }

  String? _videoPath(ShortVideoMessage? video) {
    if (video == null) {
      return null;
    }
    final latestVideo = _latestVideoFor(video);
    final key = _mediaKey(video);
    final localPath =
        _resolvedLocalPaths[key] ?? latestVideo?.localPath ?? video.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      return localPath;
    }
    return latestVideo?.remotePath ?? video.remotePath;
  }

  Future<String?> _downloadVideo(
    ShortVideoMessage video,
    ChatProvider provider,
    int token,
  ) async {
    final key = _mediaKey(video);
    if (_downloadingVideoKey == key) {
      return null;
    }
    final targetVideo = _latestVideoFor(video) ?? video;
    if (targetVideo.remotePath?.isNotEmpty != true) {
      return null;
    }
    if (mounted) {
      setState(() {
        _downloadingVideoKey = key;
        _downloadProgress = 0;
      });
    }
    try {
      String? downloadedPath;
      await provider.downloadMediaMessage(
        targetVideo,
        onDownloading: (_, progress) {
          if (!mounted ||
              token != _prepareToken ||
              _downloadingVideoKey != key) {
            return;
          }
          setState(() {
            _downloadProgress = (progress.clamp(0, 100)) / 100;
          });
        },
        onDownloaded: (downloaded) {
          final path = downloaded.localPath;
          if (path == null || path.isEmpty) {
            return;
          }
          downloadedPath = path;
          targetVideo.localPath = path;
          video.localPath = path;
        },
      );
      if (!mounted || token != _prepareToken || _downloadingVideoKey != key) {
        return null;
      }
      final resolvedPath =
          downloadedPath ??
          _latestVideoFor(video)?.localPath ??
          targetVideo.localPath ??
          video.localPath;
      setState(() {
        if (resolvedPath != null && resolvedPath.isNotEmpty) {
          _resolvedLocalPaths[key] = resolvedPath;
        }
        _downloadingVideoKey = null;
        _downloadProgress = null;
      });
      return resolvedPath;
    } catch (e) {
      if (!mounted || token != _prepareToken || _downloadingVideoKey != key) {
        return null;
      }
      setState(() {
        _downloadingVideoKey = null;
        _downloadProgress = null;
        _downloadError = e;
      });
      return null;
    }
  }

  ShortVideoMessage? _latestVideoFor(ShortVideoMessage video) {
    final provider = _chatProvider;
    if (provider == null) {
      return null;
    }
    for (final candidate in provider.messages.whereType<ShortVideoMessage>()) {
      if (_isSameMessage(candidate, video)) {
        return candidate;
      }
    }
    return null;
  }

  void _cancelCurrentDownload() {
    final key = _downloadingVideoKey;
    final provider = _chatProvider;
    if (key == null || provider == null) {
      return;
    }
    final video = widget.videos.firstWhere(
      (candidate) => _mediaKey(candidate) == key,
      orElse: () => _currentVideo ?? widget.videos.first,
    );
    _downloadingVideoKey = null;
    _downloadProgress = null;
    unawaited(provider.cancelMediaDownload(video));
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

  bool _isNetworkPath(String path) {
    return path.startsWith(RegExp(r'https?://', caseSensitive: false));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int _quarterTurns(VideoPlayerValue value) {
    final rotation = value.rotationCorrection % 360;
    return switch (rotation) {
      90 => 1,
      180 => 2,
      270 => 3,
      _ => 0,
    };
  }

  double _displayAspectRatio(VideoPlayerValue value) {
    final size = value.size;
    if (size.width <= 0 || size.height <= 0) {
      return 9 / 16;
    }
    final turns = _quarterTurns(value);
    final swapsAxes = turns == 1 || turns == 3;
    final width = swapsAxes ? size.height : size.width;
    final height = swapsAxes ? size.width : size.height;
    if (width <= 0 || height <= 0) {
      return 9 / 16;
    }
    return width / height;
  }

  Duration _displayPosition(VideoPlayerValue value) {
    final duration = value.duration;
    final position = value.position;
    final isCompleted =
        duration > Duration.zero && position >= duration && !value.isPlaying;
    return isCompleted ? Duration.zero : position;
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
    final currentVideo = _currentVideo;
    if (currentVideo == null) {
      return;
    }
    final deletedMessages =
        _chatProvider!.engineProvider.deletedMessagesNotifier.value;
    if (deletedMessages == null || deletedMessages.isEmpty) {
      return;
    }
    final recalled = deletedMessages.any(
      (message) => _isSameMessage(message, currentVideo),
    );
    if (!recalled) {
      return;
    }
    _handledRecallForCurrentPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _pauseCurrentVideo();
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
