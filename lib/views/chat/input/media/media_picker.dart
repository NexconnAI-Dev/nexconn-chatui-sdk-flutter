part of '../message_input_widget.dart';

extension _MessageInputMediaPicker on _MessageInputWidgetState {
  bool _canHandlePluginTap(MessageInputExtensionPlugin plugin) {
    return plugin.onTap != null ||
        _canSendMediaWithPlugin(plugin) ||
        _canSendLocationWithPlugin(plugin);
  }

  bool _canSendMediaWithPlugin(MessageInputExtensionPlugin plugin) {
    return switch (plugin.type) {
      MessageInputExtensionPluginType.photo ||
      MessageInputExtensionPluginType.camera ||
      MessageInputExtensionPluginType.video ||
      MessageInputExtensionPluginType.filming ||
      MessageInputExtensionPluginType.file =>
        plugin.mediaDraftResolver != null ||
            plugin.mediaPathResolver != null ||
            _hasDefaultMediaPicker(plugin),
      _ => false,
    };
  }

  bool _hasDefaultMediaPicker(MessageInputExtensionPlugin plugin) {
    return switch (plugin.type) {
      MessageInputExtensionPluginType.photo ||
      MessageInputExtensionPluginType.video ||
      MessageInputExtensionPluginType.camera ||
      MessageInputExtensionPluginType.filming ||
      MessageInputExtensionPluginType.file => true,
      _ => false,
    };
  }

  Future<List<_PickedInputMedia>> _resolveMediaDrafts(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) async {
    final draftResolver = plugin.mediaDraftResolver;
    if (draftResolver != null) {
      final drafts = await draftResolver(context, plugin);
      return drafts?.map(_PickedInputMedia.fromDraft).toList(growable: false) ??
          const [];
    }
    final resolver = plugin.mediaPathResolver;
    if (resolver != null) {
      final path = await resolver(context, plugin);
      return path == null ? const [] : [_PickedInputMedia(path: path)];
    }
    try {
      return await _pickDefaultMedia(context, plugin);
    } catch (_) {
      if (context.mounted) {
        _showUnavailablePlugin(context, plugin);
      }
      return const [];
    }
  }

  Future<List<_PickedInputMedia>> _pickDefaultMedia(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) async {
    if (!await _requestDefaultMediaPermission(context, plugin)) {
      return const [];
    }
    if (!context.mounted) {
      return const [];
    }
    return switch (plugin.type) {
      MessageInputExtensionPluginType.photo => _pickAlbumImage(context),
      MessageInputExtensionPluginType.video => _pickAlbumVideo(context),
      MessageInputExtensionPluginType.camera => _pickCameraImage(context),
      MessageInputExtensionPluginType.filming => _pickCameraVideo(context),
      MessageInputExtensionPluginType.file => _pickFile(),
      _ => Future<List<_PickedInputMedia>>.value(const []),
    };
  }

  Future<List<_PickedInputMedia>> _pickAlbumImage(BuildContext context) async {
    final locale = Localizations.maybeLocaleOf(context);
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        requestType: RequestType.image,
        maxAssets: 50,
        textDelegate: assetPickerTextDelegateFromLocale(locale),
      ),
    );
    return _mediaFromAssets(assets);
  }

  Future<List<_PickedInputMedia>> _pickAlbumVideo(BuildContext context) async {
    final locale = Localizations.maybeLocaleOf(context);
    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        requestType: RequestType.video,
        maxAssets: 1,
        filterOptions: pm.FilterOptionGroup()
          ..setOption(
            pm.AssetType.video,
            const pm.FilterOption(
              durationConstraint: pm.DurationConstraint(
                max: Duration(seconds: 11),
              ),
            ),
          ),
        textDelegate: assetPickerTextDelegateFromLocale(locale),
      ),
    );
    final media = await _mediaFromAsset(assets?.firstOrNull);
    if (media == null) {
      return const [];
    }
    if (media.duration <= 10) {
      return [media];
    }
    if (context.mounted) {
      _showSnackBar(context, context.chatUIL10n.messageInputVideoTooLong);
    }
    return const [];
  }

  Future<List<_PickedInputMedia>> _pickCameraImage(BuildContext context) async {
    final locale = Localizations.maybeLocaleOf(context);
    final asset = await CameraPicker.pickFromCamera(
      context,
      pickerConfig: CameraPickerConfig(
        enableRecording: false,
        textDelegate: cameraPickerTextDelegateFromLocale(locale),
      ),
    );
    final media = await _mediaFromAsset(asset);
    return media == null ? const [] : [media];
  }

  Future<List<_PickedInputMedia>> _pickCameraVideo(BuildContext context) async {
    final locale = Localizations.maybeLocaleOf(context);
    final asset = await CameraPicker.pickFromCamera(
      context,
      pickerConfig: CameraPickerConfig(
        enableRecording: true,
        onlyEnableRecording: true,
        enableTapRecording: true,
        maximumRecordingDuration: Duration(seconds: 10),
        resolutionPreset: ResolutionPreset.high,
        textDelegate: cameraPickerTextDelegateFromLocale(locale),
      ),
      createPickerState: _shouldUseStabilizedCameraVideoPreview()
          ? _StabilizedCameraPickerState.new
          : null,
    );
    final media = await _mediaFromAsset(
      asset,
      resolveVideoDurationFromFile: true,
    );
    if (media == null) {
      return const [];
    }
    if (media.duration < 1) {
      if (context.mounted) {
        _showSnackBar(context, context.chatUIL10n.messageInputVideoTooShort);
      }
      return const [];
    }
    return [media];
  }

  Future<List<_PickedInputMedia>> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.firstOrNull?.path;
    if (path == null || path.isEmpty) {
      return const [];
    }
    return [_PickedInputMedia(path: path, mimeType: lookupMimeType(path))];
  }

  Future<List<_PickedInputMedia>> _mediaFromAssets(
    List<AssetEntity>? assets,
  ) async {
    if (assets == null || assets.isEmpty) {
      return const [];
    }
    final media = <_PickedInputMedia>[];
    for (final asset in assets) {
      final item = await _mediaFromAsset(asset);
      if (item != null) {
        media.add(item);
      }
    }
    return media;
  }

  Future<_PickedInputMedia?> _mediaFromAsset(
    AssetEntity? asset, {
    bool resolveVideoDurationFromFile = false,
  }) async {
    if (asset == null) {
      return null;
    }
    final mimeType = await _resolveAssetMimeType(asset);
    final title = await _resolveAssetTitle(asset);
    final isGif = _isGifMimeOrName(mimeType: mimeType, name: title);
    final file = isGif
        ? (await asset.originFile) ?? await asset.file
        : await asset.file;
    final path = file?.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    var duration = asset.duration;
    if (resolveVideoDurationFromFile) {
      duration = await _resolveVideoDurationInSeconds(path, fallback: duration);
    }
    return _PickedInputMedia(
      path: path,
      duration: duration,
      mimeType: mimeType ?? lookupMimeType(path),
    );
  }

  Future<String?> _resolveAssetMimeType(AssetEntity asset) async {
    final syncMimeType = asset.mimeType?.trim();
    if (syncMimeType != null && syncMimeType.isNotEmpty) {
      return syncMimeType;
    }
    try {
      final asyncMimeType = (await asset.mimeTypeAsync)?.trim() ?? "";
      if (asyncMimeType.isNotEmpty) {
        return asyncMimeType;
      }
    } catch (_) {}
    final title = await _resolveAssetTitle(asset);
    return title == null || title.isEmpty ? null : lookupMimeType(title);
  }

  Future<String?> _resolveAssetTitle(AssetEntity asset) async {
    final syncTitle = asset.title?.trim();
    if (syncTitle != null && syncTitle.isNotEmpty) {
      return syncTitle;
    }
    try {
      final asyncTitle = (await asset.titleAsync).trim();
      if (asyncTitle.isNotEmpty) {
        return asyncTitle;
      }
    } catch (_) {}
    return null;
  }

  bool _isGifMimeOrName({String? mimeType, String? name}) {
    final normalizedMime = mimeType?.toLowerCase();
    if (normalizedMime == 'image/gif') {
      return true;
    }
    return name?.toLowerCase().endsWith('.gif') == true;
  }

  Future<int> _resolveVideoDurationInSeconds(
    String path, {
    required int fallback,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      VideoPlayerController? controller;
      try {
        controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        final fileDuration = controller.value.duration.inSeconds;
        if (fileDuration > 0) {
          return fileDuration;
        }
      } catch (_) {
        // The media metadata might still be finalizing right after capture.
      } finally {
        await controller?.dispose();
      }
      await Future<void>.delayed(Duration(milliseconds: 120 + (attempt * 80)));
    }
    return fallback;
  }
}

bool _shouldUseStabilizedCameraVideoPreview() {
  return !kIsWeb && Platform.isAndroid;
}

class _StabilizedCameraPickerState extends CameraPickerState {
  @override
  Widget buildCaptureButton({
    required BuildContext context,
    required BoxConstraints constraints,
  }) {
    final keepTapStopTarget =
        enableTapRecording &&
        isRecordingVideo &&
        !MediaQuery.accessibleNavigationOf(context);
    final showProgressIndicator =
        keepTapStopTarget ||
        isCaptureButtonTapDown ||
        MediaQuery.accessibleNavigationOf(context);

    // wechat_camera_picker 4.5.0 hides the capture button while recording if
    // the press state is cleared, which can leave tap-to-record unable to stop.
    if (!showProgressIndicator && isRecordingVideo) {
      return const SizedBox.shrink();
    }

    const size = Size.square(82);
    return MergeSemantics(
      child: Semantics(
        label: isRecordingVideo
            ? textDelegate.sActionStopRecordingHint
            : textShootingButtonLabel,
        button: true,
        onTap: onTap,
        onTapHint: onTapHint,
        onLongPress: onLongPress,
        onLongPressHint: onLongPressHint,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerUp: onPointerUp,
          onPointerMove: onPointerMove(constraints),
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            onTapDown: (_) =>
                _setCaptureButtonState(() => isCaptureButtonTapDown = true),
            onTapUp: (_) => _setCaptureButtonState(() {
              if (!enableTapRecording) {
                isCaptureButtonTapDown = false;
              }
            }),
            onTapCancel: () =>
                _setCaptureButtonState(() => isCaptureButtonTapDown = false),
            onLongPressStart: (_) =>
                _setCaptureButtonState(() => isCaptureButtonTapDown = true),
            onLongPressEnd: (_) =>
                _setCaptureButtonState(() => isCaptureButtonTapDown = false),
            onLongPressCancel: () =>
                _setCaptureButtonState(() => isCaptureButtonTapDown = false),
            child: SizedBox.fromSize(
              size: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedContainer(
                    duration: const Duration(microseconds: 100),
                    padding: EdgeInsets.all(isCaptureButtonTapDown ? 16 : 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        strokeAlign: BorderSide.strokeAlignCenter,
                        width: 2,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  if (shouldCaptureButtonDisplay || keepTapStopTarget)
                    RotatedBox(
                      quarterTurns: enableScaledPreview
                          ? 0
                          : cameraQuarterTurns,
                      child: _RecordingProgressButton(
                        isAnimating:
                            showProgressIndicator && isShootingButtonAnimate,
                        duration:
                            pickerConfig.maximumRecordingDuration ??
                            const Duration(seconds: 15),
                        size: size,
                        ringsColor:
                            Theme.of(context).progressIndicatorTheme.color ??
                            Theme.of(context).colorScheme.primary,
                        ringsWidth: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setCaptureButtonState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  @override
  Future<AssetEntity?> pushToViewer({
    required XFile file,
    required CameraPickerViewType viewType,
  }) async {
    final FileImage? image;
    if (viewType == CameraPickerViewType.image) {
      image = FileImage(File(file.path));
      await precacheImage(image, context);
    } else {
      image = null;
    }
    if (viewType == CameraPickerViewType.video &&
        _shouldUseStabilizedCameraVideoPreview()) {
      await _waitForCapturedVideoFileToStabilize(file.path);
      await _warmUpCapturedVideoPreview(file.path);
    }
    if (!mounted) {
      return null;
    }
    final result = await CameraPickerViewer.pushToViewer(
      context,
      pickerConfig: pickerConfig,
      viewType: viewType,
      previewXFile: file,
      createViewerState:
          viewType == CameraPickerViewType.video &&
              _shouldUseStabilizedCameraVideoPreview()
          ? _StabilizedCameraPickerViewerState.new
          : null,
    );
    if (image != null) {
      PaintingBinding.instance.imageCache.evict(image);
    }
    return result;
  }

  Future<void> _waitForCapturedVideoFileToStabilize(String path) async {
    final file = File(path);
    var previousLength = -1;
    for (var attempt = 0; attempt < 8; attempt++) {
      if (await file.exists()) {
        final length = await file.length().catchError((_) => 0);
        if (length > 0 && length == previousLength) {
          return;
        }
        previousLength = length;
      }
      await Future<void>.delayed(Duration(milliseconds: 120 + (attempt * 40)));
    }
  }

  Future<void> _warmUpCapturedVideoPreview(String path) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      VideoPlayerController? controller;
      try {
        controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        return;
      } catch (_) {
        // Retry briefly while the vendor media stack finishes indexing.
      } finally {
        await controller?.dispose();
      }
      await Future<void>.delayed(Duration(milliseconds: 120 + (attempt * 80)));
    }
  }
}

class _StabilizedCameraPickerViewerState extends CameraPickerViewerState {
  @override
  Widget buildPreview(BuildContext context) {
    if (widget.viewType != CameraPickerViewType.video) {
      return super.buildPreview(context);
    }
    return MergeSemantics(
      child: Semantics(
        label: pickerConfig.textDelegate?.sActionPreviewHint ?? 'preview',
        image: true,
        onTapHint: pickerConfig.textDelegate?.sActionPreviewHint ?? 'preview',
        sortKey: const OrdinalSortKey(1),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _CoverVideoPlayer(controller: videoController),
            buildPlayControlButton(context),
          ],
        ),
      ),
    );
  }
}

class _CoverVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;

  const _CoverVideoPlayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final value = controller.value;
        final videoAspectRatio = _displayAspectRatio(value);
        final viewportAspectRatio = viewport.width / viewport.height;
        final coverSize = viewportAspectRatio > videoAspectRatio
            ? Size(viewport.width, viewport.width / videoAspectRatio)
            : Size(viewport.height * videoAspectRatio, viewport.height);
        return ClipRect(
          child: Center(
            child: SizedBox.fromSize(
              size: coverSize,
              child: RotatedBox(
                quarterTurns: _quarterTurns(value),
                child: VideoPlayer(controller),
              ),
            ),
          ),
        );
      },
    );
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
}

class _RecordingProgressButton extends StatefulWidget {
  final bool isAnimating;
  final Size size;
  final double ringsWidth;
  final Color ringsColor;
  final Duration duration;

  const _RecordingProgressButton({
    required this.isAnimating,
    required this.size,
    required this.ringsWidth,
    required this.ringsColor,
    required this.duration,
  });

  @override
  State<_RecordingProgressButton> createState() =>
      _RecordingProgressButtonState();
}

class _RecordingProgressButtonState extends State<_RecordingProgressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isAnimating) {
        _progressController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_RecordingProgressButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _progressController.duration = widget.duration;
    }
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _progressController.forward();
      } else {
        _progressController.stop();
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnimating) {
      return const SizedBox.shrink();
    }
    return SizedBox.fromSize(
      size: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _progressController,
          builder: (_, __) => CircularProgressIndicator(
            color: widget.ringsColor,
            strokeWidth: widget.ringsWidth,
            value: _progressController.value,
          ),
        ),
      ),
    );
  }
}
