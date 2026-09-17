part of '../chat_provider.dart';

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
