part of '../message_bubble.dart';

extension _MessageBubbleSendStatusIndicator on _MessageBubbleBase {
  Widget? _sendStatusIndicator(BuildContext context, bool sent) {
    if (withoutStatusLine) {
      return null;
    }
    if (!sent || _isRecallMessage) {
      return null;
    }
    final sentStatus = _displaySentStatus(context);
    final isFailure =
        sentStatus == SentStatus.failed || sentStatus == SentStatus.canceled;
    if (sentStatus != SentStatus.sending && !isFailure) {
      return null;
    }
    final child = sentStatus == SentStatus.sending
        ? KeyedSubtree(
            key: MessageBubble.sendingStatusKey,
            child: const _RotatingStatusAsset(
              assetName: 'messageSending.png',
              size: kBubbleStatusSize,
            ),
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleResend(context),
            child: KeyedSubtree(
              key: MessageBubble.failedStatusKey,
              child: ChatUIAsset.image(
                'messageSendFail.png',
                width: kBubbleStatusSize,
                height: kBubbleStatusSize,
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.only(
        right: kBubbleStatusPadding,
        top: kBubbleStatusPadding,
      ),
      child: child,
    );
  }

  SentStatus? _readSentStatus() {
    try {
      return message.sentStatus;
    } on NoSuchMethodError {
      return null;
    }
  }

  SentStatus? _displaySentStatus(BuildContext context) {
    final provider = _maybeChatProvider(context, listen: true);
    return provider?.sentStatusForDisplay(message) ?? _readSentStatus();
  }

  Future<void> _handleReadReceiptStatusTap(
    BuildContext context,
    ChatProvider? provider,
    ChatReadReceiptStatusTap? customTap,
  ) async {
    if (customTap != null) {
      customTap(context, message);
      return;
    }
    if (provider == null) {
      return;
    }
    if (provider.multiSelectMode) {
      onTap?.call();
      return;
    }
    await ReadReceiptUsersSheet.show(
      context,
      provider: provider,
      message: message,
      config: config.messageListConfig,
    );
  }

  Future<void> _handleResend(BuildContext context) async {
    final provider = _maybeChatProvider(context);
    if (provider?.multiSelectMode == true) {
      onTap?.call();
      return;
    }
    final customResend = config.messageListConfig.onResendMessage;
    if (customResend != null) {
      await customResend(context, channel, message);
      return;
    }
    if (provider == null) {
      return;
    }
    await provider.retryFailedMessage(message);
  }
}

class _RotatingStatusAsset extends StatefulWidget {
  const _RotatingStatusAsset({required this.assetName, required this.size});

  final String assetName;
  final double size;

  @override
  State<_RotatingStatusAsset> createState() => _RotatingStatusAssetState();
}

class _RotatingStatusAssetState extends State<_RotatingStatusAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ChatUIAsset.image(
        widget.assetName,
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
