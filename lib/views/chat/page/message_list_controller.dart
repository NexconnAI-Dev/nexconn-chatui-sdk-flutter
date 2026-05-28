class MessageListController {
  Future<void> Function()? _prepareForOutgoingAppend;
  Future<void> Function()? _scrollToBottom;
  Future<void> Function()? _keepBottomVisible;
  Future<void> Function(int index, double alignment)? _jumpToIndex;
  bool Function()? _isAttached;
  bool Function()? _isNearBottom;
  bool Function()? _shouldKeepBottomForInputTransition;
  double Function()? _getScrollOffset;
  void Function(double offset)? _jumpToScrollOffset;

  void bind({
    required Future<void> Function() scrollToBottom,
    required Future<void> Function(int index, double alignment) jumpToIndex,
    required bool Function() isAttached,
    required bool Function() isNearBottom,
    required double Function() getScrollOffset,
    required void Function(double offset) jumpToScrollOffset,
    Future<void> Function()? prepareForOutgoingAppend,
    Future<void> Function()? keepBottomVisible,
    bool Function()? shouldKeepBottomForInputTransition,
  }) {
    _prepareForOutgoingAppend = prepareForOutgoingAppend;
    _scrollToBottom = scrollToBottom;
    _keepBottomVisible = keepBottomVisible;
    _jumpToIndex = jumpToIndex;
    _isAttached = isAttached;
    _isNearBottom = isNearBottom;
    _shouldKeepBottomForInputTransition = shouldKeepBottomForInputTransition;
    _getScrollOffset = getScrollOffset;
    _jumpToScrollOffset = jumpToScrollOffset;
  }

  void clear() {
    _prepareForOutgoingAppend = null;
    _scrollToBottom = null;
    _keepBottomVisible = null;
    _jumpToIndex = null;
    _isAttached = null;
    _isNearBottom = null;
    _shouldKeepBottomForInputTransition = null;
    _getScrollOffset = null;
    _jumpToScrollOffset = null;
  }

  Future<void> prepareForOutgoingAppend() async {
    await _prepareForOutgoingAppend?.call();
  }

  Future<void> scrollToBottom() async {
    await _scrollToBottom?.call();
  }

  Future<void> keepBottomVisible() async {
    await _keepBottomVisible?.call();
  }

  Future<void> jumpToIndex(int index, {double alignment = 0}) async {
    await _jumpToIndex?.call(index, alignment);
  }

  bool get isAttached => _isAttached?.call() ?? false;

  bool isNearBottom() => _isNearBottom?.call() ?? false;

  bool shouldKeepBottomForInputTransition() =>
      _shouldKeepBottomForInputTransition?.call() ?? isNearBottom();

  double getScrollOffset() => _getScrollOffset?.call() ?? 0.0;

  void jumpToScrollOffset(double offset) {
    _jumpToScrollOffset?.call(offset);
  }
}
