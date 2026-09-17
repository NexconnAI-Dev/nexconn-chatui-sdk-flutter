part of '../chat_provider.dart';

const List<Duration> _readReceiptRetryDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];
const int _maxReadReceiptBatchSize = 100;
const int _maxReadReceiptCacheSize = 1000;
const Duration _readReceiptBatchDelay = Duration(milliseconds: 100);
const Duration _readReceiptOperationTimeout = Duration(seconds: 15);

extension _ChatProviderProviderInternals on ChatProvider {
  bool _readReceiptConfiguredForChannel(ChannelType type) =>
      readReceiptOptions.enabled &&
      readReceiptOptions.enabledChannelTypes.contains(type) &&
      (type == ChannelType.direct || type == ChannelType.group);

  Future<bool> _resolveDefaultNeedReceipt() async {
    if (!readReceiptOptions.defaultNeedReceipt ||
        !_readReceiptConfiguredForChannel(channel.channelType)) {
      return false;
    }
    return engineProvider.waitForReadReceiptV5(channel.channelType);
  }

  bool _supportsReadReceipts(ChannelType type) =>
      _readReceiptConfiguredForChannel(type) && _serverSupportsReadReceiptV5;

  bool get _serverSupportsReadReceiptV5 =>
      engineProvider.readReceiptVersion == ReadReceiptVersion.version5;

  bool _isCurrentReadReceiptKey(_ChatReadReceiptMessageKey key) {
    final identifier = channel.channelIdentifier;
    return key.channelType == identifier.channelType &&
        key.channelId == identifier.channelId &&
        key.subChannelId ==
            _ChatReadReceiptMessageKey.normalize(identifier.subChannelId);
  }

  bool _isReceiptBusinessMessage(Message message) {
    if (_isRecallMessage(message)) {
      return false;
    }
    final type = message.messageType;
    return type != null &&
        type != MessageType.unknown &&
        type != MessageType.command &&
        type != MessageType.commandNotification &&
        type != MessageType.groupNotification &&
        type != MessageType.informationNotification;
  }

  String? _messageIdOf(Message message) {
    try {
      return message.messageId;
    } on NoSuchMethodError {
      return null;
    }
  }

  bool? _needReceiptOf(Message message) {
    try {
      return message.needReceipt;
    } on NoSuchMethodError {
      return null;
    }
  }

  bool? _sentReceiptOf(Message message) {
    try {
      return message.sentReceipt;
    } on NoSuchMethodError {
      return null;
    }
  }

  Future<void> _syncReadReceipts(Iterable<Message> messages) async {
    if (_disposed ||
        !readReceiptOptions.enabled ||
        !_supportsReadReceipts(channel.channelType)) {
      engineProvider.readReceiptRepository.releaseOwner(this);
      return;
    }
    await engineProvider.readReceiptRepository.replaceOwnerMessages(
      this,
      _messages,
    );
  }

  void _clearReadReceiptState() {
    _readReceiptGeneration++;
    _submittedReadReceiptMessageIds.clear();
    _readReceiptSubmitQueue.completeAndClear();
    _submittingReadReceiptMessageIds.clear();
  }

  void _markReadReceiptSubmitted(_ChatReadReceiptMessageKey key) {
    _submittedReadReceiptMessageIds.remove(key);
    _submittedReadReceiptMessageIds.add(key);
    while (_submittedReadReceiptMessageIds.length > _maxReadReceiptCacheSize) {
      _submittedReadReceiptMessageIds.remove(
        _submittedReadReceiptMessageIds.first,
      );
    }
  }

  /// Queues a V5 read receipt only after a received message is visible.
  Future<void> _submitReadReceiptForVisible(
    Message message, {
    double visibleFraction = 1,
  }) {
    if (visibleFraction < 0.1 ||
        _disposed ||
        !readReceiptOptions.enabled ||
        !_readReceiptConfiguredForChannel(channel.channelType) ||
        _directionOf(message) != MessageDirection.receive ||
        _needReceiptOf(message) != true ||
        _sentReceiptOf(message) == true ||
        !_isReceiptBusinessMessage(message)) {
      return Future<void>.value();
    }
    final key = _ChatReadReceiptMessageKey.fromMessage(message);
    if (key == null || !_isCurrentReadReceiptKey(key)) {
      return Future<void>.value();
    }
    if (_submittedReadReceiptMessageIds.contains(key)) {
      return Future<void>.value();
    }
    final queued = _readReceiptSubmitQueue.submissionFor(key);
    if (queued != null) return queued.completer.future;

    final submission = _ChatReadReceiptSubmission(key: key, message: message);
    _readReceiptSubmitQueue.pending[key] = submission;
    _scheduleReadReceiptSubmitQueue(_readReceiptBatchDelay);
    return submission.completer.future;
  }

  void _scheduleReadReceiptSubmitQueue(Duration delay, {bool retry = false}) {
    final queue = _readReceiptSubmitQueue;
    if (_disposed ||
        connectionStatus != ConnectionStatus.connected ||
        !_supportsReadReceipts(channel.channelType) ||
        queue.requestActive ||
        queue.batchTimer?.isActive == true ||
        queue.retryTimer?.isActive == true ||
        (queue.currentBatch.isEmpty && queue.pending.isEmpty)) {
      return;
    }
    final timer = Timer(delay, () {
      if (retry) {
        queue.retryTimer = null;
      } else {
        queue.batchTimer = null;
      }
      _startReadReceiptSubmitQueue();
    });
    if (retry) {
      queue.retryTimer = timer;
    } else {
      queue.batchTimer = timer;
    }
  }

  void _startReadReceiptSubmitQueue() {
    final queue = _readReceiptSubmitQueue;
    if (_disposed ||
        connectionStatus != ConnectionStatus.connected ||
        !_supportsReadReceipts(channel.channelType) ||
        queue.requestActive) {
      return;
    }
    queue.currentBatch.removeWhere((submission) => submission.canceled);
    if (queue.currentBatch.isEmpty) {
      final entries = queue.pending.entries
          .take(_maxReadReceiptBatchSize)
          .toList(growable: false);
      if (entries.isEmpty) return;
      queue.currentBatch = entries
          .map((entry) => entry.value)
          .where((submission) => !submission.canceled)
          .toList();
      for (final entry in entries) {
        queue.pending.remove(entry.key);
      }
      if (queue.currentBatch.isEmpty) {
        _scheduleReadReceiptSubmitQueue(_readReceiptBatchDelay);
        return;
      }
    }

    final batch = List<_ChatReadReceiptSubmission>.unmodifiable(
      queue.currentBatch,
    );
    final keys = batch.map((submission) => submission.key).toList();
    queue.requestActive = true;
    _submittingReadReceiptMessageIds.addAll(keys);
    final generation = _readReceiptGeneration;
    final requestToken = ++queue.requestToken;
    var finished = false;

    bool isCurrent() =>
        !finished &&
        queue.requestActive &&
        queue.requestToken == requestToken &&
        !_disposed &&
        generation == _readReceiptGeneration;

    void finishSuccess() {
      if (!isCurrent()) return;
      finished = true;
      queue.deadlineTimer?.cancel();
      queue.deadlineTimer = null;
      queue.requestActive = false;
      _submittingReadReceiptMessageIds.removeAll(keys);
      for (final submission in batch) {
        if (submission.canceled) continue;
        _markReadReceiptSubmitted(submission.key);
        try {
          submission.message.sentReceipt = true;
        } on NoSuchMethodError {
          // Lightweight test doubles and older Nexconn versions may expose
          // only the getter. The provider cache still prevents resubmission.
        }
        submission.complete();
      }
      queue.currentBatch = <_ChatReadReceiptSubmission>[];
      queue.retryAttempt = 0;
      _scheduleReadReceiptSubmitQueue(_readReceiptBatchDelay);
    }

    void finishError() {
      if (!isCurrent()) return;
      finished = true;
      queue.deadlineTimer?.cancel();
      queue.deadlineTimer = null;
      queue.requestActive = false;
      _submittingReadReceiptMessageIds.removeAll(keys);
      queue.currentBatch.removeWhere((submission) => submission.canceled);
      if (connectionStatus != ConnectionStatus.connected) return;
      if (queue.currentBatch.isNotEmpty &&
          queue.retryAttempt < _readReceiptRetryDelays.length) {
        final delay = _readReceiptRetryDelays[queue.retryAttempt];
        queue.retryAttempt++;
        _scheduleReadReceiptSubmitQueue(delay, retry: true);
        return;
      }
      for (final submission in queue.currentBatch) {
        submission.complete();
      }
      queue.currentBatch = <_ChatReadReceiptSubmission>[];
      queue.retryAttempt = 0;
      _scheduleReadReceiptSubmitQueue(_readReceiptBatchDelay);
    }

    queue.deadlineTimer = Timer(_readReceiptOperationTimeout, finishError);
    unawaited(() async {
      try {
        final code = await channel.sendReadReceiptResponse(
          keys.map((key) => key.messageId).toList(growable: false),
          (error) {
            if ((error?.code ?? 0) == 0) {
              finishSuccess();
            } else {
              finishError();
            }
          },
        );
        if (code != 0) finishError();
      } catch (_) {
        finishError();
      }
    }());
  }

  void _pauseReadReceiptSubmitQueue() {
    final queue = _readReceiptSubmitQueue;
    queue.batchTimer?.cancel();
    queue.retryTimer?.cancel();
    queue.deadlineTimer?.cancel();
    queue.batchTimer = null;
    queue.retryTimer = null;
    queue.deadlineTimer = null;
    if (queue.requestActive) {
      queue.requestToken++;
      queue.requestActive = false;
      _submittingReadReceiptMessageIds.removeAll(
        queue.currentBatch.map((submission) => submission.key),
      );
    }
  }

  void _prepareReadReceiptSubmitQueueForReconnect() {
    _pauseReadReceiptSubmitQueue();
  }

  void _removeReadReceiptStateForMessages(Iterable<Message> messages) {
    engineProvider.readReceiptRepository.removeMessages(messages);
    final queue = _readReceiptSubmitQueue;
    for (final message in messages) {
      final key = _ChatReadReceiptMessageKey.fromMessage(message);
      if (key == null) continue;
      _submittedReadReceiptMessageIds.remove(key);
      final pending = queue.pending.remove(key);
      pending?.complete();
      for (final submission in queue.currentBatch) {
        if (submission.key != key) continue;
        submission.canceled = true;
        submission.complete();
      }
      _submittingReadReceiptMessageIds.remove(key);
    }
  }

  bool _isSuccess(NCError? error) {
    return error == null || error.code == 0;
  }

  int get _effectivePageSize => pageSize <= 0 ? 20 : pageSize;

  void _beginSearch(ChatMessageSearchRequest request) {
    _lastSearchRequest = request;
    _isSearching = true;
    _safeNotifyListeners();
  }

  Future<NCError?> _runChannelOperation(
    Future<NCError?> Function() task,
    String action, {
    FutureOr<void> Function()? onSuccess,
  }) async {
    try {
      final result = await task();
      _lastError = result;
      if (_isSuccess(result)) {
        await onSuccess?.call();
      }
      return result;
    } catch (error) {
      final converted = _toNCError(error);
      _lastError = converted;
      _callbacks.onUnsupportedAction?.call(action, converted.message ?? '');
      return converted;
    } finally {
      _safeNotifyListeners();
    }
  }

  NCError _toNCError(Object error) {
    if (error is NCError) {
      return error;
    }
    return NCError(code: 50000, message: error.toString());
  }

  MentionedInfoParams? _mentionedInfo(List<String>? mentionUserIds) {
    if (mentionUserIds == null || mentionUserIds.isEmpty) {
      return null;
    }
    return MentionedInfoParams(
      type: mentionUserIds.contains('All')
          ? MentionedType.all
          : MentionedType.part,
      userIdList: mentionUserIds,
    );
  }
}
