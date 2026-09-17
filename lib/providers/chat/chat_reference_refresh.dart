part of '../chat_provider.dart';

const int _maxReferenceRefreshBatchSize = 20;
const int _referenceMessageNotFoundCode = 33403;
const int _referenceRemoteDataNotFoundCode = 34304;
const Duration _referenceRefreshTimeout = Duration(seconds: 15);
const List<Duration> _referenceRefreshRetryDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];

extension _ChatProviderReferenceRefresh on ChatProvider {
  Future<void> _refreshReferenceMessages(
    Iterable<Message> messages, {
    bool force = false,
  }) async {
    if (_disposed) return;
    _ensureReferenceRefreshUserScope();
    if (force) {
      _invalidateReferenceRefreshRequests(resetRetry: true);
    }

    final candidates = <String, ReferenceMessage>{};
    for (final message in messages) {
      if (message is! ReferenceMessage) continue;
      _restoreRememberedReferenceTerminalStatus(message);
      final messageId = _messageIdOf(message);
      if (messageId == null || messageId.isEmpty) continue;
      if (_isReferenceTerminal(_referenceStatusOf(message))) continue;
      if (!force && _referenceRefreshRequestIds.containsKey(messageId)) {
        continue;
      }
      candidates[messageId] = message;
    }
    if (candidates.isEmpty) return;

    final ids = candidates.keys.toList(growable: false);
    for (
      var offset = 0;
      offset < ids.length;
      offset += _maxReferenceRefreshBatchSize
    ) {
      final end = (offset + _maxReferenceRefreshBatchSize).clamp(0, ids.length);
      final batch = ids.sublist(offset, end);
      unawaited(_startReferenceRefreshBatch(batch));
    }
  }

  Future<void> _startReferenceRefreshBatch(List<String> messageIds) async {
    if (_disposed || messageIds.isEmpty) return;
    final requestId = ++_referenceRefreshRequestSequence;
    final generation = _referenceRefreshGeneration;
    final identifier = channel.channelIdentifier;
    final channelType = identifier.channelType;
    final channelId = identifier.channelId;
    final subChannelId = _normalizedSubChannelId(identifier.subChannelId);
    final userId = engineProvider.currentUserId;
    final handledMessageIds = <String>{};
    var finished = false;

    for (final messageId in messageIds) {
      _referenceRefreshRequestIds[messageId] = requestId;
      _referenceRefreshRemoteRequestIds.remove(messageId);
    }
    bool isCurrent() => _isReferenceRefreshContextCurrent(
      generation: generation,
      channelType: channelType,
      channelId: channelId,
      subChannelId: subChannelId,
      userId: userId,
    );

    void finish({required bool success}) {
      if (finished) return;
      finished = true;
      _referenceRefreshTimeoutTimers.remove(requestId)?.cancel();
      for (final messageId in messageIds) {
        if (_referenceRefreshRequestIds[messageId] == requestId) {
          _referenceRefreshRequestIds.remove(messageId);
        }
        if (_referenceRefreshRemoteRequestIds[messageId] == requestId) {
          _referenceRefreshRemoteRequestIds.remove(messageId);
        }
      }
      if (success) {
        _referenceRefreshRetryRequestIds.remove(requestId);
        if (_referenceRefreshRetryRequestIds.isEmpty) {
          _referenceRefreshRetryPending = false;
          _referenceRefreshRetryTimer?.cancel();
          _referenceRefreshRetryTimer = null;
          if (_referenceRefreshRequestIds.isEmpty) {
            _referenceRefreshRetryAttempt = 0;
          }
        }
      } else if (isCurrent()) {
        _markReferenceRefreshRetryNeeded(requestId);
      }
    }

    _referenceRefreshTimeoutTimers[requestId] = Timer(
      _referenceRefreshTimeout,
      () {
        _referenceRefreshTimeoutTimers.remove(requestId);
        if (!finished && isCurrent()) {
          // Keep request ownership until a newer request starts. Native can
          // deliver a valid remote stage after this watchdog fires.
          _markReferenceRefreshRetryNeeded(requestId);
        }
      },
    );

    try {
      final code = await channel.refreshReferenceMessages(
        messageIds,
        RefreshReferenceMessagesCallback(
          onLocalResults: (results) {
            if (finished || !isCurrent()) return;
            handledMessageIds.addAll(
              _applyReferenceRefreshResults(
                requestId,
                messageIds,
                results,
                isRemote: false,
              ),
            );
          },
          onRemoteResults: (results) {
            if (finished || !isCurrent()) return;
            for (final messageId in messageIds) {
              if (_referenceRefreshRequestIds[messageId] == requestId) {
                _referenceRefreshRemoteRequestIds[messageId] = requestId;
              }
            }
            handledMessageIds.addAll(
              _applyReferenceRefreshResults(
                requestId,
                messageIds,
                results,
                isRemote: true,
              ),
            );
            finish(success: messageIds.every(handledMessageIds.contains));
          },
          onError: (_) => finish(success: false),
        ),
      );
      if (code != 0) finish(success: false);
    } catch (_) {
      finish(success: false);
    }
  }

  Set<String> _applyReferenceRefreshResults(
    int requestId,
    List<String> requestedMessageIds,
    List<ReferenceMessageRefreshResult> results, {
    required bool isRemote,
  }) {
    final requested = requestedMessageIds.toSet();
    final handled = <String>{};
    var changed = false;
    for (final result in results) {
      final refreshed = result.message;
      final messageId = _firstNonEmpty(
        result.messageId,
        refreshed == null ? null : _messageIdOf(refreshed),
      );
      if (messageId == null ||
          !requested.contains(messageId) ||
          _referenceRefreshRequestIds[messageId] != requestId ||
          (!isRemote &&
              _referenceRefreshRemoteRequestIds[messageId] == requestId)) {
        continue;
      }

      final missingStatus = _referenceMissingStatus(
        code: result.code,
        isRemote: isRemote,
      );
      final refreshedReference = refreshed is ReferenceMessage
          ? refreshed
          : null;
      final incomingStatus = refreshedReference == null
          ? null
          : _referenceStatusOf(refreshedReference);
      final hasTerminalStatus =
          incomingStatus != null && _isReferenceTerminal(incomingStatus);
      if ((result.code ?? 0) != 0 &&
          missingStatus == null &&
          !hasTerminalStatus) {
        continue;
      }
      if (missingStatus == null && refreshedReference == null) continue;

      handled.add(messageId);
      final current = _messageById(messageId);
      if (current is! ReferenceMessage) continue;
      changed =
          _mergeReferenceRefreshResult(
            current,
            refreshedReference,
            statusOverride: missingStatus,
          ) ||
          changed;
    }
    if (changed) _safeNotifyListeners();
    return handled;
  }

  bool _mergeReferenceRefreshResult(
    ReferenceMessage current,
    ReferenceMessage? refreshed, {
    ReferenceMessageStatus? statusOverride,
  }) {
    final currentStatus = _referenceStatusOf(current);
    final incomingStatus =
        statusOverride ??
        (refreshed == null
            ? ReferenceMessageStatus.defaultValue
            : _referenceStatusOf(refreshed));
    final mergedStatus = _maxReferenceStatus(currentStatus, incomingStatus);
    var changed = false;
    if (mergedStatus != currentStatus) {
      changed = _setReferenceStatus(current, mergedStatus) || changed;
    }

    final currentReference = _referenceMessageOf(current);
    final incomingReference = refreshed == null
        ? null
        : _referenceMessageOf(refreshed);
    final targetId = _firstNonEmpty(
      currentReference == null ? null : _messageIdOf(currentReference),
      incomingReference == null ? null : _messageIdOf(incomingReference),
    );
    if (_isReferenceTerminal(mergedStatus)) {
      _rememberReferenceTerminalStatus(
        current,
        mergedStatus,
        targetId: targetId,
      );
      return changed;
    }

    Message? replacement = incomingReference;
    final latestModified = targetId == null
        ? null
        : _latestModifiedMessages[targetId];
    if (latestModified != null && _isSuccessfulModification(latestModified)) {
      replacement = latestModified;
    }
    if (replacement != null &&
        _referenceStatusRank(incomingStatus) >=
            _referenceStatusRank(currentStatus) &&
        !identical(currentReference, replacement)) {
      try {
        current.referenceMsg = replacement;
        changed = true;
      } on NoSuchMethodError {
        // Preserve compatibility with older/custom ReferenceMessage adapters.
      }
    }
    return changed;
  }

  bool _preserveReferenceStateForReplacement(
    Message current,
    Message replacement,
  ) {
    if (current is! ReferenceMessage || replacement is! ReferenceMessage) {
      return false;
    }
    final currentStatus = _referenceStatusOf(current);
    final replacementStatus = _referenceStatusOf(replacement);
    final mergedStatus = _maxReferenceStatus(currentStatus, replacementStatus);
    var changed = false;
    if (mergedStatus != replacementStatus) {
      changed = _setReferenceStatus(replacement, mergedStatus) || changed;
    }
    if (_isReferenceTerminal(mergedStatus)) {
      final currentReference = _referenceMessageOf(current);
      if (currentReference != null &&
          !identical(_referenceMessageOf(replacement), currentReference)) {
        try {
          replacement.referenceMsg = currentReference;
          changed = true;
        } on NoSuchMethodError {
          // Preserve compatibility with older/custom ReferenceMessage adapters.
        }
      }
      _rememberReferenceTerminalStatus(replacement, mergedStatus);
    }
    return changed;
  }

  bool _applyReferenceTerminalEvent(
    Message target,
    ReferenceMessageStatus status,
  ) {
    _ensureReferenceRefreshUserScope();
    final targetId = _messageIdOf(target);
    if (targetId != null && targetId.isNotEmpty) {
      final existing = _referenceTerminalStatusesByTargetId[targetId];
      _referenceTerminalStatusesByTargetId[targetId] = existing == null
          ? status
          : _maxReferenceStatus(existing, status);
    }
    final identityKeys = _identityKeysOf(target);
    var changed = false;
    for (final message in _messages) {
      if (message is! ReferenceMessage) continue;
      final referenced = _referenceMessageOf(message);
      if (referenced == null) continue;
      final matches =
          targetId != null && _messageIdOf(referenced) == targetId ||
          (identityKeys.isNotEmpty &&
              _sharesIdentity(referenced, identityKeys));
      if (!matches) continue;
      final currentStatus = _referenceStatusOf(message);
      final mergedStatus = _maxReferenceStatus(currentStatus, status);
      if (mergedStatus != currentStatus) {
        changed = _setReferenceStatus(message, mergedStatus) || changed;
      }
      _rememberReferenceTerminalStatus(
        message,
        mergedStatus,
        targetId: targetId,
      );
    }
    return changed;
  }

  Message? _originalMessageFromRecall(Message message) {
    try {
      final raw = message.raw;
      if (raw is RCIMIWRecallNotificationMessage &&
          raw.originalMessage != null) {
        return Message.fromRaw(raw.originalMessage!);
      }
    } catch (_) {
      // Some adapters expose recall notifications without the raw payload.
    }
    return null;
  }

  ReferenceMessageStatus _referenceTerminalStatusForDeletedEvent(
    Message message,
  ) {
    if (!_isRecallMessage(message)) return ReferenceMessageStatus.deleted;
    try {
      final raw = message.raw;
      if (raw is RCIMIWRecallNotificationMessage && raw.deleted == true) {
        return ReferenceMessageStatus.deleted;
      }
    } catch (_) {
      // A recall placeholder without the native flag is treated as recalled.
    }
    return ReferenceMessageStatus.recalled;
  }

  void _restoreRememberedReferenceTerminalStatus(Message message) {
    if (message is! ReferenceMessage) return;
    _ensureReferenceRefreshUserScope();
    final status = _referenceStatusOf(message);
    final outerId = _messageIdOf(message);
    final referenced = _referenceMessageOf(message);
    final targetId = referenced == null ? null : _messageIdOf(referenced);
    var merged = status;
    if (outerId != null) {
      final remembered = _referenceTerminalStatusesByOuterId[outerId];
      if (remembered != null) merged = _maxReferenceStatus(merged, remembered);
    }
    if (targetId != null) {
      final remembered = _referenceTerminalStatusesByTargetId[targetId];
      if (remembered != null) merged = _maxReferenceStatus(merged, remembered);
    }
    if (merged != status) _setReferenceStatus(message, merged);
    if (_isReferenceTerminal(merged)) {
      _rememberReferenceTerminalStatus(message, merged, targetId: targetId);
    }
  }

  void _rememberReferenceTerminalStatus(
    ReferenceMessage message,
    ReferenceMessageStatus status, {
    String? targetId,
  }) {
    if (!_isReferenceTerminal(status)) return;
    final outerId = _messageIdOf(message);
    if (outerId != null && outerId.isNotEmpty) {
      final current = _referenceTerminalStatusesByOuterId[outerId];
      _referenceTerminalStatusesByOuterId[outerId] = current == null
          ? status
          : _maxReferenceStatus(current, status);
    }
    final resolvedTargetId = _firstNonEmpty(
      targetId,
      _referenceMessageOf(message) == null
          ? null
          : _messageIdOf(_referenceMessageOf(message)!),
    );
    if (resolvedTargetId != null) {
      final current = _referenceTerminalStatusesByTargetId[resolvedTargetId];
      _referenceTerminalStatusesByTargetId[resolvedTargetId] = current == null
          ? status
          : _maxReferenceStatus(current, status);
    }
  }

  ReferenceMessageStatus _referenceStatusOf(ReferenceMessage message) {
    try {
      return message.referenceMessageStatus ??
          ReferenceMessageStatus.defaultValue;
    } on NoSuchMethodError {
      return ReferenceMessageStatus.defaultValue;
    }
  }

  Message? _referenceMessageOf(ReferenceMessage message) {
    try {
      return message.referenceMsg;
    } on NoSuchMethodError {
      return null;
    }
  }

  bool _setReferenceStatus(
    ReferenceMessage message,
    ReferenceMessageStatus status,
  ) {
    try {
      if (message.referenceMessageStatus == status) return false;
      message.referenceMessageStatus = status;
      return true;
    } on NoSuchMethodError {
      return false;
    }
  }

  ReferenceMessageStatus _maxReferenceStatus(
    ReferenceMessageStatus first,
    ReferenceMessageStatus second,
  ) => _referenceStatusRank(first) >= _referenceStatusRank(second)
      ? first
      : second;

  int _referenceStatusRank(ReferenceMessageStatus status) => switch (status) {
    ReferenceMessageStatus.defaultValue => 0,
    ReferenceMessageStatus.modified => 1,
    ReferenceMessageStatus.recalled => 2,
    ReferenceMessageStatus.deleted => 3,
  };

  bool _isReferenceTerminal(ReferenceMessageStatus status) =>
      status == ReferenceMessageStatus.recalled ||
      status == ReferenceMessageStatus.deleted;

  ReferenceMessageStatus? _referenceMissingStatus({
    required int? code,
    required bool isRemote,
  }) {
    if (!isRemote) return null;
    if (code == _referenceMessageNotFoundCode ||
        code == _referenceRemoteDataNotFoundCode) {
      return ReferenceMessageStatus.deleted;
    }
    return null;
  }

  bool _isReferenceRefreshContextCurrent({
    required int generation,
    required ChannelType channelType,
    required String channelId,
    required String? subChannelId,
    required String userId,
  }) {
    final current = channel.channelIdentifier;
    return !_disposed &&
        generation == _referenceRefreshGeneration &&
        current.channelType == channelType &&
        current.channelId == channelId &&
        _normalizedSubChannelId(current.subChannelId) == subChannelId &&
        engineProvider.currentUserId == userId;
  }

  String? _firstNonEmpty(String? first, String? second) {
    if (first != null && first.isNotEmpty) return first;
    if (second != null && second.isNotEmpty) return second;
    return null;
  }

  void _markReferenceRefreshRetryNeeded(int requestId) {
    if (_disposed) return;
    _referenceRefreshRetryRequestIds.add(requestId);
    _referenceRefreshRetryPending = true;
    if (connectionStatus != ConnectionStatus.connected ||
        _referenceRefreshRetryTimer != null ||
        _referenceRefreshRetryAttempt >= _referenceRefreshRetryDelays.length) {
      return;
    }
    final delay = _referenceRefreshRetryDelays[_referenceRefreshRetryAttempt++];
    final generation = _referenceRefreshGeneration;
    _referenceRefreshRetryTimer = Timer(delay, () {
      _referenceRefreshRetryTimer = null;
      if (_disposed ||
          generation != _referenceRefreshGeneration ||
          !_referenceRefreshRetryPending ||
          connectionStatus != ConnectionStatus.connected) {
        return;
      }
      _referenceRefreshRetryPending = false;
      _invalidateReferenceRefreshRequests(resetRetry: false);
      unawaited(_refreshReferenceMessages(_messages));
    });
  }

  void _pauseReferenceRefreshesForDisconnect() {
    _ensureReferenceRefreshUserScope();
    final hasRefreshableReferences = _messages.any(
      (message) =>
          message is ReferenceMessage &&
          !_isReferenceTerminal(_referenceStatusOf(message)),
    );
    _invalidateReferenceRefreshRequests(resetRetry: false);
    _referenceRefreshRetryPending = hasRefreshableReferences;
  }

  void _restartReferenceRefreshes() {
    _ensureReferenceRefreshUserScope();
    _invalidateReferenceRefreshRequests(resetRetry: true);
    unawaited(_refreshReferenceMessages(_messages));
  }

  void _invalidateReferenceRefreshRequests({required bool resetRetry}) {
    _referenceRefreshGeneration++;
    for (final timer in _referenceRefreshTimeoutTimers.values) {
      timer.cancel();
    }
    _referenceRefreshTimeoutTimers.clear();
    _referenceRefreshRequestIds.clear();
    _referenceRefreshRemoteRequestIds.clear();
    _referenceRefreshRetryRequestIds.clear();
    _referenceRefreshRetryTimer?.cancel();
    _referenceRefreshRetryTimer = null;
    _referenceRefreshRetryPending = false;
    if (resetRetry) _referenceRefreshRetryAttempt = 0;
  }

  void _clearReferenceRefreshState() {
    _invalidateReferenceRefreshRequests(resetRetry: true);
    _referenceTerminalStatusesByOuterId.clear();
    _referenceTerminalStatusesByTargetId.clear();
    _referenceRefreshUserId = null;
  }

  void _ensureReferenceRefreshUserScope() {
    final currentUserId = engineProvider.currentUserId;
    final previousUserId = _referenceRefreshUserId;
    if (previousUserId == null) {
      _referenceRefreshUserId = currentUserId;
      return;
    }
    if (previousUserId == currentUserId) return;
    _invalidateReferenceRefreshRequests(resetRetry: true);
    _referenceTerminalStatusesByOuterId.clear();
    _referenceTerminalStatusesByTargetId.clear();
    _unavailableReferenceMessageKeys.clear();
    _latestModifiedMessages.clear();
    _messageModificationEventRevisions.clear();
    _terminalMessageEditIds.clear();
    _referenceRefreshUserId = currentUserId;
  }
}
