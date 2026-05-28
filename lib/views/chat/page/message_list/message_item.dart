part of '../message_list_widget.dart';

extension _MessageListMessageItem on _MessageListWidgetState {
  Widget _messageListItem(
    BuildContext context,
    ChatProvider provider,
    int index, {
    required bool showNetworkTip,
    required bool showTypingTip,
    required NexconnChatUILocalizations l10n,
  }) {
    var cursor = index;
    if (showNetworkTip) {
      if (cursor == 0) {
        return _trackedListChromeItem(
          'network',
          _NetworkTip(
            text:
                widget.config.messageListConfig.networkStatusText ??
                l10n.chatNetworkUnavailable,
          ),
        );
      }
      cursor -= 1;
    }
    if (showTypingTip) {
      if (cursor == 0) {
        return _trackedListChromeItem(
          'typing',
          _StatusTip(
            text: _typingStatusText(context, widget.config.messageListConfig),
            onTap: () => _scrollToBottom(provider),
          ),
        );
      }
      cursor -= 1;
    }
    if (widget.headerBuilder != null) {
      if (cursor == 0) {
        return _trackedListChromeItem('header', widget.headerBuilder!(context));
      }
      cursor -= 1;
    }
    if (cursor < provider.messages.length) {
      return _messageItemContent(context, provider, cursor);
    }
    cursor -= provider.messages.length;
    if (_hasOutgoingAppendReserve) {
      if (cursor == 0) {
        return _trackedListChromeItem(
          _outgoingAppendReserveChromeId,
          SizedBox(height: _outgoingAppendReserveHeight()),
        );
      }
      cursor -= 1;
    }
    if (widget.footerBuilder != null && cursor == 0) {
      return _trackedListChromeItem('footer', widget.footerBuilder!(context));
    }
    return const SizedBox.shrink();
  }

  Widget _messageItemContent(
    BuildContext context,
    ChatProvider provider,
    int messageIndex,
  ) {
    final message = provider.messages[messageIndex];
    final previousMessage = messageIndex > 0
        ? provider.messages[messageIndex - 1]
        : null;
    final messageKey = _messageKey(message);
    final itemKey = _messageItemKeys.putIfAbsent(messageKey, GlobalKey.new);
    final isLastMessage = messageIndex == provider.messages.length - 1;
    final isUnreadMentioned = provider.unreadMentionedMessages.any(
      (item) => _isSameMessage(item, message),
    );
    final shouldTrackVisibility = isLastMessage || isUnreadMentioned;
    final child =
        widget.messageBuilder?.call(context, message, widget.config) ??
        MessageBubble(
          channel: widget.channel,
          message: message,
          config: widget.config,
          showTime: TimeUtil.shouldShowMessageTime(
            message.sentTime,
            previousMessage?.sentTime,
          ),
          customMessageBubbleBuilders: widget.customMessageBubbleBuilders,
          selected: provider.isMessageSelected(message),
          multiSelectMode: provider.multiSelectMode,
          onTap: () => _handleMessageTap(context, provider, message),
          onDoubleTap: widget.onMessageDoubleTap == null
              ? null
              : () => widget.onMessageDoubleTap!(message),
          onLongPressStart: (details) => _handleMessageLongPress(
            context,
            provider,
            message,
            details.globalPosition,
          ),
          onSwipe: widget.onMessageSwipe == null
              ? null
              : (direction) =>
                    widget.onMessageSwipe!(context, message, direction),
          onAvatarTap: () => widget.onMessageAvatarTap?.call(message),
          onAvatarLongPress: () =>
              widget.onMessageAvatarLongPress?.call(message),
        );
    final keyedChild = KeyedSubtree(key: itemKey, child: child);
    if (!shouldTrackVisibility) {
      _messageVisibleFractions.remove(messageKey);
      return keyedChild;
    }
    return VisibilityDetector(
      key: Key('message_visibility_$messageKey'),
      onVisibilityChanged: (info) {
        _messageVisibleFractions[messageKey] = info.visibleFraction;
        if (info.visibleFraction >= 0.5) {
          provider.removeUnreadMentionedMessage(message);
        }
      },
      child: keyedChild,
    );
  }

  Widget _trackedListChromeItem(String id, Widget child) {
    final itemKey = _listChromeItemKeys.putIfAbsent(id, GlobalKey.new);
    return KeyedSubtree(key: itemKey, child: child);
  }

  Widget _empty(BuildContext context, ChatProvider provider) {
    final emptyChild = _isSystemChannel
        ? const SizedBox.shrink()
        : widget.emptyBuilder?.call(context) ??
              Center(
                child: Text(
                  widget.config.messageListConfig.emptyText ??
                      context.chatUIL10n.chatMessageListEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
    return ListView(
      controller: provider.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_showNetworkTip(provider))
          _NetworkTip(
            text:
                widget.config.messageListConfig.networkStatusText ??
                context.chatUIL10n.chatNetworkUnavailable,
          ),
        if (widget.headerBuilder != null) widget.headerBuilder!(context),
        SizedBox(height: MediaQuery.of(context).size.height * 0.24),
        emptyChild,
        if (widget.footerBuilder != null) widget.footerBuilder!(context),
      ],
    );
  }

  Widget _loadingPlaceholder(BuildContext context, ChatProvider provider) {
    final topOffset = MediaQuery.of(context).size.height * 0.24;
    return ListView(
      controller: provider.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_showNetworkTip(provider))
          _NetworkTip(
            text:
                widget.config.messageListConfig.networkStatusText ??
                context.chatUIL10n.chatNetworkUnavailable,
          ),
        if (widget.headerBuilder != null) widget.headerBuilder!(context),
        SizedBox(height: topOffset),
        const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
        if (widget.footerBuilder != null) widget.footerBuilder!(context),
      ],
    );
  }
}
