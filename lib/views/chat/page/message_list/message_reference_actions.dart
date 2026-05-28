part of '../message_list_widget.dart';

extension _MessageListReferenceActions on _MessageListWidgetState {
  Future<void> _referenceMessage(
    BuildContext context,
    ChatProvider provider,
    Message message,
  ) async {
    final handler = widget.config.longPressMenuConfig.onReference;
    if (handler != null) {
      await handler(context, provider.channel, message);
      return;
    }
    provider.setReferenceMessage(message);
  }

  RelativeRect _menuPosition(
    BuildContext context,
    Offset globalPosition, {
    double? menuWidth,
    double? menuHeight,
  }) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = overlay.size;
    final safeTop = mediaQuery.padding.top;
    final safeBottom = mediaQuery.padding.bottom;
    final resolvedMenuWidth = menuWidth ?? 160;
    final resolvedMenuHeight = menuHeight ?? 220;
    final headerMinTop = safeTop + appbarHeight + 50;
    final inputFieldTop =
        _messageListBottomInOverlay(overlay) ??
        _estimatedInputTop(context, screenSize.height, safeBottom);

    var left = globalPosition.dx;
    var top = globalPosition.dy;
    final maxLeft = screenSize.width - resolvedMenuWidth - 8;
    if (left > maxLeft) {
      left = maxLeft;
    }
    if (left < 8) {
      left = 8;
    }

    const menuEdgeSpacing = 12.0;
    final bottomAvoidTop = inputFieldTop - resolvedMenuHeight - menuEdgeSpacing;
    if (globalPosition.dy + resolvedMenuHeight + menuEdgeSpacing >
        inputFieldTop) {
      top = bottomAvoidTop;
    }
    if (globalPosition.dy <= headerMinTop) {
      top = headerMinTop;
    }

    final maxTop = screenSize.height - resolvedMenuHeight - safeBottom - 8;
    if (top > maxTop) {
      top = maxTop;
    }
    if (top < headerMinTop) {
      top = headerMinTop;
    }

    final right = screenSize.width - left - resolvedMenuWidth;
    final bottom = screenSize.height - top - resolvedMenuHeight;
    return RelativeRect.fromLTRB(left, top, right, bottom);
  }

  double? _messageListBottomInOverlay(RenderBox overlay) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    final bottom = renderObject.localToGlobal(
      Offset(0, renderObject.size.height),
      ancestor: overlay,
    );
    return bottom.dy;
  }

  double _estimatedInputTop(
    BuildContext context,
    double screenHeight,
    double safeBottom,
  ) {
    final inputProvider = _maybeReadMessageInputProvider(context);
    final inputConfig = widget.config.inputConfig;
    final bottomPanelHeight = switch (inputProvider?.mode) {
      MessageInputMode.emoji => inputConfig.emojiPanelConfig.height,
      MessageInputMode.extension => inputConfig.extensionPanelConfig.height,
      MessageInputMode.initial ||
      MessageInputMode.text ||
      MessageInputMode.voice ||
      null => 0.0,
    };
    final composerHeight =
        (inputProvider?.referenceMessage == null
            ? 0.0
            : kInputQuotePreviewHeight) +
        kInputFieldMinHeight;
    return screenHeight - bottomPanelHeight - composerHeight - safeBottom;
  }

  MessageInputProvider? _maybeReadMessageInputProvider(BuildContext context) {
    try {
      return Provider.of<MessageInputProvider?>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _showSelectionLimitTip(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.chatUIL10n.chatSelectionLimit(
            widget.config.messageListConfig.maxSelectedMessages,
          ),
        ),
      ),
    );
  }
}
