part of '../message_list_widget.dart';

extension _MessageListMessageMenuOperations on _MessageListWidgetState {
  String _messageKey(Message message) {
    final messageId = message.messageId;
    if (messageId != null && messageId.isNotEmpty) {
      return messageId;
    }
    return '${message.channelType?.name}-${message.channelId}-${message.sentTime}-${identityHashCode(message)}';
  }

  Future<void> _copyMessage(
    BuildContext context,
    ChatProvider provider,
    Message message,
  ) async {
    final menu = widget.config.longPressMenuConfig;
    final copyText = ChatProvider.extractCopyText(message);
    if (copyText == null || copyText.isEmpty) {
      return;
    }
    if (menu.onCopy != null) {
      await menu.onCopy!(context, provider.channel, message, copyText);
      return;
    }
    await provider.copyMessage(message, overrideText: copyText);
  }

  Future<void> _deleteMessage(
    BuildContext context,
    ChatProvider provider,
    Message message,
  ) async {
    final menu = widget.config.longPressMenuConfig;
    if (menu.onDelete != null) {
      await menu.onDelete!(context, provider.channel, message);
      return;
    }
    NCError? error;
    if (!_isSystemChannelMessage(message) &&
        _shouldForceDeleteForMeMessage(provider, message)) {
      error = await provider.deleteMessageForMe(message);
    } else {
      switch (menu.deleteBehavior) {
        case ChatMessageDeleteBehavior.forMe:
          error = await provider.deleteMessageForMe(message);
        case ChatMessageDeleteBehavior.forAll:
          error = await provider.deleteMessageForAll(message);
        case ChatMessageDeleteBehavior.custom:
          return;
      }
    }
    if (!context.mounted || error == null || error.code == 0) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message ?? context.chatUIL10n.chatDeleteFailed),
      ),
    );
  }

  Future<void> _deleteMessageForAll(
    BuildContext context,
    ChatProvider provider,
    Message message,
  ) async {
    final menu = widget.config.longPressMenuConfig;
    if (menu.onDeleteForAll != null) {
      await menu.onDeleteForAll!(context, provider.channel, message);
      return;
    }
    final isConnected =
        _engineProvider?.connectionStatus == ConnectionStatus.connected;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.chatUIL10n.chatNetworkUnavailable)),
      );
      return;
    }
    final error = await provider.deleteMessageForAll(message);
    if (!context.mounted || error == null || error.code == 0) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message ?? context.chatUIL10n.chatDeleteFailed),
      ),
    );
  }

  bool _canCopyMessage(Message message) {
    final copyText = ChatProvider.extractCopyText(message);
    return copyText != null && copyText.isNotEmpty;
  }

  bool _canDeleteForAllMessage(ChatProvider provider, Message message) {
    return _isOwnSentActionableMessage(message) &&
        provider.isMessageWithinDeleteForAllWindowForCurrentServerTime(
          message.sentTime,
        );
  }

  bool _shouldForceDeleteForMeMessage(ChatProvider provider, Message message) {
    return _isOwnSentActionableMessage(message) &&
        !provider.isMessageWithinDeleteForAllWindowForCurrentServerTime(
          message.sentTime,
        );
  }

  bool _isOwnSentActionableMessage(Message message) {
    return message.direction == MessageDirection.send &&
        message.messageType != MessageType.recall &&
        message.sentStatus != SentStatus.sending &&
        message.sentStatus != SentStatus.failed &&
        message.sentStatus != SentStatus.canceled;
  }

  bool _canReferenceMessage(Message message) {
    if (_isSendingMessage(message)) {
      return false;
    }
    return message.messageType != MessageType.recall &&
        message is! CombineMessage &&
        message is! HDVoiceMessage &&
        message is! ShortVideoMessage &&
        message.messageType != MessageType.voice;
  }

  bool _isSendingMessage(Message message) {
    return message.sentStatus == SentStatus.sending;
  }

  bool _isSystemChannelMessage(Message message) {
    return widget.channel.channelType == ChannelType.system ||
        message.channelType == ChannelType.system;
  }
}
