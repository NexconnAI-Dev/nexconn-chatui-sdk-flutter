part of '../message_bubble.dart';

extension _MessageBubbleVoiceMessageMediaBubble on _MessageBubbleBase {
  Widget _voiceBubble(
    BuildContext context,
    HDVoiceMessage voice,
    MessageStyleConfig style,
  ) {
    final duration = voice.duration ?? 0;
    final durationTextStyle = _voiceDurationTextStyle(style);
    final width = _voiceBubbleWidth(context, duration, durationTextStyle);
    final isSent = _messageDirection() == MessageDirection.send;
    final player = _maybeAudioPlayerProvider(context, listen: true);
    final hasLocalFile = _hasPlayableVoiceFile(voice.localPath);
    final isPlaying =
        player?.currentPlayingMessageId == _messageKey(voice) &&
        player?.state == NexconnAudioPlayerState.playing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleVoiceTap(context, voice),
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isSent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isSent)
            _voiceLeadingIcon(
              isPlaying: isPlaying,
              hasLocalFile: hasLocalFile,
              isSent: false,
              voice: voice,
            ),
          SizedBox(
            key: MessageBubble.voiceDurationWidthKey,
            width: width + kBubbleVoiceDurationPadding,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kBubbleVoiceDurationPadding,
              ),
              child: Text(
                voiceMessageDurationText(duration),
                maxLines: 1,
                textAlign: isSent ? TextAlign.right : TextAlign.left,
                style: durationTextStyle,
              ),
            ),
          ),
          if (isSent)
            _voiceLeadingIcon(
              isPlaying: isPlaying,
              hasLocalFile: hasLocalFile,
              isSent: true,
              voice: voice,
            ),
        ],
      ),
    );
  }

  Widget _voiceLeadingIcon({
    required bool isPlaying,
    required bool hasLocalFile,
    required bool isSent,
    required HDVoiceMessage voice,
  }) {
    final iconAsset = isSent
        ? 'NexconnLightIcon/voice_message_send.png'
        : 'voice_message_icon_receive.png';
    if (hasLocalFile || _hasPlayableRemoteVoice(voice.remotePath)) {
      return ChatUIAsset.image(
        isPlaying
            ? (isSent ? 'voice_playing_send.gif' : 'voice_playing_receive.gif')
            : iconAsset,
        height: MessageBubble._voiceIconLegacySize,
      );
    }
    return ChatUIAsset.image(
      iconAsset,
      height: MessageBubble._voiceIconLegacySize,
    );
  }

  Widget _voiceDownloadIndicator({
    required int? progress,
    required Color color,
    required Color backgroundColor,
  }) {
    final normalizedProgress = progress?.clamp(0, 100);
    final indicatorValue = normalizedProgress == null || normalizedProgress <= 0
        ? null
        : normalizedProgress / 100;
    return SizedBox(
      width: 10,
      height: 10,
      child: CircularProgressIndicator(
        value: indicatorValue,
        strokeWidth: 1.5,
        color: color,
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget? _voiceBubbleDownloadIndicator(BuildContext context) {
    if (message is! HDVoiceMessage) {
      return null;
    }
    final player = _maybeAudioPlayerProvider(context, listen: true);
    final voice = message as HDVoiceMessage;
    if (player == null || !player.isVoiceMessageDownloading(voice)) {
      return null;
    }
    final colorScheme = Theme.of(context).colorScheme;
    return _voiceDownloadIndicator(
      progress: player.voiceMessageDownloadProgress(voice),
      color: colorScheme.primary,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.18),
    );
  }

  TextStyle _voiceDurationTextStyle(MessageStyleConfig style) {
    return (style.textStyle ?? const TextStyle()).copyWith(
      color: style.textColor,
      fontSize: kBubbleVoiceDurationFontSize,
    );
  }

  double _voiceBubbleWidth(
    BuildContext context,
    int duration,
    TextStyle textStyle,
  ) => voiceMessageDurationWidth(context, duration, textStyle);

  void _handleVoiceTap(BuildContext context, HDVoiceMessage voice) {
    final provider = _maybeChatProvider(context);
    if (provider?.multiSelectMode == true) {
      onTap?.call();
      return;
    }
    final player = _maybeAudioPlayerProvider(context);
    if (player == null) {
      onTap?.call();
      return;
    }
    player.playVoiceMessage(voice, context).ignore();
  }

  MessageDirection? _messageDirection() {
    try {
      return message.direction;
    } on NoSuchMethodError {
      return null;
    }
  }

  bool _hasPlayableVoiceFile(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return false;
    }
    final path = rawPath.startsWith('file://') ? rawPath.substring(7) : rawPath;
    return File(path).existsSync();
  }

  bool _hasPlayableRemoteVoice(String? rawPath) {
    if (rawPath == null || rawPath.isEmpty) {
      return false;
    }
    return rawPath.startsWith(RegExp(r'https?://', caseSensitive: false));
  }
}
