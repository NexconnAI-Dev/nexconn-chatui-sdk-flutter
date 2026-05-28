part of '../message_list_widget.dart';

extension _MessageListEvents on _MessageListWidgetState {
  static const int _mentionScrollRetryLimit = 6;

  void _handleMessageEvent() {
    if (!mounted) {
      return;
    }
    final provider = _chatProvider;
    if (provider == null) {
      return;
    }
    final message = _engineProvider?.receivedMessageNotifier.value;
    if (message == null) {
      return;
    }
    final messageIdentifier = message.channelIdentifier;
    if (messageIdentifier == null ||
        !_isSameChannelIdentifier(
          messageIdentifier,
          widget.channel.channelIdentifier,
        )) {
      return;
    }
    final asyncListener = widget.config.onAsyncMessageReceived;
    if (asyncListener != null) {
      Future.sync(() => asyncListener(context, message));
    }
    if (_isNearBottom(provider) && _isLatestMessageFullyVisible(provider)) {
      _scheduleStableScrollToBottom(provider);
    }
  }

  void _handleTypingEvent() {
    if (!mounted) {
      return;
    }
    final event = _engineProvider?.typingStatusNotifier.value;
    if (event == null ||
        !_isSameChannelIdentifier(
          event.channelIdentifier,
          widget.channel.channelIdentifier,
        )) {
      if (_typingStatusEvent != null && mounted) {
        _setMessageListState(() => _typingStatusEvent = null);
      } else {
        _typingStatusEvent = null;
      }
      return;
    }
    if (mounted) {
      _setMessageListState(() => _typingStatusEvent = event);
    } else {
      _typingStatusEvent = event;
    }
  }

  bool _showTypingTip(ChatProvider provider) {
    final event = _typingStatusEvent;
    return widget.config.messageListConfig.showTypingStatusTip &&
        !_isOffline(provider.connectionStatus) &&
        event != null &&
        _isSameChannelIdentifier(
          event.channelIdentifier,
          widget.channel.channelIdentifier,
        ) &&
        (event.userTypingStatus?.isNotEmpty ?? false);
  }

  Future<void> _handleUnreadMentionedTipTap(ChatProvider provider) async {
    if (provider.unreadMentionedMessages.isEmpty) {
      return;
    }
    _clearPreserveBottomForInputTransition();
    final targetMessage = provider.unreadMentionedMessages.last;
    final initialContext =
        _messageItemKeys[_messageKey(targetMessage)]?.currentContext;
    if (initialContext != null) {
      await Scrollable.ensureVisible(
        initialContext,
        alignment: 0,
        duration: const Duration(milliseconds: 100),
      );
      return;
    }
    var targetIndex = provider.messages.indexWhere(
      (message) => _isSameMessage(message, targetMessage),
    );
    if (targetIndex < 0) {
      final didLoadTarget = await _loadUnreadMentionedTargetIntoView(
        provider,
        targetMessage,
      );
      if (!didLoadTarget) {
        return;
      }
      targetIndex = provider.messages.indexWhere(
        (message) => _isSameMessage(message, targetMessage),
      );
      if (targetIndex < 0) {
        return;
      }
    }
    final resolvedContext = await _scrollTargetMessageIntoView(
      provider,
      targetMessage,
      targetIndex,
    );
    if (resolvedContext == null || !resolvedContext.mounted) {
      return;
    }
    await Scrollable.ensureVisible(
      resolvedContext,
      alignment: 0,
      duration: const Duration(milliseconds: 100),
    );
  }

  Future<void> _handleReferenceMessageTap(
    ChatProvider provider,
    Message targetMessage,
  ) async {
    _clearPreserveBottomForInputTransition();
    final initialContext =
        _messageItemKeys[_messageKey(targetMessage)]?.currentContext;
    if (initialContext != null) {
      await Scrollable.ensureVisible(
        initialContext,
        alignment: 0,
        duration: const Duration(milliseconds: 100),
      );
      return;
    }
    var targetIndex = provider.messages.indexWhere(
      (message) => _isSameMessage(message, targetMessage),
    );
    if (targetIndex < 0) {
      final didLoadTarget = await _loadUnreadMentionedTargetIntoView(
        provider,
        targetMessage,
      );
      if (!didLoadTarget) {
        return;
      }
      targetIndex = provider.messages.indexWhere(
        (message) => _isSameMessage(message, targetMessage),
      );
      if (targetIndex < 0) {
        return;
      }
    }
    final resolvedContext = await _scrollTargetMessageIntoView(
      provider,
      targetMessage,
      targetIndex,
    );
    if (resolvedContext == null || !resolvedContext.mounted) {
      return;
    }
    await Scrollable.ensureVisible(
      resolvedContext,
      alignment: 0,
      duration: const Duration(milliseconds: 100),
    );
  }

  Future<bool> _loadUnreadMentionedTargetIntoView(
    ChatProvider provider,
    Message targetMessage,
  ) async {
    const maxLoadAttempts = 10;
    for (var attempt = 0; attempt < maxLoadAttempts; attempt++) {
      if (!mounted || !provider.hasMore) {
        break;
      }
      await _loadOlderMessagesPreservingAnchor(provider);
      final targetIndex = provider.messages.indexWhere(
        (message) => _isSameMessage(message, targetMessage),
      );
      if (targetIndex >= 0) {
        return true;
      }
    }
    return provider.messages.any(
      (message) => _isSameMessage(message, targetMessage),
    );
  }

  String _typingStatusText(BuildContext context, MessageListConfig config) {
    final typingUsers = _typingStatusEvent?.userTypingStatus;
    final userId = typingUsers == null || typingUsers.isEmpty
        ? null
        : typingUsers.first.userId;
    if (userId == null ||
        userId.isEmpty ||
        userId == widget.channel.channelId) {
      return config.typingStatusTipText ??
          context.chatUIL10n.chatTypingStatusTip;
    }
    return '$userId ${config.typingStatusTipText ?? context.chatUIL10n.chatTypingStatusTip}';
  }

  Future<BuildContext?> _scrollTargetMessageIntoView(
    ChatProvider provider,
    Message targetMessage,
    int targetIndex,
  ) async {
    if (!_itemScrollController.isAttached || provider.messages.isEmpty) {
      return null;
    }
    final overallIndex = _messageOverallIndex(provider, targetIndex);
    await _jumpToOverallIndex(overallIndex, 0);
    final maxAttempts = provider.messages.length.clamp(
      _mentionScrollRetryLimit,
      32,
    );
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) {
        return null;
      }
      await WidgetsBinding.instance.endOfFrame;
      final context =
          _messageItemKeys[_messageKey(targetMessage)]?.currentContext;
      if (context != null && context.mounted) {
        return context;
      }
      if (!_itemScrollController.isAttached) {
        continue;
      }
      _itemScrollController.jumpTo(index: overallIndex, alignment: 0);
    }
    return _messageItemKeys[_messageKey(targetMessage)]?.currentContext;
  }

  bool _isSameMessage(Message a, Message b) {
    if (identical(a, b)) {
      return true;
    }
    final aId = a.messageId;
    final bId = b.messageId;
    if (aId != null && aId.isNotEmpty && aId == bId) {
      return true;
    }
    return _messageKey(a) == _messageKey(b);
  }
}
