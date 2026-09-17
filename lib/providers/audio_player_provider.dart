import 'dart:async';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import 'chat_provider.dart';

/// Playback state for voice-message audio.
enum NexconnAudioPlayerState { playing, paused, stopped }

/// Coordinates voice-message playback and exposes current audio state.
class NexconnAudioPlayerProvider with ChangeNotifier, WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _currentPlayingMessageId;
  final Set<String> _downloadingMessageIds = <String>{};
  final Map<String, int> _downloadProgressByMessageId = <String, int>{};
  NexconnAudioPlayerState _state = NexconnAudioPlayerState.stopped;
  bool _disposed = false;
  int _playRequestToken = 0;

  NexconnAudioPlayerProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  String? get currentPlayingMessageId => _currentPlayingMessageId;
  NexconnAudioPlayerState get state => _state;

  bool isVoiceMessageDownloading(HDVoiceMessage message) {
    return _downloadingMessageIds.contains(_messageKey(message));
  }

  int? voiceMessageDownloadProgress(HDVoiceMessage message) {
    return _downloadProgressByMessageId[_messageKey(message)];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(stopVoiceMessage());
    }
  }

  Future<void> playVoiceMessage(
    HDVoiceMessage message, [
    BuildContext? context,
  ]) async {
    final playableLocalPath = await _playableLocalPath(message.localPath);
    if (!kIsWeb && playableLocalPath == null) {
      if (context != null && context.mounted) {
        await downloadVoiceMessage(message, context, autoPlay: true);
        return;
      }
      await playVoiceMessagePath(
        localPath: null,
        remotePath: message.remotePath,
        messageKey: _messageKey(message),
        onMissingSource: null,
      );
      return;
    }
    await playVoiceMessagePath(
      localPath: playableLocalPath ?? message.localPath,
      remotePath: message.remotePath,
      messageKey: _messageKey(message),
      onMissingSource: context == null || !context.mounted
          ? null
          : () => downloadVoiceMessage(message, context, autoPlay: true),
    );
  }

  Future<void> playVoiceMessagePath({
    String? localPath,
    String? remotePath,
    required String messageKey,
    Future<void> Function()? onMissingSource,
  }) async {
    if (_disposed) {
      return;
    }
    final requestToken = ++_playRequestToken;
    if (_currentPlayingMessageId == messageKey &&
        _state == NexconnAudioPlayerState.playing) {
      await stopVoiceMessage();
      return;
    }
    if (_state == NexconnAudioPlayerState.playing) {
      await _stopVoiceMessage(
        invalidatePendingRequest: false,
        deactivateAudioSession: false,
      );
    }

    final resolvedSource = await _resolveAudioSource(
      localPath: localPath,
      remotePath: remotePath,
    );
    if (_disposed || requestToken != _playRequestToken) {
      return;
    }
    if (resolvedSource == null) {
      if (onMissingSource != null) {
        unawaited(onMissingSource());
      }
      return;
    }

    try {
      await _player.setAudioSource(resolvedSource.source);
      if (_disposed || requestToken != _playRequestToken) {
        return;
      }
      _currentPlayingMessageId = messageKey;
      _state = NexconnAudioPlayerState.playing;
      _safeNotifyListeners();
      await _playerStateSubscription?.cancel();
      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (_disposed ||
            requestToken != _playRequestToken ||
            state.processingState != ProcessingState.completed) {
          return;
        }
        unawaited(_finishCompletedPlayback(requestToken));
      });
      await _player.play();
    } catch (_) {
      if (requestToken != _playRequestToken) {
        return;
      }
      await _playerStateSubscription?.cancel();
      _playerStateSubscription = null;
      await _stopPlayer();
      await _deactivateAudioSession();
      _currentPlayingMessageId = null;
      _state = NexconnAudioPlayerState.stopped;
      _safeNotifyListeners();
      if (resolvedSource.isLocalFile && onMissingSource != null) {
        unawaited(onMissingSource());
      }
    }
  }

  Future<void> downloadVoiceMessage(
    HDVoiceMessage message,
    BuildContext context, {
    bool autoPlay = false,
  }) async {
    if (_disposed || !context.mounted) {
      return;
    }
    final messageKey = _messageKey(message);
    if (_downloadingMessageIds.contains(messageKey)) {
      return;
    }
    _downloadingMessageIds.add(messageKey);
    _downloadProgressByMessageId[messageKey] = 0;
    _safeNotifyListeners();
    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.downloadMediaMessage(
        message,
        onDownloading: (downloading, progress) {
          if (_disposed) {
            return;
          }
          _downloadProgressByMessageId[messageKey] = progress.clamp(0, 100);
          if (downloading.localPath?.isNotEmpty ?? false) {
            message.localPath = downloading.localPath;
          }
          _safeNotifyListeners();
        },
        onDownloaded: (downloaded) {
          if (!context.mounted || _disposed) {
            return;
          }
          if (downloaded.localPath?.isNotEmpty ?? false) {
            message.localPath = downloaded.localPath;
          }
          if (autoPlay) {
            unawaited(
              playVoiceMessagePath(
                localPath: downloaded.localPath ?? message.localPath,
                remotePath: downloaded.remotePath ?? message.remotePath,
                messageKey: messageKey,
                onMissingSource: null,
              ),
            );
          } else {
            _safeNotifyListeners();
          }
        },
      );
    } finally {
      _downloadingMessageIds.remove(messageKey);
      _downloadProgressByMessageId.remove(messageKey);
      _safeNotifyListeners();
    }
  }

  Future<void> stopVoiceMessage({
    bool notify = true,
    bool invalidatePendingRequest = true,
  }) {
    return _stopVoiceMessage(
      notify: notify,
      invalidatePendingRequest: invalidatePendingRequest,
    );
  }

  Future<void> _stopVoiceMessage({
    bool notify = true,
    bool invalidatePendingRequest = true,
    bool deactivateAudioSession = true,
  }) async {
    if (_disposed) {
      return;
    }
    if (invalidatePendingRequest) {
      _playRequestToken++;
    }
    _currentPlayingMessageId = null;
    _state = NexconnAudioPlayerState.stopped;
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    await _stopPlayer();
    if (deactivateAudioSession) {
      await _deactivateAudioSession();
    }
    if (notify) {
      _safeNotifyListeners();
    }
  }

  String _messageKey(HDVoiceMessage message) {
    return message.messageId ??
        message.clientId?.toString() ??
        '${message.channelId}:${message.sentTime}:${message.senderUserId}';
  }

  Future<String?> _playableLocalPath(String? rawPath) async {
    if (rawPath == null || rawPath.isEmpty || kIsWeb) {
      return null;
    }
    var path = rawPath.startsWith('file://') ? rawPath.substring(7) : rawPath;
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    if (await _shouldCreateM4aCompatibilityCopy(file)) {
      final dir = file.parent;
      final name = file.uri.pathSegments.last.split('.').first;
      final copyPath =
          '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final copy = File(copyPath);
      if (!copy.existsSync()) {
        await file.copy(copyPath);
      }
      path = copyPath;
    }
    return path;
  }

  Future<bool> _shouldCreateM4aCompatibilityCopy(File file) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final fileName = file.uri.pathSegments.last;
    if (fileName.toLowerCase().endsWith('.m4a')) {
      return false;
    }
    if (!fileName.contains('.')) {
      return true;
    }
    return _isMpeg4Container(file);
  }

  Future<bool> _isMpeg4Container(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final header = await handle.read(12);
      return header.length >= 8 &&
          header[4] == 0x66 &&
          header[5] == 0x74 &&
          header[6] == 0x79 &&
          header[7] == 0x70;
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }

  Future<_ResolvedAudioSource?> _resolveAudioSource({
    String? localPath,
    String? remotePath,
  }) async {
    final filePath = await _playableLocalPath(localPath);
    if (filePath != null) {
      return _ResolvedAudioSource(
        source: AudioSource.uri(Uri.parse(Uri.file(filePath).toString())),
        isLocalFile: true,
      );
    }
    final remoteUri = _playableRemoteUri(remotePath);
    if (remoteUri != null) {
      return _ResolvedAudioSource(
        source: AudioSource.uri(remoteUri),
        isLocalFile: false,
      );
    }
    return null;
  }

  Uri? _playableRemoteUri(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(rawPath);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https' || scheme == 'file') {
      return uri;
    }
    return null;
  }

  Future<void> _finishCompletedPlayback(int requestToken) async {
    if (_disposed || requestToken != _playRequestToken) {
      return;
    }
    _currentPlayingMessageId = null;
    _state = NexconnAudioPlayerState.stopped;
    await _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    await _stopPlayer();
    await _deactivateAudioSession();
    _safeNotifyListeners();
  }

  Future<void> _stopPlayer() async {
    try {
      await _player.stop();
    } catch (_) {
      // Audio focus cleanup should still run even if the platform player fails.
    }
  }

  Future<void> _deactivateAudioSession() async {
    if (kIsWeb) {
      return;
    }
    try {
      final session = await AudioSession.instance;
      await session.setActive(
        false,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
    } catch (_) {
      // Best effort: unsupported platforms or native audio errors should not
      // break message playback state cleanup.
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    final shouldDeactivateAudioSession =
        _state == NexconnAudioPlayerState.playing ||
        _player.playerState.playing;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    unawaited(
      _disposePlayer(deactivateAudioSession: shouldDeactivateAudioSession),
    );
    super.dispose();
  }

  Future<void> _disposePlayer({required bool deactivateAudioSession}) async {
    await _stopPlayer();
    if (deactivateAudioSession) {
      await _deactivateAudioSession();
    }
    await _player.dispose();
  }
}

class _ResolvedAudioSource {
  final AudioSource source;
  final bool isLocalFile;

  const _ResolvedAudioSource({required this.source, required this.isLocalFile});
}
