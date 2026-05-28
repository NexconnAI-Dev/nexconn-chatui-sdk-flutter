part of '../message_input_widget.dart';

extension _MessageInputVoiceFeedback on _MessageInputWidgetState {
  bool _isVoiceDraftTooShort(MessageInputVoiceDraft draft) {
    final minimum = widget.config.minimumVoiceRecordingDuration;
    if (minimum <= Duration.zero) {
      return false;
    }
    final recordedDuration = draft.recordedDuration;
    if (recordedDuration != null) {
      return recordedDuration < minimum;
    }
    return draft.duration * Duration.millisecondsPerSecond <
        minimum.inMilliseconds;
  }

  bool _isVoiceDraftTooLong(MessageInputVoiceDraft draft) {
    final maximum = widget.config.maximumVoiceRecordingDuration;
    if (maximum <= Duration.zero) {
      return false;
    }
    final allowed = maximum + const Duration(seconds: 1);
    final recordedDuration = draft.recordedDuration;
    if (recordedDuration != null) {
      return recordedDuration > allowed;
    }
    return draft.duration > allowed.inSeconds;
  }

  void _showVoicePermissionDenied(
    BuildContext context,
    MessageInputProvider input,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.chatUIL10n.messageInputVoicePermissionDenied),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
    input.clearVoiceRecordingState();
  }

  void _showVoiceTooShort(BuildContext context, MessageInputProvider input) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.chatUIL10n.messageInputVoiceTooShort),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
    input.clearVoiceRecordingState();
  }

  void _showVoiceTooLong(BuildContext context, MessageInputProvider input) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.chatUIL10n.messageInputVoiceTooLong),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
    input.clearVoiceRecordingState();
  }

  void _showVoiceRecordFailed(
    BuildContext context,
    MessageInputProvider input,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.chatUIL10n.messageInputVoiceRecordFailed),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
    input.clearVoiceRecordingState();
  }

  void _showVoiceUnavailable(BuildContext context, MessageInputProvider input) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.config.voiceInputUnavailableText ??
              context.chatUIL10n.messageInputVoiceUnavailable,
        ),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
    input.clearVoiceRecordingState();
  }
}
