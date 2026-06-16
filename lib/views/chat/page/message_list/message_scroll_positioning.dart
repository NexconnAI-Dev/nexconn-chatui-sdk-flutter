part of '../message_list_widget.dart';

extension _MessageScrollPositioning on _MessageListWidgetState {
  static const int _bottomAlignmentRetryLimit = 5;
  static const int _initialRevealFallbackFrameBudget = 8;

  Future<void> _scrollToBottom(ChatProvider provider) async {
    _scheduleStableScrollToBottom(provider);
  }

  Future<void> _keepBottomVisible(ChatProvider provider) async {
    _scheduleKeepBottomVisible(provider);
  }

  Future<void> _prepareForOutgoingAppend(ChatProvider provider) async {
    if (!mounted ||
        provider.messages.isEmpty ||
        _isLoadingOlderWithAnchor ||
        !_itemScrollController.isAttached ||
        !_shouldKeepBottomForInputTransition(provider) ||
        _contentFitsViewport(provider) == true) {
      return;
    }
    final generation = _outgoingAppendReserveGeneration + 1;
    _outgoingAppendReserveTimer?.cancel();
    _setMessageListState(() {
      _outgoingAppendReserveGeneration = generation;
      _activeOutgoingAppendReserveGeneration = generation;
    });
    _markPreserveBottomForInputTransition();
    _outgoingAppendReserveTimer = Timer(
      _outgoingAppendReserveTimeout,
      () => _releaseOutgoingAppendReserve(
        generation,
        provider: provider,
        keepBottom: true,
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!_isOutgoingAppendReserveActive(generation) ||
        !mounted ||
        _isLoadingOlderWithAnchor ||
        !_itemScrollController.isAttached) {
      return;
    }
    final reserveIndex = _outgoingAppendReserveOverallIndex(provider);
    if (reserveIndex == null) {
      return;
    }
    await _alignItemBottomUntilStable(reserveIndex);
  }

  void _scheduleListPositionAfterBuild(ChatProvider provider) {
    final messages = provider.messages;
    final count = messages.length;
    _pruneMessageItemKeys(messages);
    final previousCount = _lastMessageCount;
    if (count == 0) {
      _lastMessageCount = count;
      _lastLastMessageKey = null;
      _lastLastMessageScrollIdentity = null;
      if ((previousCount ?? 0) > 0) {
        _scheduleScrollRecovery(
          provider,
          keepBottom: _wasNearBottom || !_didInitialScrollToBottom,
        );
      }
      return;
    }
    final previousLastMessageKey = _lastLastMessageKey;
    final previousLastMessageScrollIdentity = _lastLastMessageScrollIdentity;
    final lastMessageKey = _messageKey(messages.last);
    final lastMessageScrollIdentity = _scrollTrackingIdentityOf(messages.last);
    _lastMessageCount = count;
    _lastLastMessageKey = lastMessageKey;
    _lastLastMessageScrollIdentity = lastMessageScrollIdentity;
    if (!_didInitialScrollToBottom) {
      _didInitialScrollToBottom = true;
      _isInitialScrollRevealPending = true;
      _scheduleInitialScrollToBottomAndReveal(
        provider,
        messageCount: count,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
      );
      return;
    }
    if (_isInitialScrollRevealPending) {
      _scheduleInitialScrollToBottomAndReveal(
        provider,
        messageCount: count,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
      );
      return;
    }
    if (_isLoadingOlderWithAnchor) {
      return;
    }
    if (previousCount != null && count < previousCount) {
      _scheduleScrollRecovery(provider, keepBottom: _wasNearBottom);
      return;
    }
    if (previousCount != null &&
        count == previousCount &&
        lastMessageKey != previousLastMessageKey &&
        lastMessageScrollIdentity != previousLastMessageScrollIdentity &&
        messages.last.direction == MessageDirection.send &&
        !isDeleteForAllPlaceholderMessage(messages.last)) {
      _scheduleStableScrollToBottom(provider);
      return;
    }
    final outgoingAppendReserveGeneration =
        _activeOutgoingAppendReserveGeneration;
    if (previousCount != null &&
        count > previousCount &&
        lastMessageKey != previousLastMessageKey &&
        outgoingAppendReserveGeneration != null &&
        messages.last.direction == MessageDirection.send &&
        !isDeleteForAllPlaceholderMessage(messages.last)) {
      _jumpToLatestMessageForOutgoingAppendFrame(provider);
      _scheduleOutgoingAppendAfterReserve(
        provider,
        outgoingAppendReserveGeneration,
      );
      return;
    }
    if (previousCount != null &&
        count > previousCount &&
        lastMessageKey != previousLastMessageKey &&
        _shouldAutoScrollToNewestMessage(messages.last)) {
      _scheduleStableScrollToBottom(provider);
    }
  }

  bool _shouldAutoScrollToNewestMessage(Message lastMessage) {
    return _wasNearBottom || lastMessage.direction == MessageDirection.send;
  }

  int _leadingItemCount({
    required bool showNetworkTip,
    required bool showTypingTip,
  }) {
    return (showNetworkTip ? 1 : 0) +
        (showTypingTip ? 1 : 0) +
        (widget.headerBuilder != null ? 1 : 0);
  }

  int _totalItemCount(
    ChatProvider provider, {
    required bool showNetworkTip,
    required bool showTypingTip,
  }) {
    return _leadingItemCount(
          showNetworkTip: showNetworkTip,
          showTypingTip: showTypingTip,
        ) +
        provider.messages.length +
        (_hasOutgoingAppendReserve ? 1 : 0) +
        (widget.footerBuilder != null ? 1 : 0);
  }

  int _messageOverallIndex(
    ChatProvider provider,
    int messageIndex, {
    bool? showNetworkTip,
    bool? showTypingTip,
  }) {
    return _leadingItemCount(
          showNetworkTip: showNetworkTip ?? _showNetworkTip(provider),
          showTypingTip: showTypingTip ?? _showTypingTip(provider),
        ) +
        messageIndex;
  }

  int _lastOverallItemIndex(ChatProvider provider) {
    final itemCount = _totalItemCount(
      provider,
      showNetworkTip: _showNetworkTip(provider),
      showTypingTip: _showTypingTip(provider),
    );
    return itemCount - 1;
  }

  int _latestMessageOverallIndex(ChatProvider provider) {
    if (provider.messages.isEmpty) {
      return -1;
    }
    return _messageOverallIndex(provider, provider.messages.length - 1);
  }

  int? _outgoingAppendReserveOverallIndex(ChatProvider provider) {
    if (!_hasOutgoingAppendReserve) {
      return null;
    }
    return _leadingItemCount(
          showNetworkTip: _showNetworkTip(provider),
          showTypingTip: _showTypingTip(provider),
        ) +
        provider.messages.length;
  }

  List<ItemPosition> _visibleItemPositions() {
    final positions = _itemPositionsListener.itemPositions.value.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return positions;
  }

  ItemPosition? _itemPositionForIndex(int index) {
    for (final position in _visibleItemPositions()) {
      if (position.index == index) {
        return position;
      }
    }
    return null;
  }

  ItemPosition? _firstVisibleItemPosition() {
    final positions = _visibleItemPositions();
    if (positions.isEmpty) {
      return null;
    }
    final visible = positions.where((p) => p.itemLeadingEdge >= 0).toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    return visible.isNotEmpty ? visible.first : positions.first;
  }

  bool _isNearBottom(ChatProvider provider) {
    if (!_itemScrollController.isAttached) {
      return true;
    }
    final lastIndex = _lastOverallItemIndex(provider);
    if (lastIndex < 0) {
      return true;
    }
    final position = _itemPositionForIndex(lastIndex);
    if (position == null) {
      if (_isInitialBottomPositioningPending()) {
        return true;
      }
      if (_visibleItemPositions().isEmpty) {
        return _wasNearBottom;
      }
      return false;
    }
    return position.itemTrailingEdge <= 1.08;
  }

  bool _shouldKeepBottomForInputTransition(ChatProvider provider) {
    if (_isInitialBottomPositioningPending()) {
      _preserveBottomForInputTransition = true;
      return true;
    }
    if (_isNearBottom(provider)) {
      _preserveBottomForInputTransition = true;
      return true;
    }
    return _preserveBottomForInputTransition;
  }

  void _markPreserveBottomForInputTransition() {
    _preserveBottomForInputTransition = true;
  }

  void _clearPreserveBottomForInputTransition() {
    _preserveBottomForInputTransition = false;
    final generation = _activeOutgoingAppendReserveGeneration;
    if (generation != null) {
      _releaseOutgoingAppendReserve(generation);
    }
  }

  void _setPreserveBottomForTargetIndex(ChatProvider provider, int index) {
    final lastIndex = _lastOverallItemIndex(provider);
    if (lastIndex < 0 || index >= lastIndex) {
      _markPreserveBottomForInputTransition();
      return;
    }
    _clearPreserveBottomForInputTransition();
  }

  bool _isInitialBottomPositioningPending() {
    return !_didInitialScrollToBottom || _isInitialScrollRevealPending;
  }

  double _getScrollOffset() {
    final firstVisible = _firstVisibleItemPosition();
    if (firstVisible == null) {
      return 0.0;
    }
    final alignment = firstVisible.itemLeadingEdge.clamp(0.0, 1.0);
    return firstVisible.index + alignment;
  }

  void _jumpToScrollOffset(double offset) {
    if (!_itemScrollController.isAttached) {
      return;
    }
    final index = offset.floor();
    final provider = _chatProvider;
    if (provider != null) {
      _setPreserveBottomForTargetIndex(provider, index);
    }
    var alignment = offset - index;
    if (alignment < 0) {
      alignment = 0;
    } else if (alignment > 1) {
      alignment = 1;
    }
    _itemScrollController.jumpTo(index: index, alignment: alignment);
  }

  Future<void> _jumpToOverallIndex(
    int index,
    double alignment, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    final provider = _chatProvider;
    if (provider != null) {
      _setPreserveBottomForTargetIndex(provider, index);
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || index < 0) {
      return;
    }
    if (!_itemScrollController.isAttached) {
      if (retriesLeft > 0) {
        await _jumpToOverallIndex(
          index,
          alignment,
          retriesLeft: retriesLeft - 1,
        );
      }
      return;
    }
    _itemScrollController.jumpTo(index: index, alignment: alignment);
  }

  void _handleVisibleItemsChanged() {
    final chatProvider = _chatProvider;
    if (chatProvider == null) {
      return;
    }
    final isNearBottom = _isNearBottom(chatProvider);
    _wasNearBottom = isNearBottom;
    if (isNearBottom) {
      _markPreserveBottomForInputTransition();
    }
  }

  void _cancelPendingBottomPositioning() {
    _pendingScrollToBottom = false;
    _pendingKeepBottomVisible = false;
    _pendingScrollRecovery = false;
    _pendingKeepBottomOnScrollRecovery = false;
  }

  void _scheduleStableScrollToBottom(ChatProvider provider) {
    _pendingScrollToBottom = true;
    _markPreserveBottomForInputTransition();
    if (_scrollToBottomCoalesced) {
      return;
    }
    _scrollToBottomCoalesced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scrollToBottomCoalesced = false;
      if (!_pendingScrollToBottom || !mounted || _isLoadingOlderWithAnchor) {
        return;
      }
      _pendingScrollToBottom = false;
      await _jumpToBottomWhenReady(provider);
    });
  }

  void _scheduleKeepBottomVisible(ChatProvider provider) {
    _pendingKeepBottomVisible = true;
    _markPreserveBottomForInputTransition();
    if (_keepBottomVisibleCoalesced) {
      return;
    }
    _keepBottomVisibleCoalesced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _keepBottomVisibleCoalesced = false;
      if (!_pendingKeepBottomVisible || !mounted || _isLoadingOlderWithAnchor) {
        return;
      }
      _pendingKeepBottomVisible = false;
      await _keepBottomVisibleWhenReady(provider);
    });
  }

  void _jumpToLatestMessageForOutgoingAppendFrame(ChatProvider provider) {
    if (!_itemScrollController.isAttached) {
      return;
    }
    final latestMessageIndex = _latestMessageOverallIndex(provider);
    if (latestMessageIndex < 0) {
      return;
    }
    _itemScrollController.jumpTo(index: latestMessageIndex, alignment: 0);
  }

  void _scheduleOutgoingAppendAfterReserve(
    ChatProvider provider,
    int reserveGeneration,
  ) {
    _markPreserveBottomForInputTransition();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isOutgoingAppendReserveActive(reserveGeneration) ||
          !mounted ||
          _isLoadingOlderWithAnchor) {
        return;
      }
      await _alignLatestMessageBottomWhenReady(provider);
      if (!_isOutgoingAppendReserveActive(reserveGeneration) || !mounted) {
        return;
      }
      _releaseOutgoingAppendReserve(
        reserveGeneration,
        provider: provider,
        keepBottom: true,
      );
    });
  }

  Future<bool> _alignLatestMessageBottomWhenReady(
    ChatProvider provider, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_itemScrollController.isAttached) {
      return false;
    }
    final latestMessageIndex = _latestMessageOverallIndex(provider);
    if (latestMessageIndex < 0) {
      return false;
    }
    if (_itemPositionForIndex(latestMessageIndex) == null) {
      _itemScrollController.jumpTo(index: latestMessageIndex, alignment: 0);
    }
    return _alignItemBottomUntilStable(
      latestMessageIndex,
      retriesLeft: retriesLeft,
    );
  }

  bool _isOutgoingAppendReserveActive(int generation) {
    return _activeOutgoingAppendReserveGeneration == generation;
  }

  void _releaseOutgoingAppendReserve(
    int generation, {
    ChatProvider? provider,
    bool keepBottom = false,
  }) {
    if (!_isOutgoingAppendReserveActive(generation)) {
      return;
    }
    _outgoingAppendReserveTimer?.cancel();
    _outgoingAppendReserveTimer = null;
    _setMessageListState(() {
      _activeOutgoingAppendReserveGeneration = null;
      _listChromeItemKeys.remove(_outgoingAppendReserveChromeId);
    });
    if (!keepBottom ||
        provider == null ||
        !mounted ||
        _isLoadingOlderWithAnchor ||
        !_shouldKeepBottomForInputTransition(provider)) {
      return;
    }
    _scheduleKeepBottomVisible(provider);
  }

  double _outgoingAppendReserveHeight() {
    final viewportHeight = _messageListViewportHeight;
    if (viewportHeight == null ||
        viewportHeight <= 0 ||
        !viewportHeight.isFinite) {
      return 120.0;
    }
    return (viewportHeight * 0.25).clamp(96.0, 160.0).toDouble();
  }

  void _scheduleInitialScrollToBottomAndReveal(
    ChatProvider provider, {
    required int messageCount,
    required String lastMessageScrollIdentity,
  }) {
    _markPreserveBottomForInputTransition();
    if (_initialScrollRevealScheduled &&
        _initialScrollRevealMessageCount == messageCount &&
        _initialScrollRevealMessageIdentity == lastMessageScrollIdentity) {
      return;
    }
    _initialScrollRevealScheduled = true;
    _initialScrollRevealMessageCount = messageCount;
    _initialScrollRevealMessageIdentity = lastMessageScrollIdentity;
    final revealGeneration = ++_initialScrollRevealGeneration;
    _scheduleInitialRevealFallback(
      provider,
      revealGeneration: revealGeneration,
      messageCount: messageCount,
      lastMessageScrollIdentity: lastMessageScrollIdentity,
      framesLeft: _initialRevealFallbackFrameBudget,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initialScrollRevealScheduled = false;
      if (!_isInitialRevealTargetCurrent(
        provider,
        revealGeneration: revealGeneration,
        messageCount: messageCount,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
      )) {
        return;
      }
      final didPosition = await _jumpToBottomWhenReady(provider);
      if (!_isInitialRevealTargetCurrent(
        provider,
        revealGeneration: revealGeneration,
        messageCount: messageCount,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
      )) {
        return;
      }
      if (didPosition) {
        _revealInitialScroll();
      }
      final isStable = await _waitForInitialBottomToRemainStable(
        provider,
        revealGeneration: revealGeneration,
        messageCount: messageCount,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
        requireRevealPending: !didPosition,
      );
      if (!_isInitialRevealTargetCurrent(
        provider,
        revealGeneration: revealGeneration,
        messageCount: messageCount,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
        requireRevealPending: !didPosition,
      )) {
        if (!_isInitialScrollRevealPending &&
            mounted &&
            !_isLoadingOlderWithAnchor &&
            _isInitialRevealTargetCurrent(
              provider,
              revealGeneration: revealGeneration,
              messageCount: messageCount,
              lastMessageScrollIdentity: lastMessageScrollIdentity,
              requireRevealPending: false,
            )) {
          _scheduleKeepBottomVisible(provider);
        }
        return;
      }
      if (!didPosition) {
        _revealInitialScroll();
      }
      if (!isStable && !_isLoadingOlderWithAnchor) {
        _scheduleKeepBottomVisible(provider);
      }
    });
  }

  void _scheduleInitialRevealFallback(
    ChatProvider provider, {
    required int revealGeneration,
    required int messageCount,
    required String lastMessageScrollIdentity,
    required int framesLeft,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialRevealTargetCurrent(
        provider,
        revealGeneration: revealGeneration,
        messageCount: messageCount,
        lastMessageScrollIdentity: lastMessageScrollIdentity,
      )) {
        return;
      }
      if (framesLeft > 0) {
        _scheduleInitialRevealFallback(
          provider,
          revealGeneration: revealGeneration,
          messageCount: messageCount,
          lastMessageScrollIdentity: lastMessageScrollIdentity,
          framesLeft: framesLeft - 1,
        );
        return;
      }
      _jumpNearBottomBeforeForcedReveal(provider);
      _revealInitialScroll();
      if (!_isLoadingOlderWithAnchor) {
        _scheduleKeepBottomVisible(provider);
      }
    });
  }

  void _jumpNearBottomBeforeForcedReveal(ChatProvider provider) {
    if (!_itemScrollController.isAttached) {
      return;
    }
    final itemIndex = _contentFitsViewport(provider) == true
        ? 0
        : _lastOverallItemIndex(provider);
    if (itemIndex < 0) {
      return;
    }
    _itemScrollController.jumpTo(index: itemIndex, alignment: 0);
  }

  void _scheduleScrollRecovery(
    ChatProvider provider, {
    required bool keepBottom,
  }) {
    _pendingScrollRecovery = true;
    _pendingKeepBottomOnScrollRecovery =
        _pendingKeepBottomOnScrollRecovery || keepBottom;
    if (_scrollRecoveryCoalesced) {
      return;
    }
    _scrollRecoveryCoalesced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scrollRecoveryCoalesced = false;
      if (!_pendingScrollRecovery || !mounted || _isLoadingOlderWithAnchor) {
        return;
      }
      final shouldKeepBottom = _pendingKeepBottomOnScrollRecovery;
      _pendingScrollRecovery = false;
      _pendingKeepBottomOnScrollRecovery = false;
      await _recoverScrollOffsetAfterContentShrink(
        provider,
        keepBottom: shouldKeepBottom,
      );
    });
  }

  void _revealInitialScroll() {
    if (!_isInitialScrollRevealPending) {
      return;
    }
    _markPreserveBottomForInputTransition();
    _setMessageListState(() {
      _isInitialScrollRevealPending = false;
      _initialScrollRevealMessageCount = null;
      _initialScrollRevealMessageIdentity = null;
    });
  }

  Future<bool> _jumpToBottomWhenReady(
    ChatProvider provider, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return false;
    }
    if (!_itemScrollController.isAttached) {
      if (retriesLeft > 0) {
        return _jumpToBottomWhenReady(provider, retriesLeft: retriesLeft - 1);
      }
      return false;
    }
    final lastIndex = _lastOverallItemIndex(provider);
    if (lastIndex < 0) {
      return false;
    }
    final contentFitsViewport = _contentFitsViewport(provider);
    if (contentFitsViewport == true) {
      return _jumpToTopWhenReady(provider, retriesLeft: retriesLeft);
    }
    final lastPosition = _itemPositionForIndex(lastIndex);
    if (lastPosition != null) {
      return _alignItemBottomUntilStable(lastIndex);
    }
    _itemScrollController.jumpTo(index: lastIndex, alignment: 0);
    return _alignItemBottomUntilStable(lastIndex, retriesLeft: retriesLeft);
  }

  Future<bool> _waitForInitialBottomToRemainStable(
    ChatProvider provider, {
    required int revealGeneration,
    required int messageCount,
    required String lastMessageScrollIdentity,
    bool requireRevealPending = true,
  }) async {
    const stableFrameTarget = 2;
    var stableFrames = 0;
    var retriesLeft = _bottomAlignmentRetryLimit + stableFrameTarget;
    while (retriesLeft >= 0 &&
        _isInitialRevealTargetCurrent(
          provider,
          revealGeneration: revealGeneration,
          messageCount: messageCount,
          lastMessageScrollIdentity: lastMessageScrollIdentity,
          requireRevealPending: requireRevealPending,
        )) {
      await WidgetsBinding.instance.endOfFrame;
      if (!_itemScrollController.isAttached) {
        retriesLeft -= 1;
        continue;
      }
      final lastIndex = _lastOverallItemIndex(provider);
      if (lastIndex < 0) {
        return false;
      }
      final contentFitsViewport = _contentFitsViewport(provider);
      if (contentFitsViewport == true) {
        if (_isFirstItemTopVisuallyStable()) {
          stableFrames += 1;
          if (stableFrames >= stableFrameTarget) {
            return true;
          }
          retriesLeft -= 1;
          continue;
        }
        final adjusted = _alignFirstItemTop();
        if (adjusted) {
          stableFrames = 0;
          retriesLeft -= 1;
          continue;
        }
        retriesLeft -= 1;
        continue;
      }
      final position = _itemPositionForIndex(lastIndex);
      if (_isLatestMessageBottomVisuallyStable(provider)) {
        stableFrames += 1;
        if (stableFrames >= stableFrameTarget) {
          return true;
        }
        retriesLeft -= 1;
        continue;
      }
      if (position == null) {
        retriesLeft -= 1;
        continue;
      }
      final adjusted = _alignVisibleItemBottom(lastIndex, position);
      if (adjusted) {
        stableFrames = 0;
        retriesLeft -= 1;
        continue;
      }
      stableFrames += 1;
      if (stableFrames >= stableFrameTarget) {
        return true;
      }
      retriesLeft -= 1;
    }
    return false;
  }

  bool _isLatestMessageBottomVisuallyStable(ChatProvider provider) {
    if (provider.messages.isEmpty) {
      return true;
    }
    final latestMessageKey = _messageKey(provider.messages.last);
    final latestMessageBox = _renderBoxForKey(
      _messageItemKeys[latestMessageKey],
    );
    final viewportBox = _renderBoxForKey(_messageListViewportMeasureKey);
    if (latestMessageBox == null || viewportBox == null) {
      return false;
    }
    final latestBottom = latestMessageBox
        .localToGlobal(Offset(0, latestMessageBox.size.height))
        .dy;
    final viewportBottom = viewportBox
        .localToGlobal(Offset(0, viewportBox.size.height))
        .dy;
    return (latestBottom - viewportBottom).abs() <= 1.0;
  }

  bool _isFirstItemTopVisuallyStable() {
    final firstPosition = _itemPositionForIndex(0);
    if (firstPosition == null) {
      return false;
    }
    return firstPosition.itemLeadingEdge.abs() <= 0.01;
  }

  RenderBox? _renderBoxForKey(GlobalKey? key) {
    final renderObject = key?.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject;
  }

  bool _isInitialRevealTargetCurrent(
    ChatProvider provider, {
    required int revealGeneration,
    required int messageCount,
    required String lastMessageScrollIdentity,
    bool requireRevealPending = true,
  }) {
    if (!mounted ||
        _initialScrollRevealGeneration != revealGeneration ||
        !identical(_chatProvider, provider) ||
        provider.messages.length != messageCount ||
        provider.messages.isEmpty) {
      return false;
    }
    if (requireRevealPending && !_isInitialScrollRevealPending) {
      return false;
    }
    return _scrollTrackingIdentityOf(provider.messages.last) ==
        lastMessageScrollIdentity;
  }

  Future<void> _keepBottomVisibleWhenReady(
    ChatProvider provider, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    if (!mounted) {
      return;
    }
    if (!_itemScrollController.isAttached) {
      if (retriesLeft > 0) {
        await _retryKeepBottomVisible(provider, retriesLeft - 1);
      }
      return;
    }
    final lastIndex = _lastOverallItemIndex(provider);
    if (lastIndex < 0) {
      return;
    }
    final contentFitsViewport = _contentFitsViewport(provider);
    if (contentFitsViewport == true) {
      await _jumpToTopWhenReady(provider, retriesLeft: retriesLeft);
      return;
    }
    final lastPosition = _itemPositionForIndex(lastIndex);
    if (lastPosition == null) {
      if (_isInitialBottomPositioningPending() || _wasNearBottom) {
        await _jumpToBottomWhenReady(provider, retriesLeft: retriesLeft);
        return;
      }
      if (_visibleItemPositions().isEmpty && retriesLeft > 0) {
        await _retryKeepBottomVisible(provider, retriesLeft - 1);
      }
      return;
    }
    await _alignItemBottomUntilStable(lastIndex, retriesLeft: retriesLeft);
  }

  Future<bool> _jumpToTopWhenReady(
    ChatProvider provider, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return false;
    }
    if (!_itemScrollController.isAttached) {
      if (retriesLeft > 0) {
        return _jumpToTopWhenReady(provider, retriesLeft: retriesLeft - 1);
      }
      return false;
    }
    if (_lastOverallItemIndex(provider) < 0) {
      return false;
    }
    return _alignItemTopUntilStable(0, retriesLeft: retriesLeft);
  }

  Future<void> _retryKeepBottomVisible(
    ChatProvider provider,
    int retriesLeft,
  ) async {
    await WidgetsBinding.instance.endOfFrame;
    await _keepBottomVisibleWhenReady(provider, retriesLeft: retriesLeft);
  }

  void _handleBlankListPointerUp(Offset globalPosition) {
    if (_isPointInsideTrackedListItem(globalPosition)) {
      return;
    }
    try {
      final inputProvider = Provider.of<MessageInputProvider?>(
        context,
        listen: false,
      );
      if (inputProvider?.mode == MessageInputMode.voice) {
        return;
      }
      inputProvider?.setMode(MessageInputMode.initial);
    } on ProviderNotFoundException {
      // Message lists can be embedded without a message input area.
    }
  }

  bool _isPointInsideTrackedListItem(Offset globalPosition) {
    for (final key in [
      ..._messageItemKeys.values,
      ..._listChromeItemKeys.values,
    ]) {
      final box = _renderBoxForKey(key);
      if (box == null) {
        continue;
      }
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      if (rect.contains(globalPosition)) {
        return true;
      }
    }
    return false;
  }

  bool _alignVisibleItemBottom(int itemIndex, ItemPosition position) {
    const alignmentTolerance = 0.01;
    if ((position.itemTrailingEdge - 1.0).abs() <= alignmentTolerance) {
      return false;
    }
    _applyItemAlignment(itemIndex, position);
    return true;
  }

  bool _alignFirstItemTop() {
    final position = _itemPositionForIndex(0);
    if (position == null) {
      return false;
    }
    return _alignVisibleItemTop(0, position);
  }

  bool _alignVisibleItemTop(int itemIndex, ItemPosition position) {
    const alignmentTolerance = 0.01;
    if (position.itemLeadingEdge.abs() <= alignmentTolerance) {
      return false;
    }
    _itemScrollController.jumpTo(index: itemIndex, alignment: 0);
    return true;
  }

  Future<bool> _alignItemTopUntilStable(
    int itemIndex, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    var remainingRetries = retriesLeft;
    while (mounted && _itemScrollController.isAttached) {
      final position = _itemPositionForIndex(itemIndex);
      if (position == null) {
        _itemScrollController.jumpTo(index: itemIndex, alignment: 0);
        if (remainingRetries <= 0) {
          return false;
        }
        remainingRetries -= 1;
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final adjusted = _alignVisibleItemTop(itemIndex, position);
      if (!adjusted) {
        return true;
      }
      if (remainingRetries <= 0) {
        return true;
      }
      remainingRetries -= 1;
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  Future<bool> _alignItemBottomUntilStable(
    int itemIndex, {
    int retriesLeft = _bottomAlignmentRetryLimit,
  }) async {
    var remainingRetries = retriesLeft;
    while (mounted && _itemScrollController.isAttached) {
      final position = _itemPositionForIndex(itemIndex);
      if (position == null) {
        if (remainingRetries <= 0) {
          return false;
        }
        remainingRetries -= 1;
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final adjusted = _alignVisibleItemBottom(itemIndex, position);
      if (!adjusted) {
        return true;
      }
      if (remainingRetries <= 0) {
        return true;
      }
      remainingRetries -= 1;
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  void _updateContentMeasurementContext(
    ChatProvider provider, {
    required double viewportHeight,
    required bool showNetworkTip,
    required bool showTypingTip,
  }) {
    if (viewportHeight <= 0 || !viewportHeight.isFinite) {
      return;
    }
    if (!identical(_chatProvider, provider)) {
      return;
    }
    _messageListViewportHeight = viewportHeight;
    _contentMeasureShowNetworkTip = showNetworkTip;
    _contentMeasureShowTypingTip = showTypingTip;
  }

  bool? _contentFitsViewport(ChatProvider provider) {
    final viewportHeight = _messageListViewportHeight;
    if (viewportHeight == null ||
        viewportHeight <= 0 ||
        !viewportHeight.isFinite) {
      return null;
    }
    final lastIndex = _lastOverallItemIndex(provider);
    if (lastIndex < 0) {
      return true;
    }
    final visiblePositions = _visibleItemPositions();
    if (visiblePositions.isEmpty) {
      return null;
    }
    if (_itemPositionForIndex(0) == null ||
        _itemPositionForIndex(lastIndex) == null) {
      return false;
    }
    final contentHeight = _measuredRealListContentHeight(provider);
    if (contentHeight == null) {
      return null;
    }
    return contentHeight <= viewportHeight + 0.5;
  }

  double? _measuredRealListContentHeight(ChatProvider provider) {
    final itemKeys = <GlobalKey?>[
      if (_contentMeasureShowNetworkTip) _listChromeItemKeys['network'],
      if (_contentMeasureShowTypingTip) _listChromeItemKeys['typing'],
      if (widget.headerBuilder != null) _listChromeItemKeys['header'],
      for (final message in provider.messages)
        _messageItemKeys[_messageKey(message)],
      if (_hasOutgoingAppendReserve)
        _listChromeItemKeys[_outgoingAppendReserveChromeId],
      if (widget.footerBuilder != null) _listChromeItemKeys['footer'],
    ];
    if (itemKeys.isEmpty) {
      return 0;
    }
    var contentHeight = 0.0;
    for (final key in itemKeys) {
      if (key == null) {
        return null;
      }
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return null;
      }
      contentHeight += renderObject.size.height;
    }
    return contentHeight;
  }

  void _applyItemAlignment(int itemIndex, ItemPosition position) {
    final itemHeightFraction =
        (position.itemTrailingEdge - position.itemLeadingEdge).abs();
    final desiredAlignment = (1.0 - itemHeightFraction).clamp(0.0, 1.0);
    _itemScrollController.jumpTo(index: itemIndex, alignment: desiredAlignment);
  }

  Future<void> _recoverScrollOffsetAfterContentShrink(
    ChatProvider provider, {
    required bool keepBottom,
  }) async {
    if (!keepBottom) {
      return;
    }
    await _jumpToBottomWhenReady(provider);
  }

  void _pruneMessageItemKeys(List<Message> messages) {
    if (_messageItemKeys.isEmpty) {
      _messageVisibleFractions.clear();
      return;
    }
    final liveKeys = messages.map(_messageKey).toSet();
    _messageItemKeys.removeWhere((key, _) => !liveKeys.contains(key));
    _messageVisibleFractions.removeWhere((key, _) => !liveKeys.contains(key));
  }

  bool _isLatestMessageFullyVisible(ChatProvider provider) {
    if (provider.messages.isEmpty) {
      return true;
    }
    final lastMessageKey = _messageKey(provider.messages.last);
    final visibleFraction = _messageVisibleFractions[lastMessageKey];
    if (visibleFraction == null) {
      return _isNearBottom(provider);
    }
    return visibleFraction >= 0.98;
  }

  bool _isSameChannelIdentifier(ChannelIdentifier a, ChannelIdentifier b) {
    return a.channelType == b.channelType &&
        a.channelId == b.channelId &&
        _normalizedSubChannelId(a.subChannelId) ==
            _normalizedSubChannelId(b.subChannelId);
  }

  String? _normalizedSubChannelId(String? subChannelId) {
    return subChannelId == null || subChannelId.isEmpty ? null : subChannelId;
  }

  String _scrollTrackingIdentityOf(Message message) {
    final clientId = _messageClientIdOf(message);
    if (clientId != null) {
      return 'client:$clientId';
    }
    final messageId = _messageMessageIdOf(message);
    if (messageId != null && messageId.isNotEmpty) {
      return 'uid:$messageId';
    }
    final channelType = _messageChannelTypeOf(message);
    final channelId = _messageChannelIdOf(message);
    final sentTime = _messageSentTimeOf(message);
    final senderUserId = _messageSenderUserIdOf(message);
    final messageType = _messageMessageTypeOf(message);
    if (channelType != null &&
        channelId != null &&
        channelId.isNotEmpty &&
        sentTime != null &&
        senderUserId != null &&
        senderUserId.isNotEmpty &&
        messageType != null) {
      return 'fallback:${channelType.name}:$channelId:'
          '${_normalizedSubChannelId(_messageSubChannelIdOf(message))}:'
          '$sentTime:$senderUserId:${messageType.name}';
    }
    return _messageKey(message);
  }

  int? _messageClientIdOf(Message message) {
    try {
      return message.clientId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _messageMessageIdOf(Message message) {
    try {
      return message.messageId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _messageChannelIdOf(Message message) {
    try {
      return message.channelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  ChannelType? _messageChannelTypeOf(Message message) {
    try {
      return message.channelType;
    } on NoSuchMethodError {
      return null;
    }
  }

  MessageType? _messageMessageTypeOf(Message message) {
    try {
      return message.messageType;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _messageSubChannelIdOf(Message message) {
    try {
      return message.subChannelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _messageSentTimeOf(Message message) {
    try {
      return message.sentTime;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _messageSenderUserIdOf(Message message) {
    try {
      return message.senderUserId;
    } on NoSuchMethodError {
      return null;
    }
  }
}
