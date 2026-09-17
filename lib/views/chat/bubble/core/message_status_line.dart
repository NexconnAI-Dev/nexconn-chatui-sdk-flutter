part of '../message_bubble.dart';

extension _MessageBubbleStatus on _MessageBubbleBase {
  bool _isSuccessfullyEditedMessage(Message target) {
    try {
      return target.hasChanged == true;
    } on NoSuchMethodError {
      return false;
    }
  }

  TextStyle _editedMarkerStyle(Message target) {
    final sent = target.direction == MessageDirection.send;
    return TextStyle(
      color: sent ? const Color(0xFFE4E4E4) : const Color(0xFF7C838E),
      fontSize: 12,
    );
  }

  Widget? _messageEditStatusAppend(BuildContext context) {
    if (message is! TextMessage && message is! ReferenceMessage) return null;
    MessageModifyStatus? status;
    try {
      status = message.modifyInfo?.status;
    } on NoSuchMethodError {
      return null;
    }
    final textStyle = Theme.of(context).textTheme.labelSmall;
    if (status == MessageModifyStatus.updating) {
      return Semantics(
        label: context.chatUIL10n.messageEditUpdating,
        child: Row(
          key: MessageBubble.editUpdatingStatusKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
            const SizedBox(width: 4),
            Text(
              context.chatUIL10n.messageEditUpdating,
              style: textStyle?.copyWith(color: const Color(0xFF007AFF)),
            ),
          ],
        ),
      );
    }
    if (status != MessageModifyStatus.failed) return null;
    final provider = _maybeChatProvider(context);
    return Semantics(
      button: provider != null,
      label: context.chatUIL10n.messageEditRetry,
      child: InkWell(
        key: MessageBubble.editFailedStatusKey,
        borderRadius: BorderRadius.circular(4),
        onTap: provider == null
            ? null
            : () => unawaited(provider.retryEditedMessage(message)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 14,
                color: Color(0xFFFF5A50),
              ),
              const SizedBox(width: 4),
              Text(
                context.chatUIL10n.messageEditRetry,
                style: textStyle?.copyWith(color: const Color(0xFFFF5A50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
