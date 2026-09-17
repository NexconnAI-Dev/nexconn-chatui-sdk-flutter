import 'dart:async';
import 'dart:collection';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/foundation.dart';

/// Executes one V5 read-receipt lookup for at most 100 message identifiers.
typedef NexconnReadReceiptInfoQuery =
    Future<int> Function(
      List<MessageIdentifier> identifiers,
      OperationHandler<List<ReadReceiptInfo>> handler,
    );

enum ChatReadReceiptDisplayState { unread, partial, read }

/// Cached V5 read-receipt counts used by chat bubbles and channel rows.
class ChatReadReceiptDisplayData {
  final int readCount;
  final int unreadCount;
  final int totalCount;
  final bool isAuthoritative;

  const ChatReadReceiptDisplayData({
    this.readCount = 0,
    this.unreadCount = 0,
    this.totalCount = 0,
    this.isAuthoritative = false,
  });

  int get effectiveTotalCount =>
      totalCount > 0 ? totalCount : readCount + unreadCount;

  double get readRatio => effectiveTotalCount <= 0
      ? 0
      : (readCount / effectiveTotalCount).clamp(0.0, 1.0);

  ChatReadReceiptDisplayState get state {
    if (readCount <= 0) return ChatReadReceiptDisplayState.unread;
    if (effectiveTotalCount > 0 && readCount < effectiveTotalCount) {
      return ChatReadReceiptDisplayState.partial;
    }
    return ChatReadReceiptDisplayState.read;
  }
}

/// Engine-scoped V5 read-receipt query/cache shared by chat and channel lists.
class NexconnReadReceiptV5Repository with ChangeNotifier {
  static const int maxBatchSize = 100;
  static const int _maxCacheSize = 1000;
  static const Duration _requestTimeout = Duration(seconds: 15);
  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final NexconnReadReceiptInfoQuery _query;
  final LinkedHashMap<_ReadReceiptMessageKey, ChatReadReceiptDisplayData>
  _displayCache =
      LinkedHashMap<_ReadReceiptMessageKey, ChatReadReceiptDisplayData>();
  final Map<Object, Set<_ReadReceiptMessageKey>> _ownerKeys =
      <Object, Set<_ReadReceiptMessageKey>>{};
  final Map<_ReadReceiptMessageKey, Set<Object>> _keyOwners =
      <_ReadReceiptMessageKey, Set<Object>>{};
  final Set<_ReadReceiptMessageKey> _querying = <_ReadReceiptMessageKey>{};
  final Map<_ReadReceiptMessageKey, int> _eventRevisions =
      <_ReadReceiptMessageKey, int>{};
  final Map<_ReadReceiptMessageKey, int> _retryAttempts =
      <_ReadReceiptMessageKey, int>{};
  final Map<_ReadReceiptMessageKey, Duration> _retryWaits =
      <_ReadReceiptMessageKey, Duration>{};
  final Set<_ReadReceiptMessageKey> _retryTimerBatch =
      <_ReadReceiptMessageKey>{};
  final Map<Completer<void>, Timer> _operationTimers =
      <Completer<void>, Timer>{};
  final Set<Completer<void>> _pendingOperations = <Completer<void>>{};

  String _currentUserId;
  ConnectionStatus _connectionStatus;
  ReadReceiptVersion? _version;
  Timer? _retryTimer;
  bool _drainingRetries = false;
  bool _disposed = false;
  int _generation = 0;

  NexconnReadReceiptV5Repository({
    String currentUserId = '',
    ConnectionStatus connectionStatus = ConnectionStatus.unknown,
    ReadReceiptVersion? version,
    NexconnReadReceiptInfoQuery? query,
  }) : _currentUserId = currentUserId,
       _connectionStatus = connectionStatus,
       _version = version,
       _query = query ?? BaseChannel.getMessageReadReceiptInfoByIdentifiers;

  bool isEnabledFor(ChannelType type) =>
      !_disposed &&
      _version == ReadReceiptVersion.version5 &&
      (type == ChannelType.direct || type == ChannelType.group);

  ChatReadReceiptDisplayData? dataForMessage(Message message) {
    final key = _ReadReceiptMessageKey.fromMessage(message);
    if (key == null) return null;
    final data = _displayCache.remove(key);
    if (data != null) _displayCache[key] = data;
    return data;
  }

  /// Replaces all messages observed by [owner] and queries missing V5 state.
  ///
  /// Exact owner tracking lets a disposed ChatProvider cancel retries unless a
  /// ChannelProvider still needs the same cache entry.
  Future<void> replaceOwnerMessages(
    Object owner,
    Iterable<Message> messages,
  ) async {
    if (_disposed) return;
    final nextKeys = <_ReadReceiptMessageKey>{};
    for (final message in messages) {
      if (!_isQueryableOutgoingMessage(message)) continue;
      final key = _ReadReceiptMessageKey.fromMessage(message);
      if (key != null) nextKeys.add(key);
    }
    _replaceOwnerKeys(owner, nextKeys);
    if (!_canQuery) return;

    final candidates = nextKeys
        .where(
          (key) =>
              _hasObservers(key) &&
              !_querying.contains(key) &&
              !_retryWaits.containsKey(key) &&
              (_retryAttempts[key] ?? 0) < _retryDelays.length &&
              _displayCache[key]?.isAuthoritative != true,
        )
        .toList(growable: false);
    await _queryInBatches(candidates);
  }

  void releaseOwner(Object owner) {
    if (_disposed) return;
    _replaceOwnerKeys(owner, const <_ReadReceiptMessageKey>{});
  }

  void removeMessages(Iterable<Message> messages) {
    if (_disposed) return;
    var changed = false;
    for (final message in messages) {
      final key = _ReadReceiptMessageKey.fromMessage(message);
      if (key == null) continue;
      changed = _displayCache.remove(key) != null || changed;
      _eventRevisions[key] = (_eventRevisions[key] ?? 0) + 1;
      _clearRetry(key, restartTimer: false);
      final owners = _keyOwners.remove(key);
      for (final owner in owners ?? const <Object>{}) {
        _ownerKeys[owner]?.remove(key);
      }
    }
    _restartRetryTimer();
    if (changed) notifyListeners();
  }

  void handleResponses(List<MessageReadReceiptResponse>? responses) {
    if (_disposed || responses == null || responses.isEmpty) return;
    var changed = false;
    for (final response in responses) {
      final identifier = response.channelIdentifier;
      final key = identifier == null
          ? null
          : _ReadReceiptMessageKey.fromIdentifier(
              identifier,
              response.messageId,
            );
      if (key == null || !isEnabledFor(key.channelType)) continue;
      _eventRevisions[key] = (_eventRevisions[key] ?? 0) + 1;
      _clearRetry(key, restartTimer: false);
      _putData(
        key,
        ChatReadReceiptDisplayData(
          readCount: response.readCount ?? 0,
          unreadCount: response.unreadCount ?? 0,
          totalCount: response.totalCount ?? 0,
          isAuthoritative: true,
        ),
      );
      changed = true;
    }
    _restartRetryTimer();
    if (changed) notifyListeners();
  }

  void updateAccount(String userId) {
    if (_disposed || _currentUserId == userId) return;
    _currentUserId = userId;
    _invalidate(clearCache: true, clearOwners: true);
  }

  void updateCapability(ReadReceiptVersion? version) {
    if (_disposed || _version == version) return;
    _version = version;
    _invalidate(clearCache: true);
  }

  void updateConnectionStatus(ConnectionStatus status) {
    if (_disposed || _connectionStatus == status) return;
    _connectionStatus = status;
    _invalidate(clearCache: status == ConnectionStatus.connected);
  }

  bool get _canQuery =>
      !_disposed &&
      _version == ReadReceiptVersion.version5 &&
      _connectionStatus == ConnectionStatus.connected;

  bool _isQueryableOutgoingMessage(Message message) {
    final type = _safeRead(() => message.channelType);
    if (type == null || !isEnabledFor(type)) return false;
    if (_safeRead(() => message.direction) != MessageDirection.send ||
        _safeRead(() => message.needReceipt) != true) {
      return false;
    }
    final status = _safeRead(() => message.sentStatus);
    if (status == SentStatus.sending ||
        status == SentStatus.failed ||
        status == SentStatus.canceled) {
      return false;
    }
    final messageType = _safeRead(() => message.messageType);
    return messageType != null &&
        messageType != MessageType.unknown &&
        messageType != MessageType.command &&
        messageType != MessageType.commandNotification &&
        messageType != MessageType.groupNotification &&
        messageType != MessageType.informationNotification;
  }

  Future<void> _queryBatch(List<_ReadReceiptMessageKey> requested) async {
    if (!_canQuery || requested.isEmpty) return;
    final batch = requested
        .where(
          (key) =>
              _hasObservers(key) &&
              !_querying.contains(key) &&
              !_retryWaits.containsKey(key) &&
              _displayCache[key]?.isAuthoritative != true,
        )
        .take(maxBatchSize)
        .toList(growable: false);
    if (batch.isEmpty) return;

    _querying.addAll(batch);
    final generation = _generation;
    final userId = _currentUserId;
    final revisions = <_ReadReceiptMessageKey, int>{
      for (final key in batch) key: _eventRevisions[key] ?? 0,
    };
    var succeeded = false;
    List<ReadReceiptInfo>? infos;
    var completed = false;
    final completer = Completer<void>();

    void complete(bool success, List<ReadReceiptInfo>? value) {
      if (completed) return;
      completed = true;
      succeeded = success;
      infos = value;
      if (!completer.isCompleted) completer.complete();
    }

    _pendingOperations.add(completer);
    _operationTimers[completer] = Timer(
      _requestTimeout,
      () => complete(false, null),
    );
    unawaited(() async {
      try {
        final code = await _query(
          batch.map((key) => key.toIdentifier()).toList(growable: false),
          (value, error) => complete((error?.code ?? 0) == 0, value),
        );
        if (code != 0) complete(false, null);
      } catch (_) {
        complete(false, null);
      }
    }());

    await completer.future;
    _pendingOperations.remove(completer);
    _operationTimers.remove(completer)?.cancel();
    _querying.removeAll(batch);
    if (_disposed ||
        generation != _generation ||
        userId != _currentUserId ||
        !_canQuery) {
      return;
    }

    var changed = false;
    if (succeeded) {
      final byMessageId = <String, ReadReceiptInfo>{
        for (final info in infos ?? const <ReadReceiptInfo>[])
          if (info.messageId?.isNotEmpty == true) info.messageId!: info,
      };
      for (final key in batch) {
        if (!_hasObservers(key)) {
          _clearRetry(key, restartTimer: false);
          continue;
        }
        if ((_eventRevisions[key] ?? 0) != revisions[key]) {
          _clearRetry(key, restartTimer: false);
          continue;
        }
        final info = byMessageId[key.messageId];
        _putData(
          key,
          ChatReadReceiptDisplayData(
            readCount: info?.readCount ?? 0,
            unreadCount: info?.unreadCount ?? 0,
            totalCount: info?.totalCount ?? 0,
            isAuthoritative: true,
          ),
        );
        _clearRetry(key, restartTimer: false);
        changed = true;
      }
    } else {
      _scheduleRetries(
        batch.where(
          (key) =>
              _hasObservers(key) &&
              (_eventRevisions[key] ?? 0) == revisions[key] &&
              _displayCache[key]?.isAuthoritative != true,
        ),
      );
    }
    _restartRetryTimer();
    if (changed) notifyListeners();
  }

  void _scheduleRetries(Iterable<_ReadReceiptMessageKey> keys) {
    for (final key in keys) {
      if (_retryWaits.containsKey(key)) continue;
      final attempt = _retryAttempts[key] ?? 0;
      if (attempt >= _retryDelays.length) continue;
      _retryAttempts[key] = attempt + 1;
      _retryWaits[key] = _retryDelays[attempt];
    }
  }

  void _restartRetryTimer() {
    if (_disposed || _drainingRetries || !_canQuery) return;
    if (_retryWaits.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    _retryTimer?.cancel();
    _retryTimerBatch
      ..clear()
      ..addAll(_retryWaits.keys);
    Duration? delay;
    for (final key in _retryTimerBatch) {
      final wait = _retryWaits[key] ?? Duration.zero;
      if (delay == null || wait.compareTo(delay) < 0) delay = wait;
    }
    final scheduledDelay = delay ?? Duration.zero;
    _retryTimer = Timer(scheduledDelay, () {
      _retryTimer = null;
      final due = <_ReadReceiptMessageKey>[];
      for (final key in _retryTimerBatch) {
        final wait = _retryWaits[key];
        if (wait == null) continue;
        if (wait.compareTo(scheduledDelay) <= 0) {
          _retryWaits.remove(key);
          due.add(key);
        } else {
          _retryWaits[key] = wait - scheduledDelay;
        }
      }
      _retryTimerBatch.clear();
      unawaited(_drainDueRetries(due));
    });
  }

  Future<void> _drainDueRetries(List<_ReadReceiptMessageKey> due) async {
    if (!_canQuery || _drainingRetries) return;
    _drainingRetries = true;
    try {
      due = due.where(_hasObservers).toList(growable: false);
      await _queryInBatches(due);
    } finally {
      _drainingRetries = false;
      _restartRetryTimer();
    }
  }

  Future<void> _queryInBatches(List<_ReadReceiptMessageKey> keys) async {
    var pending = <_ReadReceiptMessageKey>[];
    final messageIds = <String>{};
    for (final key in keys) {
      if (pending.length >= maxBatchSize || !messageIds.add(key.messageId)) {
        await _queryBatch(pending);
        pending = <_ReadReceiptMessageKey>[];
        messageIds
          ..clear()
          ..add(key.messageId);
      }
      pending.add(key);
    }
    await _queryBatch(pending);
  }

  void _replaceOwnerKeys(Object owner, Set<_ReadReceiptMessageKey> next) {
    final previous = _ownerKeys[owner] ?? const <_ReadReceiptMessageKey>{};
    for (final key in previous.difference(next)) {
      final owners = _keyOwners[key];
      owners?.remove(owner);
      if (owners?.isEmpty ?? false) {
        _keyOwners.remove(key);
        _clearRetry(key, restartTimer: false);
      }
    }
    for (final key in next.difference(previous)) {
      _keyOwners.putIfAbsent(key, () => <Object>{}).add(owner);
    }
    if (next.isEmpty) {
      _ownerKeys.remove(owner);
    } else {
      _ownerKeys[owner] = next;
    }
    _restartRetryTimer();
  }

  bool _hasObservers(_ReadReceiptMessageKey key) =>
      _keyOwners[key]?.isNotEmpty == true;

  void _clearRetry(_ReadReceiptMessageKey key, {required bool restartTimer}) {
    _retryAttempts.remove(key);
    _retryWaits.remove(key);
    _retryTimerBatch.remove(key);
    if (restartTimer) _restartRetryTimer();
  }

  void _putData(_ReadReceiptMessageKey key, ChatReadReceiptDisplayData data) {
    _displayCache.remove(key);
    _displayCache[key] = data;
    while (_displayCache.length > _maxCacheSize) {
      final evicted = _displayCache.keys.first;
      _displayCache.remove(evicted);
      if (!_querying.contains(evicted)) _eventRevisions.remove(evicted);
    }
  }

  void _invalidate({required bool clearCache, bool clearOwners = false}) {
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryWaits.clear();
    _retryTimerBatch.clear();
    _retryAttempts.clear();
    _drainingRetries = false;
    for (final timer in _operationTimers.values) {
      timer.cancel();
    }
    _operationTimers.clear();
    for (final operation in _pendingOperations.toList()) {
      if (!operation.isCompleted) operation.complete();
    }
    _pendingOperations.clear();
    _querying.clear();
    _eventRevisions.clear();
    if (clearCache) _displayCache.clear();
    if (clearOwners) {
      _ownerKeys.clear();
      _keyOwners.clear();
    }
    notifyListeners();
  }

  T? _safeRead<T>(T? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return null;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _retryTimer?.cancel();
    for (final timer in _operationTimers.values) {
      timer.cancel();
    }
    for (final operation in _pendingOperations.toList()) {
      if (!operation.isCompleted) operation.complete();
    }
    _operationTimers.clear();
    _pendingOperations.clear();
    _displayCache.clear();
    _ownerKeys.clear();
    _keyOwners.clear();
    _querying.clear();
    _eventRevisions.clear();
    _retryAttempts.clear();
    _retryWaits.clear();
    _retryTimerBatch.clear();
    super.dispose();
  }
}

@immutable
class _ReadReceiptMessageKey {
  final ChannelType channelType;
  final String channelId;
  final String? subChannelId;
  final String messageId;

  const _ReadReceiptMessageKey({
    required this.channelType,
    required this.channelId,
    required this.subChannelId,
    required this.messageId,
  });

  static _ReadReceiptMessageKey? fromMessage(Message message) {
    try {
      final type = message.channelType;
      final id = message.channelId;
      final messageId = message.messageId;
      if (type == null ||
          id == null ||
          id.isEmpty ||
          messageId == null ||
          messageId.isEmpty) {
        return null;
      }
      String? subChannelId;
      try {
        subChannelId = _normalize(message.subChannelId);
      } on NoSuchMethodError {
        subChannelId = null;
      }
      return _ReadReceiptMessageKey(
        channelType: type,
        channelId: id,
        subChannelId: subChannelId,
        messageId: messageId,
      );
    } on NoSuchMethodError {
      return null;
    }
  }

  static _ReadReceiptMessageKey? fromIdentifier(
    ChannelIdentifier identifier,
    String? messageId,
  ) {
    final id = messageId?.trim();
    if (id == null || id.isEmpty || identifier.channelId.isEmpty) return null;
    return _ReadReceiptMessageKey(
      channelType: identifier.channelType,
      channelId: identifier.channelId,
      subChannelId: _normalize(identifier.subChannelId),
      messageId: id,
    );
  }

  MessageIdentifier toIdentifier() => MessageIdentifier(
    channelType: channelType,
    channelId: channelId,
    subChannelId: subChannelId,
    messageId: messageId,
  );

  static String? _normalize(String? value) =>
      value == null || value.isEmpty ? null : value;

  @override
  bool operator ==(Object other) =>
      other is _ReadReceiptMessageKey &&
      other.channelType == channelType &&
      other.channelId == channelId &&
      other.subChannelId == subChannelId &&
      other.messageId == messageId;

  @override
  int get hashCode =>
      Object.hash(channelType, channelId, subChannelId, messageId);
}
