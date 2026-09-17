part of '../chat_provider.dart';

/// Message operation surface used by ChatProvider.
abstract class ChatMessageOperations {
  Future<List<Message>> searchMessages(ChatMessageSearchRequest request);

  Future<List<Message>> searchMessagesByUser(ChatMessageSearchRequest request);

  Future<List<Message>> searchMessagesByTimeRange(
    ChatMessageSearchRequest request,
  );

  Future<List<Message>> getMessagesAroundTime(ChatMessageSearchRequest request);

  Future<ChatDeleteMessageForAllResult> deleteMessageForAll(
    BaseChannel channel,
    Message message,
  );

  Future<NCError?> cancelSendingMediaMessage(
    BaseChannel channel,
    MediaMessage message,
  );

  Future<NCError?> deleteMessageForMe(BaseChannel channel, Message message);

  Future<NCError?> deleteLocalMessages(List<int> messageClientIds);

  Future<NCError?> deleteMessagesForMeByTimestamp(
    BaseChannel channel, {
    required int timestamp,
    MessageOperationPolicy policy = MessageOperationPolicy.localRemote,
  });

  Future<NCError?> saveDraft(BaseChannel channel, String draft);

  Future<NCError?> clearDraft(BaseChannel channel);

  Future<List<Message>> getUnreadMentionedMessages(BaseChannel channel);

  Future<ChatReadReceiptUsersData> loadReadReceiptUsers(
    BaseChannel channel,
    Message message,
  );
}

/// Optional lookup capability for [ChatMessageOperations] implementations.
///
/// Keeping message lookup separate preserves source compatibility for custom
/// operation implementations created before message editing was introduced.
abstract class ChatMessageLookupOperations {
  /// Resolves one message by its server-side unique ID.
  ///
  /// A `null` result means the SDK completed successfully but did not find the
  /// message. Implementations should throw [NCError] when the lookup itself
  /// fails so callers can distinguish a temporary failure from a stale draft.
  Future<Message?> getMessageById(String messageId);
}

/// Optional paging capability for [ChatMessageOperations] implementations.
///
/// Keeping this separate preserves source compatibility for existing custom
/// operation implementations while allowing the built-in detail sheet to load
/// large member lists incrementally.
abstract class ChatReadReceiptUsersPageOperations {
  ChatReadReceiptUsersPageSource createReadReceiptUsersPageSource(
    BaseChannel channel,
    Message message,
    MessageReadReceiptStatus status, {
    required int pageSize,
  });
}

class _NexconnChatMessageOperations
    implements
        ChatMessageOperations,
        ChatMessageLookupOperations,
        ChatReadReceiptUsersPageOperations {
  const _NexconnChatMessageOperations();

  @override
  Future<Message?> getMessageById(String messageId) async {
    final completer = Completer<Message?>();
    unawaited(() async {
      try {
        final code = await BaseChannel.getMessageById(
          GetMessageByIdParams(messageId: messageId),
          (message, error) {
            if (error != null && error.code != 0) {
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
              return;
            }
            if (!completer.isCompleted) {
              completer.complete(message);
            }
          },
        );
        if (code != 0 && !completer.isCompleted) {
          completer.completeError(NCError(code: code));
        }
      } catch (error) {
        if (!completer.isCompleted) completer.completeError(error);
      }
    }());
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw NCError(
        code: -1,
        message: 'Timed out while resolving message by ID',
      ),
    );
  }

  Future<List<Message>> _loadMessagesFromQuery(
    Future<int> Function(OperationHandler<PageData<Message>>) loader,
  ) async {
    final completer = Completer<List<Message>>();
    final code = await loader((page, error) {
      if (error != null && error.code != 0) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(page?.data ?? const []);
      }
    });
    if (code != 0 && !completer.isCompleted) {
      throw NCError(code: code);
    }
    return completer.future;
  }

  Future<List<Message>> _loadMessagesFromList(
    Future<int> Function(OperationHandler<List<Message>>) loader,
  ) async {
    final completer = Completer<List<Message>>();
    final code = await loader((messages, error) {
      if (error != null && error.code != 0) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(messages ?? const []);
      }
    });
    if (code != 0 && !completer.isCompleted) {
      throw NCError(code: code);
    }
    return completer.future;
  }

  @override
  Future<List<Message>> searchMessages(ChatMessageSearchRequest request) {
    return _loadMessagesFromQuery(
      BaseChannel.createSearchMessagesQuery(
        SearchMessagesQueryParams(
          channelIdentifier: request.channel.channelIdentifier,
          keyword: request.keyword ?? '',
          startTime: request.startTime,
          pageSize: request.pageSize,
        ),
      ).loadNextPage,
    );
  }

  @override
  Future<List<Message>> searchMessagesByUser(ChatMessageSearchRequest request) {
    return _loadMessagesFromQuery(
      BaseChannel.createSearchMessagesByUserQuery(
        SearchMessagesByUserQueryParams(
          channelIdentifier: request.channel.channelIdentifier,
          userId: request.userId ?? '',
          startTime: request.startTime,
          pageSize: request.pageSize,
        ),
      ).loadNextPage,
    );
  }

  @override
  Future<List<Message>> searchMessagesByTimeRange(
    ChatMessageSearchRequest request,
  ) {
    return _loadMessagesFromQuery(
      BaseChannel.createSearchMessagesByTimeRangeQuery(
        SearchMessagesByTimeRangeQueryParams(
          channelIdentifier: request.channel.channelIdentifier,
          keyword: request.keyword ?? '',
          startTime: request.startTime,
          endTime: request.endTime,
          pageSize: request.pageSize,
        ),
      ).loadNextPage,
    );
  }

  @override
  Future<List<Message>> getMessagesAroundTime(
    ChatMessageSearchRequest request,
  ) {
    return _loadMessagesFromList(
      (handler) => request.channel.getMessagesAroundTime(
        GetMessagesAroundTimeParams(
          sentTime: request.sentTime,
          beforeCount: request.beforeCount,
          afterCount: request.afterCount,
        ),
        handler,
      ),
    );
  }

  @override
  Future<ChatDeleteMessageForAllResult> deleteMessageForAll(
    BaseChannel channel,
    Message message,
  ) async {
    if (channel is CommunityChannel) {
      final completer = Completer<NCError?>();
      final code = await channel.deleteMessageForAll(
        DeleteCommunityMessageParams(message: message, deleteRemote: true),
        (value) {
          if (!completer.isCompleted) {
            completer.complete(value);
          }
        },
      );
      if (code != 0 && !completer.isCompleted) {
        completer.complete(NCError(code: code));
      }
      return ChatDeleteMessageForAllResult(error: await completer.future);
    }
    final completer = Completer<ChatDeleteMessageForAllResult>();
    final code = await BaseChannel.deleteMessageForAll(message, (
      value,
      opError,
    ) {
      if (!completer.isCompleted) {
        completer.complete(
          ChatDeleteMessageForAllResult(message: value, error: opError),
        );
      }
    });
    if (code != 0 && !completer.isCompleted) {
      completer.complete(
        ChatDeleteMessageForAllResult(error: NCError(code: code)),
      );
    }
    return completer.future;
  }

  @override
  Future<NCError?> cancelSendingMediaMessage(
    BaseChannel channel,
    MediaMessage message,
  ) async {
    final completer = Completer<NCError?>();
    final code = await channel.cancelSendingMessage(message, (error) {
      if (!completer.isCompleted) {
        completer.complete(error);
      }
    });
    if (code != 0 && !completer.isCompleted) {
      completer.complete(NCError(code: code));
    }
    return completer.future;
  }

  @override
  Future<NCError?> deleteMessageForMe(
    BaseChannel channel,
    Message message,
  ) async {
    NCError? error;
    await channel.deleteMessagesForMe([message], (value) => error = value);
    return error;
  }

  @override
  Future<NCError?> deleteLocalMessages(List<int> messageClientIds) async {
    final completer = Completer<NCError?>();
    final code = await BaseChannel.deleteLocalMessages(messageClientIds, (
      error,
    ) {
      if (!completer.isCompleted) {
        completer.complete(error);
      }
    });
    if (code != 0 && !completer.isCompleted) {
      completer.complete(NCError(code: code));
    }
    return completer.future;
  }

  @override
  Future<NCError?> deleteMessagesForMeByTimestamp(
    BaseChannel channel, {
    required int timestamp,
    MessageOperationPolicy policy = MessageOperationPolicy.localRemote,
  }) async {
    NCError? error;
    await channel.deleteMessagesForMeByTimestamp(
      DeleteMessagesForMeByTimestampParams(
        timestamp: timestamp,
        policy: policy,
      ),
      (value) => error = value,
    );
    return error;
  }

  @override
  Future<NCError?> saveDraft(BaseChannel channel, String draft) async {
    NCError? error;
    await channel.saveDraft(draft, (value) => error = value);
    return error;
  }

  @override
  Future<NCError?> clearDraft(BaseChannel channel) async {
    NCError? error;
    await channel.clearDraft((value) => error = value);
    return error;
  }

  @override
  Future<List<Message>> getUnreadMentionedMessages(BaseChannel channel) {
    final completer = Completer<List<Message>>();
    channel.getUnreadMentionedMessages((messages, error) {
      if (error != null && error.code != 0) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(messages ?? const []);
      }
    });
    return completer.future;
  }

  @override
  Future<ChatReadReceiptUsersData> loadReadReceiptUsers(
    BaseChannel channel,
    Message message,
  ) async {
    final messageId = message.messageId;
    if (messageId == null || messageId.isEmpty) {
      throw NCError(
        code: 25101,
        message: 'Message ID is missing; read receipt users cannot be loaded',
      );
    }
    final info = await _loadReadReceiptInfo(channel, messageId);
    final readUsers = await _loadAllReadReceiptUsers(
      channel,
      messageId,
      MessageReadReceiptStatus.read,
    );
    final unreadUsers = await _loadAllReadReceiptUsers(
      channel,
      messageId,
      MessageReadReceiptStatus.unread,
    );
    final resolvedReadCount = info?.readCount ?? readUsers.length;
    final resolvedUnreadCount = info?.unreadCount ?? unreadUsers.length;
    final resolvedTotalCount =
        info?.totalCount ?? resolvedReadCount + resolvedUnreadCount;
    return ChatReadReceiptUsersData(
      readUsers: readUsers
          .map(
            (user) => ChatReadReceiptUserEntry(
              userId: user.userId ?? '',
              title: user.userId?.isNotEmpty == true
                  ? user.userId!
                  : 'Unknown user',
              timestamp: user.timestamp,
              isRead: true,
              payload: user,
            ),
          )
          .toList(growable: false),
      unreadUsers: unreadUsers
          .map(
            (user) => ChatReadReceiptUserEntry(
              userId: user.userId ?? '',
              title: user.userId?.isNotEmpty == true
                  ? user.userId!
                  : 'Unknown user',
              timestamp: user.timestamp,
              isRead: false,
              payload: user,
            ),
          )
          .toList(growable: false),
      readCount: resolvedReadCount,
      unreadCount: resolvedUnreadCount,
      totalCount: resolvedTotalCount,
      rawInfo: info,
      rawReadUsers: readUsers,
      rawUnreadUsers: unreadUsers,
    );
  }

  @override
  ChatReadReceiptUsersPageSource createReadReceiptUsersPageSource(
    BaseChannel channel,
    Message message,
    MessageReadReceiptStatus status, {
    required int pageSize,
  }) {
    final messageId = message.messageId;
    if (messageId == null || messageId.isEmpty) {
      throw NCError(
        code: 25101,
        message: 'Message ID is missing; read receipt users cannot be loaded',
      );
    }
    return _NexconnReadReceiptUsersPageSource(
      BaseChannel.createMessagesReadReceiptUsersQuery(
        MessagesReadReceiptUsersQueryParams(
          channelIdentifier: channel.channelIdentifier,
          messageId: messageId,
          pageSize: pageSize.clamp(1, 100),
          isAscending: false,
          status: status,
        ),
      ),
      isRead: status == MessageReadReceiptStatus.read,
    );
  }

  Future<ReadReceiptInfo?> _loadReadReceiptInfo(
    BaseChannel channel,
    String messageId,
  ) async {
    final completer = Completer<ReadReceiptInfo?>();
    void complete(List<ReadReceiptInfo>? infos, NCError? error) {
      if (completer.isCompleted) return;
      if (error != null && error.code != 0) {
        completer.completeError(error);
        return;
      }
      ReadReceiptInfo? matchedInfo;
      final candidates = infos ?? const <ReadReceiptInfo>[];
      for (final info in candidates) {
        if (info.messageId == messageId) {
          matchedInfo = info;
          break;
        }
      }
      matchedInfo ??= candidates.isNotEmpty ? candidates.first : null;
      completer.complete(matchedInfo);
    }

    // The native operation ID and callback are independent delivery paths.
    // Keep the UI responsive if either path is lost by a bridge/native fault.
    unawaited(() async {
      try {
        final code = await channel.getMessageReadReceiptInfo([
          messageId,
        ], complete);
        if (code != 0) complete(null, NCError(code: code));
      } catch (error) {
        complete(null, error is NCError ? error : NCError(message: '$error'));
      }
    }());
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw NCError(
        code: -1,
        message: 'Timed out while loading message read receipt info',
      ),
    );
  }

  Future<List<MessageReadReceiptUser>> _loadAllReadReceiptUsers(
    BaseChannel channel,
    String messageId,
    MessageReadReceiptStatus status,
  ) async {
    final query = BaseChannel.createMessagesReadReceiptUsersQuery(
      MessagesReadReceiptUsersQueryParams(
        channelIdentifier: channel.channelIdentifier,
        messageId: messageId,
        pageSize: 50,
        status: status,
      ),
    );
    final users = <MessageReadReceiptUser>[];
    while (true) {
      final page = await _loadReadReceiptUsersPage(query);
      users.addAll(page.data);
      if (!query.hasMore || page.data.isEmpty) {
        break;
      }
    }
    return users;
  }

  Future<PageResult<MessageReadReceiptUser>> _loadReadReceiptUsersPage(
    MessagesReadReceiptUsersQuery query,
  ) async {
    final completer = Completer<PageResult<MessageReadReceiptUser>>();
    void complete(PageResult<MessageReadReceiptUser>? page, NCError? error) {
      if (completer.isCompleted) return;
      if (error != null && error.code != 0) {
        completer.completeError(error);
        return;
      }
      completer.complete(
        page ??
            const PageResult<MessageReadReceiptUser>(
              data: <MessageReadReceiptUser>[],
              totalCount: 0,
            ),
      );
    }

    unawaited(() async {
      try {
        final code = await query.loadNextPage(complete);
        if (code != 0) complete(null, NCError(code: code));
      } catch (error) {
        complete(null, error is NCError ? error : NCError(message: '$error'));
      }
    }());
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw NCError(
        code: -1,
        message: 'Timed out while loading read receipt users',
      ),
    );
  }
}

class _NexconnReadReceiptUsersPageSource
    implements ChatReadReceiptUsersPageSource {
  final MessagesReadReceiptUsersQuery _query;
  final bool isRead;

  _NexconnReadReceiptUsersPageSource(this._query, {required this.isRead});

  @override
  bool get hasMore => _query.hasMore;

  @override
  Future<ChatReadReceiptUsersPage> loadNextPage() async {
    final completer = Completer<PageResult<MessageReadReceiptUser>>();
    void complete(PageResult<MessageReadReceiptUser>? page, NCError? error) {
      if (completer.isCompleted) return;
      if (error != null && error.code != 0) {
        completer.completeError(error);
        return;
      }
      completer.complete(
        page ??
            const PageResult<MessageReadReceiptUser>(
              data: <MessageReadReceiptUser>[],
              totalCount: 0,
            ),
      );
    }

    unawaited(() async {
      try {
        final code = await _query.loadNextPage(complete);
        if (code != 0) complete(null, NCError(code: code));
      } catch (error) {
        complete(null, error is NCError ? error : NCError(message: '$error'));
      }
    }());
    final page = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw NCError(
        code: -1,
        message: 'Timed out while loading read receipt users',
      ),
    );
    final users = page.data
        .map(
          (user) => ChatReadReceiptUserEntry(
            userId: user.userId ?? '',
            title: user.userId?.isNotEmpty == true
                ? user.userId!
                : 'Unknown user',
            timestamp: user.timestamp,
            isRead: isRead,
            payload: user,
          ),
        )
        .toList(growable: false);
    return ChatReadReceiptUsersPage(
      users: users,
      totalCount: page.totalCount,
      hasMore: users.isNotEmpty && _query.hasMore,
    );
  }
}
