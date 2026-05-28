part of '../chat_provider.dart';

/// Search mode used when querying messages in a channel.
enum ChatMessageSearchMode { keyword, user, timeRange, aroundTime }

/// Parameters for message search in ChatProvider.
class ChatMessageSearchRequest {
  final BaseChannel channel;
  final ChatMessageSearchMode mode;
  final String? keyword;
  final String? userId;
  final int startTime;
  final int endTime;
  final int sentTime;
  final int beforeCount;
  final int afterCount;
  final int pageSize;

  const ChatMessageSearchRequest({
    required this.channel,
    required this.mode,
    this.keyword,
    this.userId,
    this.startTime = 0,
    this.endTime = 0,
    this.sentTime = 0,
    this.beforeCount = 10,
    this.afterCount = 10,
    this.pageSize = 20,
  });

  Map<String, dynamic> toJson() => {
    'channel': channel.toJson(),
    'mode': mode.name,
    'keyword': keyword,
    'userId': userId,
    'startTime': startTime,
    'endTime': endTime,
    'sentTime': sentTime,
    'beforeCount': beforeCount,
    'afterCount': afterCount,
    'pageSize': pageSize,
  };

  String get summary {
    switch (mode) {
      case ChatMessageSearchMode.keyword:
        return 'Keyword: ${keyword ?? ''}';
      case ChatMessageSearchMode.user:
        return 'User: ${userId ?? ''}';
      case ChatMessageSearchMode.timeRange:
        return 'Time range: $startTime ~ $endTime';
      case ChatMessageSearchMode.aroundTime:
        return 'Around $sentTime, $beforeCount before / $afterCount after';
    }
  }
}
