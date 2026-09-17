part of '../chat_provider.dart';

extension _ChatProviderMessageEvents on ChatProvider {
  /// Invalidates a pending edit when a terminal message event wins locally.
  /// This prevents a late modify callback from resurrecting a recalled or
  /// deleted message.
  void _invalidateMessageModification(Message message) {
    final id = message.messageId;
    if (id == null || id.isEmpty) return;
    _messageModificationEventRevisions[id] =
        (_messageModificationEventRevisions[id] ?? 0) + 1;
    _terminalMessageEditIds.add(id);
    final operationId = _messageEditOperationIds.remove(id);
    final cancellationSignal = operationId == null
        ? null
        : _messageEditCancellationSignals.remove(operationId);
    if (cancellationSignal != null && !cancellationSignal.isCompleted) {
      cancellationSignal.complete();
    }
    _latestModifiedMessages.remove(id);
  }

  void _onChannelMessageUpserted() {
    final message = engineProvider.channelMessageUpsertedNotifier.value;
    if (message == null || !_sameChannel(message)) {
      return;
    }
    if (_consumeSuppressedChannelUpsert(message)) {
      return;
    }
    if (_isRecallMessage(message)) {
      _handleRecallMessageEvent(message);
      return;
    }
    _upsertMessageFromEngine(message);
    // Sent messages arrive through the channel-upsert callback rather than
    // the received-message callback. Query their V5 state here as well so a
    // newly sent message gets an indicator without waiting for a reload.
    unawaited(_syncReadReceipts([message]));
    unawaited(_refreshReferenceMessages([message]));
  }

  void _onMessageReceived() {
    final message = engineProvider.receivedMessageNotifier.value;
    if (message == null || !_sameChannel(message)) {
      return;
    }
    if (_isRecallMessage(message)) {
      _handleRecallMessageEvent(message);
      _scheduleClearUnreadCount();
      return;
    }
    _upsertMessage(message);
    unawaited(_syncReadReceipts([message]));
    unawaited(_refreshReferenceMessages([message]));
    _scheduleClearUnreadCount();
  }

  void _onReadReceiptDataChanged() => _safeNotifyListeners();

  void _onMessagesModified() {
    final modified = engineProvider.modifiedMessagesNotifier.value;
    if (modified == null || modified.isEmpty) return;
    final sameChannel = modified.where(_sameChannel).toList();
    if (sameChannel.isEmpty) return;
    final acceptedById = <String, Message>{};
    for (final item in sameChannel) {
      final id = item.messageId;
      if (id == null || id.isEmpty) continue;
      if (_terminalMessageEditIds.contains(id)) continue;
      if (!_hasMessageModificationPayload(item)) continue;
      final current = _latestModifiedMessages[id] ?? _messageById(id);
      if (!_shouldAcceptModifiedMessage(
        item,
        current,
        acceptEqualStatus: true,
      )) {
        continue;
      }
      _latestModifiedMessages[id] = item;
      _messageModificationEventRevisions[id] =
          (_messageModificationEventRevisions[id] ?? 0) + 1;
      acceptedById[id] = item;
    }
    if (acceptedById.isEmpty) return;
    final successfulModifications = acceptedById.entries
        .where((entry) => _isSuccessfulModification(entry.value))
        .toList(growable: false);
    if (successfulModifications.isNotEmpty) {
      _ensureReferenceMessageIndex();
    }
    var referenceIndexChanged = false;
    var changed = false;
    for (final entry in acceptedById.entries) {
      final index = _messageIndexForId(entry.key);
      if (index == null) continue;
      referenceIndexChanged =
          referenceIndexChanged ||
          _messages[index] is ReferenceMessage ||
          entry.value is ReferenceMessage;
      final previous = _messages[index];
      _preserveReferenceStateForReplacement(previous, entry.value);
      _messages[index] = entry.value;
      _updateCachedMessageAt(index, entry.value, previous: previous);
      changed = true;
    }
    for (final entry in successfulModifications) {
      final replacement = entry.value;
      if (!_isSuccessfulModification(replacement)) continue;
      for (final item in _referenceMessagesByTargetId[entry.key] ?? const {}) {
        if (_isReferenceTerminal(_referenceStatusOf(item))) continue;
        item.referenceMsg = replacement;
        final currentStatus = _referenceStatusOf(item);
        final mergedStatus = _maxReferenceStatus(
          currentStatus,
          ReferenceMessageStatus.modified,
        );
        if (mergedStatus != currentStatus) {
          _setReferenceStatus(item, mergedStatus);
        }
        changed = true;
      }
    }
    if (changed) {
      // Replacements keep their position and identity, so the cached message
      // index and visible list stay valid. Only reference targets can alter
      // the reverse index below.
      if (referenceIndexChanged) {
        _markReferenceMessageIndexDirty();
      }
      _markMessageRenderChanged();
      _safeNotifyListeners();
    }
  }

  void _onModifiedMessageSyncCompleted() {
    if (_disposed) return;
    unawaited(_syncReadReceipts(_messages));
    _restartReferenceRefreshes();
    if (_hasResolvedInitialLoad) {
      unawaited(loadInitialMessages());
    }
  }

  /// Merges modification events that arrived before a paged query completed.
  ///
  /// The local query can legitimately return an older message snapshot than
  /// the event stream. Keep the event snapshot in that case so a later page
  /// load cannot roll an edited message back to its original content.
  List<Message> _mergeLatestModifiedMessages(Iterable<Message> messages) {
    final result = <Message>[];
    for (final message in messages) {
      final id = message.messageId;
      if (id == null || id.isEmpty) {
        result.add(message);
        continue;
      }
      if (_terminalMessageEditIds.contains(id)) continue;
      final cached = _latestModifiedMessages[id];
      if (cached == null) {
        if (_modificationStatusOf(message) != null ||
            _modificationTimestamp(message) != null) {
          _latestModifiedMessages[id] = message;
          _messageModificationEventRevisions[id] =
              (_messageModificationEventRevisions[id] ?? 0) + 1;
        }
        result.add(message);
        continue;
      }
      if (_shouldAcceptModifiedMessage(message, cached)) {
        _latestModifiedMessages[id] = message;
        _messageModificationEventRevisions[id] =
            (_messageModificationEventRevisions[id] ?? 0) + 1;
        result.add(message);
      } else {
        result.add(cached);
      }
    }
    return result;
  }

  MessageModifyStatus? _modificationStatusOf(Message message) {
    try {
      return message.modifyInfo?.status;
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _modificationTimestamp(Message message) {
    try {
      return message.modifyInfo?.timestamp;
    } on NoSuchMethodError {
      return null;
    }
  }

  bool _isSuccessfulModification(Message message) {
    try {
      return message.hasChanged == true &&
          _modificationStatusOf(message) == MessageModifyStatus.success;
    } on NoSuchMethodError {
      return false;
    }
  }

  bool _matchesSuccessfulModification(Message candidate, Message expected) {
    if (!_isSuccessfulModification(candidate)) return false;
    final textMatches = switch ((candidate, expected)) {
      (TextMessage actual, TextMessage wanted) => actual.text == wanted.text,
      (ReferenceMessage actual, ReferenceMessage wanted) =>
        actual.text == wanted.text &&
            actual.referenceMsg?.messageId == wanted.referenceMsg?.messageId,
      _ => false,
    };
    if (!textMatches) return false;
    final actualMention = _mentionedInfoFromMessage(candidate);
    final expectedMention = _mentionedInfoFromMessage(expected);
    if (actualMention?.type != expectedMention?.type) return false;
    final actualIds = actualMention?.userIdList ?? const <String>[];
    final expectedIds = expectedMention?.userIdList ?? const <String>[];
    if (actualIds.length != expectedIds.length) return false;
    for (var index = 0; index < actualIds.length; index++) {
      if (actualIds[index] != expectedIds[index]) return false;
    }
    return true;
  }

  bool _hasMessageModificationPayload(Message message) {
    try {
      return message.hasChanged == true ||
          message.modifyInfo?.content != null ||
          _modificationStatusOf(message) != null;
    } on NoSuchMethodError {
      return false;
    }
  }

  int _modificationStatusPriority(MessageModifyStatus? status) {
    return switch (status) {
      MessageModifyStatus.success => 3,
      MessageModifyStatus.failed => 2,
      MessageModifyStatus.updating => 1,
      null => 0,
    };
  }

  bool _shouldAcceptModifiedMessage(
    Message candidate,
    Message? current, {
    bool acceptEqualStatus = false,
  }) {
    if (!_hasMessageModificationPayload(candidate)) return false;
    if (current == null || !_hasMessageModificationPayload(current)) {
      return true;
    }
    final candidateTimestamp = _modificationTimestamp(candidate);
    final currentTimestamp = _modificationTimestamp(current);
    final candidateHasTimestamp =
        candidateTimestamp != null && candidateTimestamp > 0;
    final currentHasTimestamp =
        currentTimestamp != null && currentTimestamp > 0;
    if (candidateHasTimestamp && currentHasTimestamp) {
      if (candidateTimestamp != currentTimestamp) {
        return candidateTimestamp > currentTimestamp;
      }
      final candidatePriority = _modificationStatusPriority(
        _modificationStatusOf(candidate),
      );
      final currentPriority = _modificationStatusPriority(
        _modificationStatusOf(current),
      );
      return candidatePriority > currentPriority ||
          (acceptEqualStatus && candidatePriority == currentPriority);
    }
    if (candidateHasTimestamp) return true;
    if (currentHasTimestamp) return false;
    final candidateStatus = _modificationStatusOf(candidate);
    final currentStatus = _modificationStatusOf(current);
    final candidatePriority = _modificationStatusPriority(candidateStatus);
    final currentPriority = _modificationStatusPriority(currentStatus);
    return candidatePriority > currentPriority ||
        (acceptEqualStatus && candidatePriority == currentPriority);
  }

  void _setMessageModificationState(
    Message message, {
    required Message content,
    required int timestamp,
    required MessageModifyStatus status,
    required bool hasChanged,
  }) {
    try {
      message.raw.hasChanged = hasChanged;
      final rawContent = identical(message.raw, content.raw)
          ? null
          : content.raw;
      final rawStatus = switch (status) {
        MessageModifyStatus.success => RCIMIWMessageModifyStatus.success,
        MessageModifyStatus.updating => RCIMIWMessageModifyStatus.updating,
        MessageModifyStatus.failed => RCIMIWMessageModifyStatus.failed,
      };
      message.raw.modifyInfo = RCIMIWMessageModifyInfo.create(
        timestamp: timestamp,
        content: rawContent,
        status: rawStatus,
      );
    } catch (_) {
      // Test doubles and older wrappers may not expose mutable modification metadata.
    }
  }

  void _onMessagesDeleted() {
    final deleted = engineProvider.deletedMessagesNotifier.value;
    if (deleted == null || deleted.isEmpty) {
      return;
    }
    final sameChannelMessages = deleted.where(_sameChannel).toList();
    if (sameChannelMessages.isEmpty) {
      return;
    }
    var referenceChanged = false;
    for (final message in sameChannelMessages) {
      final original = _originalMessageFromRecall(message);
      final target = original ?? message;
      _invalidateMessageModification(target);
      if (!identical(target, message)) {
        _invalidateMessageModification(message);
      }
      referenceChanged =
          _applyReferenceTerminalEvent(
            target,
            _referenceTerminalStatusForDeletedEvent(message),
          ) ||
          referenceChanged;
    }
    final recalledMessages = sameChannelMessages
        .where(_isRecallMessage)
        .toList();
    final removedMessages = sameChannelMessages
        .where((message) => !_isRecallMessage(message))
        .toList();
    var changed = false;
    for (final recalledMessage in recalledMessages) {
      final original = _originalMessageFromRecall(recalledMessage);
      changed =
          _replaceMessageWithRecall(
            recalledMessage,
            original: original,
            notifyListeners: false,
          ) ||
          changed;
    }
    if (removedMessages.isNotEmpty) {
      changed =
          _removeMessages(removedMessages, notifyListeners: false) || changed;
    }
    if (changed || referenceChanged) {
      _safeNotifyListeners();
    }
  }

  void _handleRecallMessageEvent(Message message) {
    final original = _originalMessageFromRecall(message);
    final target = original ?? message;
    _invalidateMessageModification(target);
    if (!identical(target, message)) {
      _invalidateMessageModification(message);
    }
    final referenceChanged = _applyReferenceTerminalEvent(
      target,
      _referenceTerminalStatusForDeletedEvent(message),
    );
    final changed = _replaceMessageWithRecall(message, original: original);
    if (referenceChanged && !changed) _safeNotifyListeners();
  }

  void _onConnectionStatusChanged() {
    if (_disposed) return;
    if (connectionStatus != ConnectionStatus.connected) {
      _pauseReadReceiptSubmitQueue();
    }
    if (_isOfflineConnection(connectionStatus)) {
      _pauseReferenceRefreshesForDisconnect();
    } else if (connectionStatus == ConnectionStatus.connected) {
      _prepareReadReceiptSubmitQueueForReconnect();
      _scheduleReadReceiptSubmitQueue(_readReceiptBatchDelay);
      unawaited(_syncReadReceipts(_messages));
      _restartReferenceRefreshes();
    }
    _safeNotifyListeners();
  }

  void _onReadReceiptCapabilityChanged() {
    if (_disposed) return;
    if (_supportsReadReceipts(channel.channelType)) {
      unawaited(_syncReadReceipts(_messages));
    } else {
      engineProvider.readReceiptRepository.releaseOwner(this);
      _clearReadReceiptState();
    }
    _safeNotifyListeners();
  }

  void _onChannelUnreadStatusSync() {
    final event = engineProvider.channelUnreadStatusSyncNotifier.value;
    if (event == null || !_matchesChannelIdentifier(event.channelIdentifier)) {
      return;
    }
    if (_consumeSuppressedUnreadSync(event)) {
      return;
    }
    dismissUnreadHistoryTip();
    unawaited(loadInitialMessages());
  }
}
