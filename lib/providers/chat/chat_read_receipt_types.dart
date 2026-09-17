part of '../chat_provider.dart';

/// V5 read-receipt behavior for ChatUI.
class ChatReadReceiptV5Options {
  final bool enabled;
  final Set<ChannelType> enabledChannelTypes;
  final bool defaultNeedReceipt;

  const ChatReadReceiptV5Options({
    this.enabled = true,
    this.enabledChannelTypes = const {ChannelType.direct, ChannelType.group},
    this.defaultNeedReceipt = true,
  });
}

/// Identity of one V5 receipt record.
///
/// Message UIDs are normally globally unique, but the native callbacks also
/// carry channel context and some test/native implementations can reuse a UID
/// while rebuilding a local message. Keeping the full channel identity avoids
/// applying a response from another sub-channel to the current bubble.
@immutable
class _ChatReadReceiptMessageKey {
  final ChannelType channelType;
  final String channelId;
  final String? subChannelId;
  final String messageId;

  const _ChatReadReceiptMessageKey({
    required this.channelType,
    required this.channelId,
    required this.subChannelId,
    required this.messageId,
  });

  static _ChatReadReceiptMessageKey? fromMessage(Message message) {
    try {
      final type = message.channelType;
      final id = message.channelId;
      final uid = message.messageId;
      if (type == null ||
          id == null ||
          id.isEmpty ||
          uid == null ||
          uid.isEmpty) {
        return null;
      }
      String? subChannelId;
      try {
        subChannelId = normalize(message.subChannelId);
      } on NoSuchMethodError {
        // Older wrappers and lightweight test doubles have no sub-channel
        // getter; the base channel identity remains valid in that case.
        subChannelId = null;
      }
      return _ChatReadReceiptMessageKey(
        channelType: type,
        channelId: id,
        subChannelId: subChannelId,
        messageId: uid,
      );
    } on NoSuchMethodError {
      return null;
    }
  }

  static String? normalize(String? value) =>
      value == null || value.isEmpty ? null : value;

  @override
  bool operator ==(Object other) {
    return other is _ChatReadReceiptMessageKey &&
        other.channelType == channelType &&
        other.channelId == channelId &&
        other.subChannelId == subChannelId &&
        other.messageId == messageId;
  }

  @override
  int get hashCode =>
      Object.hash(channelType, channelId, subChannelId, messageId);
}

/// User row displayed in a read-receipt user list.
class ChatReadReceiptUserEntry {
  final String userId;
  final String title;
  final String? subtitle;
  final int? timestamp;
  final bool isRead;
  final Object? payload;

  const ChatReadReceiptUserEntry({
    required this.userId,
    required this.title,
    required this.isRead,
    this.subtitle,
    this.timestamp,
    this.payload,
  });
}

/// Read and unread user groups for one message read receipt.
class ChatReadReceiptUsersData {
  final List<ChatReadReceiptUserEntry> readUsers;
  final List<ChatReadReceiptUserEntry> unreadUsers;
  final int readCount;
  final int unreadCount;
  final int totalCount;
  final Object? rawInfo;
  final Object? rawReadUsers;
  final Object? rawUnreadUsers;

  const ChatReadReceiptUsersData({
    this.readUsers = const [],
    this.unreadUsers = const [],
    this.readCount = 0,
    this.unreadCount = 0,
    this.totalCount = 0,
    this.rawInfo,
    this.rawReadUsers,
    this.rawUnreadUsers,
  });
}

/// One page of read or unread members for a message receipt.
class ChatReadReceiptUsersPage {
  final List<ChatReadReceiptUserEntry> users;
  final int totalCount;
  final bool hasMore;

  const ChatReadReceiptUsersPage({
    this.users = const <ChatReadReceiptUserEntry>[],
    this.totalCount = 0,
    this.hasMore = false,
  });
}

/// Stateful source for loading one read-receipt member page at a time.
abstract class ChatReadReceiptUsersPageSource {
  bool get hasMore;

  Future<ChatReadReceiptUsersPage> loadNextPage();
}

class _ChatReadReceiptSubmission {
  final _ChatReadReceiptMessageKey key;
  final Message message;
  final Completer<void> completer = Completer<void>();
  bool canceled = false;

  _ChatReadReceiptSubmission({required this.key, required this.message});

  void complete() {
    if (!completer.isCompleted) completer.complete();
  }
}

class _ChatReadReceiptSubmitQueue {
  final LinkedHashMap<_ChatReadReceiptMessageKey, _ChatReadReceiptSubmission>
  pending =
      LinkedHashMap<_ChatReadReceiptMessageKey, _ChatReadReceiptSubmission>();
  List<_ChatReadReceiptSubmission> currentBatch =
      <_ChatReadReceiptSubmission>[];
  Timer? batchTimer;
  Timer? retryTimer;
  Timer? deadlineTimer;
  bool requestActive = false;
  int retryAttempt = 0;
  int requestToken = 0;

  _ChatReadReceiptSubmission? submissionFor(_ChatReadReceiptMessageKey key) {
    final queued = pending[key];
    if (queued != null) return queued;
    for (final submission in currentBatch) {
      if (submission.key == key && !submission.canceled) return submission;
    }
    return null;
  }

  void completeAndClear() {
    requestToken++;
    requestActive = false;
    batchTimer?.cancel();
    retryTimer?.cancel();
    deadlineTimer?.cancel();
    batchTimer = null;
    retryTimer = null;
    deadlineTimer = null;
    for (final submission in <_ChatReadReceiptSubmission>{
      ...pending.values,
      ...currentBatch,
    }) {
      submission.complete();
    }
    pending.clear();
    currentBatch = <_ChatReadReceiptSubmission>[];
    retryAttempt = 0;
  }
}
