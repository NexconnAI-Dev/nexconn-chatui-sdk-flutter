part of '../message_bubble.dart';

extension _MessageBubbleStatus on _MessageBubbleBase {
  Widget _statusLine(BuildContext context, bool sent) {
    final sentStatus = _displaySentStatus(context);
    final shouldShowConfiguredStatus =
        sent &&
        config.messageListConfig.showSentStatus &&
        sentStatus != null &&
        sentStatus != SentStatus.sending &&
        sentStatus != SentStatus.failed &&
        sentStatus != SentStatus.canceled;
    if (!shouldShowConfiguredStatus) {
      return const SizedBox.shrink();
    }
    final textStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.grey[500], fontSize: 11);
    final statusText = Text(sentStatus.name, style: textStyle);
    final customTap = config.messageListConfig.onReadReceiptStatusTap;
    final provider = _maybeChatProvider(context);
    final canOpenReadReceiptUsers =
        config.messageListConfig.showReadReceiptUserList && provider != null;
    if (sentStatus != SentStatus.read ||
        (customTap == null && !canOpenReadReceiptUsers)) {
      return statusText;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleReadReceiptStatusTap(context, provider, customTap),
      child: statusText,
    );
  }
}
