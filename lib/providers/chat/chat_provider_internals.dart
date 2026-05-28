part of '../chat_provider.dart';

extension _ChatProviderProviderInternals on ChatProvider {
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
