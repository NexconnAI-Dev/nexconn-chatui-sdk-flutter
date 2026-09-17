part of '../message_bubble.dart';

extension _MessageBubbleSendStatusIndicator on _MessageBubbleBase {
  /// Unified status slot rendered beside the bubble (aligned to its bottom,
  /// before the bubble in the text direction), shared by the sending spinner,
  /// the failed retry icon and the V5 read-receipt indicator.
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
    final Widget child;
    if (sentStatus == SentStatus.sending) {
      child = KeyedSubtree(
        key: MessageBubble.sendingStatusKey,
        child: const _RotatingStatusAsset(
          assetName: 'messageSending.png',
          size: kBubbleStatusSize,
        ),
      );
    } else if (isFailure) {
      child = GestureDetector(
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
    } else {
      final receiptIndicator = _readReceiptStatusIndicator(context);
      if (receiptIndicator == null) {
        return null;
      }
      child = receiptIndicator;
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: kBubbleStatusPadding),
      child: child,
    );
  }

  Widget? _readReceiptStatusIndicator(BuildContext context) {
    if (!config.messageListConfig.showReadReceiptIndicator) {
      return null;
    }
    final provider = _maybeChatProvider(context);
    if (provider?.canShowReadReceipt(message) != true) {
      return null;
    }
    final receiptData =
        provider!.readReceiptDataFor(message) ??
        const ChatReadReceiptDisplayData();
    final channelType =
        channel?.channelType ??
        _safeMessageChannelType(message) ??
        provider.channel.channelType;
    final canOpenReadReceiptUsers =
        channelType == ChannelType.group &&
        config.messageListConfig.showReadReceiptUserList &&
        receiptData.isAuthoritative;
    final customTap = config.messageListConfig.onReadReceiptStatusTap;
    final canUseCustomTap = customTap != null && receiptData.isAuthoritative;
    return ChatReadReceiptIndicator(
      displayData: receiptData,
      channelType: channelType,
      size: config.messageListConfig.readReceiptIndicatorSize,
      readColor: config.messageListConfig.readReceiptReadColor,
      unreadColor: config.messageListConfig.readReceiptUnreadColor,
      onTap: canUseCustomTap || canOpenReadReceiptUsers
          ? () => _handleReadReceiptStatusTap(context, provider, customTap)
          : null,
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
    await ReadReceiptUsersPage.push(
      context,
      provider: provider,
      message: message,
      config: config.messageListConfig,
      profileProvider: config.profileProvider,
      memberBuilder: config.readReceiptMemberBuilder,
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
