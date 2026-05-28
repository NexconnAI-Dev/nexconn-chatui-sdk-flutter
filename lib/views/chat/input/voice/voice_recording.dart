// ignore_for_file: use_build_context_synchronously

part of '../message_input_widget.dart';

extension _MessageInputVoiceRecording on _MessageInputWidgetState {
  Future<void> _sendVoiceDraft(
    BuildContext context,
    MessageInputProvider input,
  ) async {
    final resolver = widget.config.voiceDraftResolver;
    if (resolver == null) {
      return;
    }
    final draft = await resolver(context);
    if (!mounted || draft == null) {
      return;
    }
    final currentContext = this.context;
    final chat = currentContext.read<ChatProvider>();
    await chat.sendVoiceMessage(draft.path, draft.duration);
  }

  void _handleVoicePointerDown(
    BuildContext context,
    MessageInputProvider input,
  ) {
    if (widget.config.voiceDraftResolver != null) {
      unawaited(_stopActiveVoicePlaybackIfNeeded(context));
      input.setVoiceRecordingState(MessageInputVoiceRecordingState.sending);
      return;
    }
    if (input.isVoiceRecording) {
      return;
    }
    input.setVoiceRecordingState(MessageInputVoiceRecordingState.sending);
    _voiceStartOperation = _startBuiltInVoiceRecording(context, input);
    unawaited(_voiceStartOperation);
  }

  void _handleVoicePointerMove(
    BuildContext context,
    MessageInputProvider input,
    PointerMoveEvent event,
  ) {
    if (!input.isVoiceRecording) {
      return;
    }
    final screenHeight = MediaQuery.of(context).size.height;
    final isCanceling =
        event.position.dy < screenHeight - kVoiceRecordingBackgroundHeight;
    input.setVoiceRecordingState(
      isCanceling
          ? MessageInputVoiceRecordingState.canceling
          : MessageInputVoiceRecordingState.sending,
    );
  }

  Future<void> _handleVoicePointerUp(
    BuildContext context,
    MessageInputProvider input,
  ) async {
    if (!input.isVoiceRecording) {
      return;
    }
    final shouldSend = !input.isVoiceCanceling;
    input.clearVoiceRecordingState();
    if (widget.config.voiceDraftResolver != null) {
      if (shouldSend) {
        await _sendVoiceDraft(context, input);
      }
      return;
    }
    await _finishBuiltInVoiceRecording(context, input, shouldSend: shouldSend);
  }

  Future<void> _startBuiltInVoiceRecording(
    BuildContext context,
    MessageInputProvider input,
  ) async {
    final recorder =
        widget.config.voiceRecorder ?? MessageInputDefaultVoiceRecorder();
    try {
      await _stopActiveVoicePlaybackIfNeeded(context);
      if (!mounted) {
        return;
      }
      final isGranted = await recorder.requestPermission(context);
      if (!mounted) {
        return;
      }
      if (!isGranted) {
        _showVoicePermissionDenied(context, input);
        return;
      }
      await recorder.start(context);
      if (!mounted) {
        await recorder.cancel();
        return;
      }
      _activeVoiceRecorder = recorder;
      _scheduleVoiceMaximumDurationFinish(context, input);
    } on MessageInputVoiceRecorderUnavailable {
      if (!mounted) {
        return;
      }
      _showVoiceUnavailable(context, input);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showVoiceRecordFailed(context, input);
    }
  }

  Future<void> _finishBuiltInVoiceRecording(
    BuildContext context,
    MessageInputProvider input, {
    required bool shouldSend,
  }) async {
    final startOperation = _voiceStartOperation;
    if (startOperation != null) {
      await startOperation;
    }
    final recorder = _activeVoiceRecorder;
    _activeVoiceRecorder = null;
    _voiceStartOperation = null;
    _voiceMaximumDurationTimer?.cancel();
    _voiceMaximumDurationTimer = null;
    if (recorder == null) {
      return;
    }
    if (!shouldSend) {
      await recorder.cancel();
      return;
    }
    final draft = await recorder.stop();
    if (!mounted || draft == null) {
      return;
    }
    if (_isVoiceDraftTooShort(draft)) {
      await recorder.discard(draft.path);
      if (!mounted) {
        return;
      }
      _showVoiceTooShort(context, input);
      return;
    }
    if (_isVoiceDraftTooLong(draft)) {
      await recorder.discard(draft.path);
      if (!mounted) {
        return;
      }
      _showVoiceTooLong(context, input);
      return;
    }
    final currentContext = this.context;
    final chat = currentContext.read<ChatProvider>();
    await chat.sendVoiceMessage(draft.path, draft.duration);
  }

  Future<void> _cancelActiveVoiceRecording() async {
    final startOperation = _voiceStartOperation;
    if (startOperation != null) {
      await startOperation;
    }
    final recorder = _activeVoiceRecorder;
    _activeVoiceRecorder = null;
    _voiceStartOperation = null;
    _voiceMaximumDurationTimer?.cancel();
    _voiceMaximumDurationTimer = null;
    await recorder?.cancel();
  }

  void _scheduleVoiceMaximumDurationFinish(
    BuildContext context,
    MessageInputProvider input,
  ) {
    _voiceMaximumDurationTimer?.cancel();
    final maximum = widget.config.maximumVoiceRecordingDuration;
    if (maximum <= Duration.zero) {
      return;
    }
    _voiceMaximumDurationTimer = Timer(maximum, () {
      if (!mounted || !input.isVoiceRecording) {
        return;
      }
      input.clearVoiceRecordingState();
      unawaited(_finishBuiltInVoiceRecording(context, input, shouldSend: true));
    });
  }

  Future<void> _stopActiveVoicePlaybackIfNeeded(BuildContext context) async {
    NexconnAudioPlayerProvider? audioPlayer;
    try {
      audioPlayer = context.read<NexconnAudioPlayerProvider>();
    } on ProviderNotFoundException {
      audioPlayer = null;
    }
    if (audioPlayer == null) {
      return;
    }
    try {
      await audioPlayer.stopVoiceMessage();
    } catch (_) {
      // Best-effort stop to avoid blocking voice recording on playback state.
    }
  }
}
