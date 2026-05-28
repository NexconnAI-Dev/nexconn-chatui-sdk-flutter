part of '../message_list_widget.dart';

extension _MessageListMessageScrollController on _MessageListWidgetState {
  bool _showNetworkTip(ChatProvider provider) {
    // Chat pages should not render a built-in offline banner. The channel list
    // can still surface connection issues, but the message list itself should
    // stay focused on message content even when the SDK reports offline states.
    return false;
  }

  bool _shouldHandlePullRefreshNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics.axisDirection != AxisDirection.down) {
      return false;
    }
    return metrics.extentBefore == 0;
  }

  Future<void> _loadOlderMessagesPreservingAnchor(ChatProvider provider) async {
    if (_isRefreshingOlderMessages ||
        !provider.hasMore ||
        provider.isLoadingMore) {
      return;
    }
    _clearPreserveBottomForInputTransition();
    _isRefreshingOlderMessages = true;
    _isLoadingOlderWithAnchor = true;
    _cancelPendingBottomPositioning();
    var firstVisibleIndex = 0;
    var firstAlignment = 0.0;
    final firstVisible = _firstVisibleItemPosition();
    if (firstVisible != null) {
      firstVisibleIndex = firstVisible.index;
      firstAlignment = firstVisible.itemLeadingEdge.clamp(0.0, 1.0);
    }
    final previousCount = provider.messages.length;
    try {
      await provider.loadMoreMessages();
      final inserted = provider.messages.length - previousCount;
      if (inserted <= 0) {
        return;
      }
      await _jumpToOverallIndex(firstVisibleIndex + inserted, firstAlignment);
    } finally {
      _isLoadingOlderWithAnchor = false;
      _isRefreshingOlderMessages = false;
    }
  }

  bool _isOffline(ConnectionStatus status) {
    return status == ConnectionStatus.networkUnavailable ||
        status == ConnectionStatus.unconnected ||
        status == ConnectionStatus.suspend ||
        status == ConnectionStatus.timeout;
  }

  void _unbindEngineProvider() {
    final engineProvider = _engineProvider;
    if (engineProvider == null) {
      return;
    }
    engineProvider.receivedMessageNotifier.removeListener(_handleMessageEvent);
    engineProvider.typingStatusNotifier.removeListener(_handleTypingEvent);
    _engineProvider = null;
  }

  void _unbindChatProvider() {
    _chatProvider = null;
  }
}
