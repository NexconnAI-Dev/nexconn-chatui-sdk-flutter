part of '../message_list_widget.dart';

extension _MessageListMessageMenuActions on _MessageListWidgetState {
  void _handleMessageTap(
    BuildContext context,
    ChatProvider provider,
    Message message,
  ) {
    if (provider.multiSelectMode) {
      final changed = provider.toggleMessageSelected(message);
      if (!changed) {
        _showSelectionLimitTip(context);
      }
      return;
    }
    final customTap = widget.onMessageTap;
    if (customTap != null) {
      customTap(message);
      return;
    }
    if (message is CombineMessage) {
      if (_isVoiceRecordingActive(context)) {
        return;
      }
      NexconnAudioPlayerProvider? audioPlayerProvider;
      try {
        audioPlayerProvider = context.read<NexconnAudioPlayerProvider>();
      } on ProviderNotFoundException {
        audioPlayerProvider = null;
      }
      pushNexconnChatUINamedRouteOr<void>(
        context,
        NexconnChatUIRoutes.combineMessageDetail,
        arguments: NexconnCombineMessageDetailRouteArguments(
          message: message,
          config: widget.config,
          provider: provider,
          audioPlayerProvider: audioPlayerProvider,
        ),
        fallbackRoute: () => MaterialPageRoute<void>(
          builder: (_) => _buildCombineDetailPage(
            provider: provider,
            audioPlayerProvider: audioPlayerProvider,
            message: message,
          ),
        ),
      );
    }
  }

  bool _isVoiceRecordingActive(BuildContext context) {
    try {
      return context.read<MessageInputProvider>().isVoiceRecording;
    } on ProviderNotFoundException {
      return false;
    }
  }

  Widget _buildCombineDetailPage({
    required ChatProvider provider,
    required NexconnAudioPlayerProvider? audioPlayerProvider,
    required CombineMessage message,
  }) {
    final detail = CombineMessageDetailPage(
      message: message,
      config: widget.config,
    );
    if (audioPlayerProvider == null) {
      return ChangeNotifierProvider<ChatProvider>.value(
        value: provider,
        child: detail,
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: provider),
        ChangeNotifierProvider<NexconnAudioPlayerProvider>.value(
          value: audioPlayerProvider,
        ),
      ],
      child: detail,
    );
  }
}
