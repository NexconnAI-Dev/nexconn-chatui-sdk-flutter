part of '../chat_provider.dart';

/// Handles a text-based message action.
typedef ChatMessageActionCallback = Future<void> Function(String value);

/// Reports that a requested message action is not supported.
typedef ChatMessageUnsupportedCallback =
    void Function(String action, String reason);

/// Runs before ChatProvider sends a message.
typedef ChatBeforeSendMessageInterceptor =
    FutureOr<bool> Function(BaseChannel channel, MessageParams params);

/// Runs after ChatProvider receives the send result.
typedef ChatAfterSendMessageInterceptor =
    FutureOr<void> Function(
      BaseChannel channel,
      MessageParams params,
      Message? message,
      NCError? error,
    );

/// Loads read and unread users for a message read receipt.
typedef ChatReadReceiptUsersLoader =
    Future<ChatReadReceiptUsersData> Function(
      BaseChannel channel,
      Message message,
    );

/// Result returned after forwarding messages.
class ChatForwardResult {
  final int forwardedCount;
  final int skippedCount;

  const ChatForwardResult({this.forwardedCount = 0, this.skippedCount = 0});

  bool get hasForwarded => forwardedCount > 0;
}

/// Raised when forwarding requires a remote media download that cannot finish.
class ChatForwardMediaDownloadException implements Exception {
  const ChatForwardMediaDownloadException();
}

class _CombinedForwardItem {
  final CombineMessageInfo info;
  final String senderName;
  final String summary;

  const _CombinedForwardItem({
    required this.info,
    required this.senderName,
    required this.summary,
  });
}

/// Result returned after deleting a message for all users.
class ChatDeleteMessageForAllResult {
  final Message? message;
  final NCError? error;

  const ChatDeleteMessageForAllResult({this.message, this.error});
}

/// Forwarding mode for selected messages.
enum ChatForwardMode { individually, combined }

bool _isReferenceForwardMessage(Message message) {
  if (message is ReferenceMessage) {
    return true;
  }
  try {
    return message.messageType == MessageType.reference;
  } on NoSuchMethodError {
    return false;
  }
}

/// Optional callbacks for message actions that host apps can override.
class ChatMessageActionCallbacks {
  final ChatMessageActionCallback? onCopyText;
  final ChatMessageActionCallback? onDialPhone;
  final ChatMessageUnsupportedCallback? onUnsupportedAction;
  final ChatBeforeSendMessageInterceptor? onBeforeSendMessage;
  final ChatAfterSendMessageInterceptor? onAfterSendMessage;

  const ChatMessageActionCallbacks({
    this.onCopyText,
    this.onDialPhone,
    this.onUnsupportedAction,
    this.onBeforeSendMessage,
    this.onAfterSendMessage,
  });
}
