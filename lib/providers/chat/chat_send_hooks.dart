part of '../chat_provider.dart';

extension _ChatProviderSendHooks on ChatProvider {
  void _markOutgoingStatusSending(
    Message message, {
    Message? original,
    SentStatus fallbackStatus = SentStatus.sending,
  }) {
    final sentStatus = _sentStatusOf(message);
    final resolvedStatus = sentStatus == SentStatus.failed
        ? SentStatus.failed
        : sentStatus == SentStatus.canceled
        ? SentStatus.canceled
        : sentStatus ?? fallbackStatus;
    _setOutgoingStatusOverride(message, resolvedStatus, original: original);
  }

  void _syncOutgoingStatusAfterResult(
    Message message, {
    Message? original,
    NCError? error,
  }) {
    final sentStatus = _sentStatusOf(message);
    final sendFailed = !_isSuccess(error);
    if (sentStatus == null) {
      if (sendFailed) {
        _setOutgoingStatusOverride(
          message,
          SentStatus.failed,
          original: original,
        );
        return;
      }
      _clearOutgoingStatusOverride(message, original: original);
      return;
    }
    if (sendFailed) {
      final resolvedFailureStatus = sentStatus == SentStatus.canceled
          ? SentStatus.canceled
          : SentStatus.failed;
      _setOutgoingStatusOverride(
        message,
        resolvedFailureStatus,
        original: original,
      );
      return;
    }
    if (sentStatus == SentStatus.sending ||
        sentStatus == SentStatus.failed ||
        sentStatus == SentStatus.canceled) {
      _setOutgoingStatusOverride(message, SentStatus.sent, original: original);
      return;
    }
    _clearOutgoingStatusOverride(message, original: original);
  }

  Future<bool> _shouldSend(MessageParams params) async {
    return _shouldSendForChannel(channel, params);
  }

  Future<bool> _shouldSendForChannel(
    BaseChannel targetChannel,
    MessageParams params,
  ) async {
    final interceptor = _callbacks.onBeforeSendMessage;
    if (interceptor == null) {
      return true;
    }
    return await interceptor(targetChannel, params);
  }

  void _notifyAfterSend(
    MessageParams params,
    Message? message,
    NCError? error,
  ) {
    _notifyAfterSendForChannel(channel, params, message, error);
  }

  void _notifyAfterSendForChannel(
    BaseChannel targetChannel,
    MessageParams params,
    Message? message,
    NCError? error,
  ) {
    final interceptor = _callbacks.onAfterSendMessage;
    if (interceptor == null) {
      return;
    }
    Future.sync(() => interceptor(targetChannel, params, message, error));
  }

  NCError? _errorFromCode(int? code) {
    return code == null || code == 0 ? null : NCError(code: code);
  }

  void _handleSendResult(MessageParams params, int? code, Message? message) {
    final error = _errorFromCode(code);
    if (message != null) {
      if (_directionOf(message) == MessageDirection.send &&
          _isLocallyDeletedSendingMessage(message)) {
        engineProvider.removeFailedMessage(message);
        _notifyAfterSend(params, message, error);
        return;
      }
      _syncOutgoingStatusAfterResult(message, error: error);
      _upsertMessage(message);
    }
    _trackFailedMessage(message, error);
    _notifyAfterSend(params, message, error);
  }

  void _trackFailedMessage(Message? message, NCError? error) {
    if (message == null) {
      return;
    }
    if (_isSuccess(error)) {
      engineProvider.removeFailedMessage(message);
    } else {
      engineProvider.addFailedMessage(message);
    }
  }
}
