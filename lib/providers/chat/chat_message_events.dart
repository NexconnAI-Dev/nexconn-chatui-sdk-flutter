part of '../chat_provider.dart';

extension _ChatProviderMessageEvents on ChatProvider {
  void _onChannelMessageUpserted() {
    final message = engineProvider.channelMessageUpsertedNotifier.value;
    if (message == null || !_sameChannel(message)) {
      return;
    }
    if (_consumeSuppressedChannelUpsert(message)) {
      return;
    }
    if (_isRecallMessage(message)) {
      _replaceMessageWithRecall(message);
      return;
    }
    _upsertMessageFromEngine(message);
  }

  void _onMessageReceived() {
    final message = engineProvider.receivedMessageNotifier.value;
    if (message == null || !_sameChannel(message)) {
      return;
    }
    if (_isRecallMessage(message)) {
      _replaceMessageWithRecall(message);
      _scheduleClearUnreadCount();
      return;
    }
    _upsertMessage(message);
    _scheduleClearUnreadCount();
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
    final recalledMessages = sameChannelMessages
        .where(_isRecallMessage)
        .toList();
    final removedMessages = sameChannelMessages
        .where((message) => !_isRecallMessage(message))
        .toList();
    var changed = false;
    for (final recalledMessage in recalledMessages) {
      changed =
          _replaceMessageWithRecall(recalledMessage, notifyListeners: false) ||
          changed;
    }
    if (removedMessages.isNotEmpty) {
      changed =
          _removeMessages(removedMessages, notifyListeners: false) || changed;
    }
    if (changed) {
      _safeNotifyListeners();
    }
  }

  void _onConnectionStatusChanged() {
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
