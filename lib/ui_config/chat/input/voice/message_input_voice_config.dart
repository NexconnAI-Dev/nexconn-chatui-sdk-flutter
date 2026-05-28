part of '../message_input_config.dart';

/// Recorded voice payload ready to send.
class MessageInputVoiceDraft {
  /// Local audio file path.
  final String path;

  /// Duration in seconds passed to the voice message params.
  final int duration;

  /// Exact recorded duration when available.
  final Duration? recordedDuration;

  const MessageInputVoiceDraft({
    required this.path,
    required this.duration,
    this.recordedDuration,
  });
}

/// Produces a voice draft after recording completes.
typedef MessageInputVoiceDraftResolver =
    FutureOr<MessageInputVoiceDraft?> Function(BuildContext context);

/// Recorder abstraction used by MessageInputWidget.
abstract class MessageInputVoiceRecorder {
  /// Requests microphone permission before recording.
  Future<bool> requestPermission(BuildContext context);

  /// Starts a recording session.
  Future<void> start(BuildContext context);

  /// Stops recording and returns the captured voice draft.
  Future<MessageInputVoiceDraft?> stop();

  /// Cancels recording and discards the current file.
  Future<void> cancel();

  /// Deletes a recorded file that should not be sent.
  Future<void> discard(String path);
}

/// Error thrown when voice recording is unavailable.
class MessageInputVoiceRecorderUnavailable implements Exception {
  /// Underlying platform or plugin error.
  final Object? cause;

  const MessageInputVoiceRecorderUnavailable([this.cause]);
}

/// Default voice recorder backed by the record package.
class MessageInputDefaultVoiceRecorder implements MessageInputVoiceRecorder {
  AudioRecorder? _recorder;
  String? _path;
  DateTime? _startedAt;

  @override
  Future<bool> requestPermission(BuildContext context) async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }
      final result = await Permission.microphone.request();
      return result.isGranted || result.isLimited;
    } on MissingPluginException catch (error) {
      throw MessageInputVoiceRecorderUnavailable(error);
    }
  }

  @override
  Future<void> start(BuildContext context) async {
    final path = await _createTemporaryPath();
    final recorder = AudioRecorder();
    try {
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } on MissingPluginException catch (error) {
      await recorder.dispose();
      throw MessageInputVoiceRecorderUnavailable(error);
    }
    _recorder = recorder;
    _path = path;
    _startedAt = DateTime.now();
  }

  @override
  Future<MessageInputVoiceDraft?> stop() async {
    final recorder = _recorder;
    final startedAt = _startedAt;
    if (recorder == null || startedAt == null) {
      return null;
    }
    final outputPath = await recorder.stop();
    await recorder.dispose();
    final elapsed = DateTime.now().difference(startedAt);
    final duration = elapsed.inSeconds;
    final path = outputPath ?? _path;
    _clearSession();
    if (path == null || path.isEmpty) {
      return null;
    }
    return MessageInputVoiceDraft(
      path: path,
      duration: duration,
      recordedDuration: elapsed,
    );
  }

  @override
  Future<void> cancel() async {
    final recorder = _recorder;
    final path = _path;
    if (recorder != null) {
      await recorder.cancel();
      await recorder.dispose();
    }
    _clearSession();
    if (path != null) {
      await discard(path);
    }
  }

  @override
  Future<void> discard(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Temporary recording cleanup is best effort.
    }
  }

  Future<String> _createTemporaryPath() async {
    try {
      final directory = await getTemporaryDirectory();
      return '${directory.path}/nexconn_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    } on MissingPluginException catch (error) {
      throw MessageInputVoiceRecorderUnavailable(error);
    }
  }

  void _clearSession() {
    _recorder = null;
    _path = null;
    _startedAt = null;
  }
}
