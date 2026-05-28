part of '../chat_provider.dart';

extension _ChatProviderMessageLoading on ChatProvider {
  Future<void> _loadMoreMessages(int version, {bool reset = false}) async {
    if (_disposed) {
      return;
    }
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    _isLoading = _messages.isEmpty;
    _isLoadingMore = true;
    _lastError = null;
    _safeNotifyListeners();

    _query ??= MessagesQuery(
      MessagesQueryParams(
        channelIdentifier: channel.channelIdentifier,
        pageSize: _effectivePageSize,
        policy: _messageQueryPolicy,
      ),
    );

    final completer = Completer<void>();

    void completeLoad() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    try {
      await _query!.loadNextPage((page, error) {
        if (_disposed || version != _requestVersion) {
          completeLoad();
          return;
        }
        _isLoading = false;
        _isLoadingMore = false;
        _hasResolvedInitialLoad = true;
        _lastError = error;
        _purgeLegacyPlaceholderMessages();
        final data = (page?.data ?? const <Message>[])
            .where((message) => !_isLegacyPlaceholderMessage(message))
            .toList(growable: false);
        if (error == null) {
          _hasMore = _query?.hasMore ?? data.length >= _effectivePageSize;
          _syncLoadedMessagesDisplayState(data);
          _messages = reset
              ? data.reversed.toList()
              : [...data.reversed, ..._messages];
        }
        _safeNotifyListeners();
        completeLoad();
      });
    } catch (error) {
      if (!_disposed && version == _requestVersion) {
        _isLoading = false;
        _isLoadingMore = false;
        _hasResolvedInitialLoad = true;
        _lastError = error is NCError
            ? error
            : NCError(message: error.toString());
        _safeNotifyListeners();
      }
      completeLoad();
      rethrow;
    }
    return completer.future;
  }
}
