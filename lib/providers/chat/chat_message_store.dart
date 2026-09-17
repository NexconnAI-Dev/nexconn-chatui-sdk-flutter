part of '../chat_provider.dart';

extension _ChatProviderMessageStore on ChatProvider {
  void _syncLoadedMessagesDisplayState(Iterable<Message> messages) {
    for (final message in messages) {
      _restoreRememberedReferenceTerminalStatus(message);
      _syncOutgoingStatusOverrideFromMessage(message);
      if (_directionOf(message) != MessageDirection.send) {
        continue;
      }
      if (!engineProvider.isFailedMessage(message)) {
        continue;
      }
      final sentStatus = _sentStatusOf(message);
      _setOutgoingStatusOverride(
        message,
        sentStatus == SentStatus.canceled
            ? SentStatus.canceled
            : SentStatus.failed,
      );
    }
  }

  bool _consumeSuppressedChannelUpsert(Message message) {
    final keys = _identityKeysOf(message);
    if (keys.isEmpty || !keys.any(_suppressedChannelUpsertKeys.contains)) {
      return false;
    }
    _suppressedChannelUpsertKeys.removeAll(keys);
    return true;
  }

  void _notifyChannelMessageUpsertedFromLocal(
    Message message, {
    Message? original,
  }) {
    final keys = <String>{
      ..._identityKeysOf(message),
      if (original != null) ..._identityKeysOf(original),
    };
    _suppressedChannelUpsertKeys.addAll(keys);
    engineProvider.notifyChannelMessageUpserted(message);
  }

  bool _purgeLegacyPlaceholderMessages() {
    final previousMessageCount = _messages.length;
    final previousUnreadMentionCount = _unreadMentionedMessages.length;
    _messages = _messages
        .where((m) => !_isLegacyPlaceholderMessage(m))
        .toList();
    if (previousMessageCount != _messages.length) {
      _markMessageCachesDirty();
    }
    _unreadMentionedMessages = _unreadMentionedMessages
        .where((m) => !_isLegacyPlaceholderMessage(m))
        .toList();
    _unreadMentionCount = _unreadMentionedMessages.length;
    final currentReference = _referenceMessage;
    if (currentReference != null &&
        _isLegacyPlaceholderMessage(currentReference)) {
      _referenceMessage = null;
    }
    return previousMessageCount != _messages.length ||
        previousUnreadMentionCount != _unreadMentionedMessages.length ||
        (currentReference != null && _referenceMessage == null);
  }

  void _markReferenceMessageUnavailable(Message message, {Message? original}) {
    final keys = <String>{
      ..._identityKeysOf(message),
      if (original != null) ..._identityKeysOf(original),
    };
    if (keys.isEmpty) {
      return;
    }
    _unavailableReferenceMessageKeys.addAll(keys);
  }

  void _clearReferenceMessageUnavailable(Message message, {Message? original}) {
    final keys = <String>{
      ..._identityKeysOf(message),
      if (original != null) ..._identityKeysOf(original),
    };
    if (keys.isEmpty) {
      return;
    }
    _unavailableReferenceMessageKeys.removeAll(keys);
  }

  void _setOutgoingStatusOverride(
    Message message,
    SentStatus status, {
    Message? original,
  }) {
    final keys = <String>{
      ..._identityKeysOf(message),
      if (original != null) ..._identityKeysOf(original),
    };
    if (keys.isEmpty) {
      return;
    }
    for (final key in keys) {
      _outgoingStatusOverrides[key] = status;
    }
  }

  void _clearOutgoingStatusOverride(Message message, {Message? original}) {
    final keys = <String>{
      ..._identityKeysOf(message),
      if (original != null) ..._identityKeysOf(original),
    };
    if (keys.isEmpty) {
      return;
    }
    for (final key in keys) {
      _outgoingStatusOverrides.remove(key);
    }
  }

  void _markLocallyDeletedSendingMessage(Message message) {
    final keys = _identityKeysOf(message);
    if (keys.isEmpty) {
      return;
    }
    _locallyDeletedSendingMessageKeys.addAll(keys);
  }

  bool _isLocallyDeletedSendingMessage(Message message) {
    final keys = _identityKeysOf(message);
    if (keys.isEmpty) {
      return false;
    }
    return keys.any(_locallyDeletedSendingMessageKeys.contains);
  }

  void _syncOutgoingStatusOverrideFromMessage(
    Message message, {
    Message? original,
  }) {
    if (_directionOf(message) != MessageDirection.send) {
      _clearOutgoingStatusOverride(message, original: original);
      return;
    }
    final sentStatus = _sentStatusOf(message);
    if (sentStatus == null) {
      return;
    }
    if (sentStatus == SentStatus.sending) {
      final keys = <String>{
        ..._identityKeysOf(message),
        if (original != null) ..._identityKeysOf(original),
      };
      final hasTerminalFailureOverride = keys.any((key) {
        final override = _outgoingStatusOverrides[key];
        return override == SentStatus.failed || override == SentStatus.canceled;
      });
      if (hasTerminalFailureOverride) {
        return;
      }
      final hasSuccessfulSendOverride = keys.any(
        (key) => _outgoingStatusOverrides[key] == SentStatus.sent,
      );
      if (hasSuccessfulSendOverride) {
        return;
      }
    }
    if (sentStatus == SentStatus.sending ||
        sentStatus == SentStatus.failed ||
        sentStatus == SentStatus.canceled) {
      _setOutgoingStatusOverride(message, sentStatus, original: original);
      return;
    }
    _clearOutgoingStatusOverride(message, original: original);
  }

  bool _removeMessages(List<Message> messages, {bool notifyListeners = true}) {
    final purgedLegacy = _purgeLegacyPlaceholderMessages();
    if (messages.isEmpty) {
      if (purgedLegacy && notifyListeners) {
        _markReferenceMessageIndexDirty();
        _markMessageRenderChanged();
        _safeNotifyListeners();
      }
      return purgedLegacy;
    }
    for (final message in messages) {
      _invalidateMessageModification(message);
    }
    _removeReadReceiptStateForMessages(messages);
    final deletedKeys = messages.map(_keyOf).toSet();
    if (deletedKeys.isEmpty) {
      return false;
    }
    final previousMessageCount = _messages.length;
    final previousMentionCount = _unreadMentionedMessages.length;
    final previousSelectionCount = _selectedMessageKeys.length;
    _messages = _messages
        .where((m) => !deletedKeys.contains(_keyOf(m)))
        .toList();
    _markMessageCachesDirty();
    _unreadMentionedMessages = _unreadMentionedMessages
        .where((m) => !deletedKeys.contains(_keyOf(m)))
        .toList();
    _unreadMentionCount = _unreadMentionedMessages.length;
    final currentReference = _referenceMessage;
    if (currentReference != null &&
        deletedKeys.contains(_keyOf(currentReference))) {
      _referenceMessage = null;
    }
    for (final message in messages) {
      _markReferenceMessageUnavailable(message);
      _clearOutgoingStatusOverride(message);
      if (engineProvider.isFailedMessage(message)) {
        engineProvider.removeFailedMessage(message);
      }
    }
    _selectedMessageKeys.removeWhere(deletedKeys.contains);
    final changed =
        previousMessageCount != _messages.length ||
        previousMentionCount != _unreadMentionedMessages.length ||
        previousSelectionCount != _selectedMessageKeys.length ||
        (currentReference != null && _referenceMessage == null);
    if (changed || purgedLegacy) {
      _markReferenceMessageIndexDirty();
    }
    if ((changed || purgedLegacy) && notifyListeners) {
      _markMessageRenderChanged();
      _safeNotifyListeners();
    }
    return changed || purgedLegacy;
  }

  bool _replaceMessageWithRecall(
    Message recalledMessage, {
    Message? original,
    bool notifyListeners = true,
    bool notifyChannel = true,
  }) {
    _invalidateMessageModification(recalledMessage);
    if (original != null) {
      _invalidateMessageModification(original);
    }
    _removeReadReceiptStateForMessages([
      recalledMessage,
      if (original != null) original,
    ]);
    final recallKeys = <String>{
      _keyOf(recalledMessage),
      if (original != null) _keyOf(original),
    };
    final index = _messages.indexWhere(
      (message) => recallKeys.contains(_keyOf(message)),
    );
    var changed = false;
    if (index >= 0) {
      _messages[index] = recalledMessage;
      _markMessageCachesDirty();
      changed = true;
    }
    final previousMentionCount = _unreadMentionedMessages.length;
    _unreadMentionedMessages = _unreadMentionedMessages
        .where((message) => !recallKeys.contains(_keyOf(message)))
        .toList();
    _unreadMentionCount = _unreadMentionedMessages.length;
    final currentReference = _referenceMessage;
    if (currentReference != null &&
        recallKeys.contains(_keyOf(currentReference))) {
      _referenceMessage = null;
      changed = true;
    }
    final previousSelectionCount = _selectedMessageKeys.length;
    _selectedMessageKeys.removeWhere(recallKeys.contains);
    if (previousMentionCount != _unreadMentionedMessages.length ||
        previousSelectionCount != _selectedMessageKeys.length) {
      changed = true;
    }
    _markReferenceMessageUnavailable(recalledMessage, original: original);
    if (changed) {
      _markMessageCachesDirty();
      _markReferenceMessageIndexDirty();
    }
    if (changed && notifyListeners) {
      _markMessageRenderChanged();
      if (notifyChannel) {
        _notifyChannelMessageUpsertedFromLocal(
          recalledMessage,
          original: original,
        );
      }
      _safeNotifyListeners();
    }
    return changed;
  }

  void _upsertMessage(Message message) {
    _upsertMessageInternal(message, notifyChannel: true);
  }

  void _upsertMessageFromEngine(Message message) {
    _upsertMessageInternal(message, notifyChannel: false);
  }

  void _upsertMessageInternal(Message message, {required bool notifyChannel}) {
    _purgeLegacyPlaceholderMessages();
    final effectiveMessage = message;
    _restoreRememberedReferenceTerminalStatus(effectiveMessage);
    _clearReferenceMessageUnavailable(effectiveMessage);
    _syncOutgoingStatusOverrideFromMessage(effectiveMessage);
    final identityKeys = _identityKeysOf(effectiveMessage);

    var index = -1;
    final messageId = effectiveMessage.messageId;
    if (messageId != null && messageId.isNotEmpty) {
      index = _messageIndexForId(messageId) ?? -1;
    }
    if (index < 0) {
      index = _messages.indexWhere((m) => _sharesIdentity(m, identityKeys));
    }
    if (index >= 0) {
      final previous = _messages[index];
      _messages[index] = effectiveMessage;
      _updateCachedMessageAt(index, effectiveMessage, previous: previous);
    } else {
      _messages = [..._messages, effectiveMessage];
      _markMessageCachesDirty();
    }
    _markReferenceMessageIndexDirty();
    final unreadIndex = _unreadMentionedMessages.indexWhere(
      (m) => _sharesIdentity(m, identityKeys),
    );
    if (unreadIndex >= 0) {
      _unreadMentionedMessages[unreadIndex] = effectiveMessage;
    }
    if (notifyChannel) {
      _notifyChannelMessageUpsertedFromLocal(effectiveMessage);
    }
    _markMessageRenderChanged();
    _safeNotifyListeners();
  }

  void _upsertMessages(List<Message> messages) {
    if (messages.isEmpty) {
      return;
    }
    _purgeLegacyPlaceholderMessages();
    final mergedMessages = <String, Message>{
      for (final message in _messages) _keyOf(message): message,
    };
    for (final message in messages) {
      final effectiveMessage = message;
      mergedMessages[_keyOf(effectiveMessage)] = effectiveMessage;
    }
    _messages = mergedMessages.values.toList();
    _markMessageCachesDirty();
    _markReferenceMessageIndexDirty();
    _markMessageRenderChanged();

    if (_unreadMentionedMessages.isNotEmpty) {
      final mergedUnreadMentioned = <String, Message>{
        for (final message in _unreadMentionedMessages)
          _keyOf(message): message,
      };
      for (final message in messages) {
        final effectiveMessage = message;
        final key = _keyOf(effectiveMessage);
        if (mergedUnreadMentioned.containsKey(key)) {
          mergedUnreadMentioned[key] = effectiveMessage;
        }
      }
      _unreadMentionedMessages = mergedUnreadMentioned.values.toList();
      _unreadMentionCount = _unreadMentionedMessages.length;
    }
  }

  Future<void> _refreshUnreadMentionedMessages() async {
    try {
      final messages = await _operations.getUnreadMentionedMessages(channel);
      _setUnreadMentionedMessages(messages);
      _lastError = null;
    } catch (_) {
      // Keep the initial channel-level mention count when the SDK cannot
      // provide a concrete unread-mentioned list for the current session.
    } finally {
      _safeNotifyListeners();
    }
  }

  void _setUnreadMentionedMessages(List<Message> messages) {
    final deduped = <String, Message>{};
    for (final message in messages) {
      deduped[_keyOf(message)] = message;
    }
    _unreadMentionedMessages = deduped.values.toList();
    _unreadMentionCount = _unreadMentionedMessages.length;
  }
}
