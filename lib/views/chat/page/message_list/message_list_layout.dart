part of '../message_list_widget.dart';

extension _MessageListMessageListLayout on _MessageListWidgetState {
  Widget _buildMessageList(BuildContext context) {
    return Selector<ChatProvider, _MessageListRenderState>(
      selector: (_, provider) => _MessageListRenderState.fromProvider(provider),
      builder: (context, _, _) {
        final provider = context.read<ChatProvider>();
        final l10n = context.chatUIL10n;
        if (!provider.hasResolvedInitialLoad && provider.messages.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _loadOlderMessagesPreservingAnchor(provider),
            child: _loadingPlaceholder(context, provider),
          );
        }
        if (provider.messages.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _loadOlderMessagesPreservingAnchor(provider),
            child: _empty(context, provider),
          );
        }
        final showNetworkTip = _showNetworkTip(provider);
        final showTypingTip = _showTypingTip(provider);
        _scheduleListPositionAfterBuild(provider);
        final itemCount = _totalItemCount(
          provider,
          showNetworkTip: showNetworkTip,
          showTypingTip: showTypingTip,
        );
        final scrollView = NotificationListener<ScrollStartNotification>(
          onNotification: (notification) {
            if (notification.dragDetails != null) {
              _clearPreserveBottomForInputTransition();
            }
            return false;
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: (event) => _handleBlankListPointerUp(event.position),
            child: RefreshIndicator(
              triggerMode: RefreshIndicatorTriggerMode.anywhere,
              notificationPredicate: _shouldHandlePullRefreshNotification,
              onRefresh: () => _loadOlderMessagesPreservingAnchor(provider),
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _updateContentMeasurementContext(
                      provider,
                      viewportHeight: constraints.maxHeight,
                      showNetworkTip: showNetworkTip,
                      showTypingTip: showTypingTip,
                    );
                    return SizedBox.expand(
                      key: const ValueKey('message-list-scrollable-viewport'),
                      child: KeyedSubtree(
                        key: _messageListViewportMeasureKey,
                        child: ScrollablePositionedList.builder(
                          itemCount: itemCount,
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                          minCacheExtent: 200,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          initialScrollIndex: 0,
                          itemBuilder: (context, index) => _messageListItem(
                            context,
                            provider,
                            index,
                            showNetworkTip: showNetworkTip,
                            showTypingTip: showTypingTip,
                            l10n: l10n,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        final listBody = _isInitialScrollRevealPending
            ? IgnorePointer(child: Opacity(opacity: 0, child: scrollView))
            : scrollView;
        return NotificationListener<ReferenceMessageTapNotification>(
          onNotification: (notification) {
            _handleReferenceMessageTap(provider, notification.targetMessage);
            return true;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              listBody,
              if (provider.unreadMentionedMessages.isNotEmpty)
                Positioned(
                  top: 20,
                  right: 20,
                  child: _UnreadMentionedTip(
                    count: provider.unreadMentionedMessages.length,
                    onTap: () => _handleUnreadMentionedTipTap(provider),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
