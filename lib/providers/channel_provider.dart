import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/widgets.dart';

import '../utils/constants.dart';
import 'engine_provider.dart';
import 'read_receipt_repository.dart';

/// Builds a custom widget for a BaseChannel.
typedef ChannelWidgetBuilder = Widget Function(BaseChannel channel);

/// Allows apps to adjust loaded channel data before display.
typedef ChannelListDataProcessor =
    List<BaseChannel> Function(List<BaseChannel> channels);

/// Handles taps on a channel list item.
typedef ChannelListItemOnTap =
    void Function(BaseChannel channel, int index, BuildContext context);

/// Online presence state displayed for direct channels.
enum ChannelOnlineStatus { online, offline, unknown }

/// Loads and mutates the channel list through Nexconn channel APIs.
class ChannelProvider with ChangeNotifier {
  static const int defaultPageSize = defaultChannelPageSize;
  static const _userHandlerPrefix = 'ai_nexconn_chatui_channel_presence';
  static const _emptyChannelReloadDelay = Duration(milliseconds: 800);
  static const _maxEmptyChannelReloadAttempts = 5;

  /// Global engine state used for connection and channel refresh events.
  final EngineProvider engineProvider;

  /// Channel types requested from the SDK query.
  final List<ChannelType> channelTypes;

  /// SDK query page size.
  final int pageSize;

  /// Optional post-processor for loaded channels.
  final ChannelListDataProcessor? channelListDataProcessor;

  /// Scroll controller used by the built-in channel list.
  final ScrollController scrollController = ScrollController();

  ChannelsQuery? _query;
  List<BaseChannel> _channels = [];
  bool _isFetching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _disposed = false;
  int _requestVersion = 0;
  DateTime? _suppressReloadUntil;
  NCError? _lastError;
  Timer? _emptyChannelReloadTimer;
  Timer? _suppressedReloadTimer;
  int _emptyChannelReloadAttempts = 0;
  bool _hasPendingSuppressedReload = false;
  late final bool _usesSdkChannelQuery;
  ConnectionStatus _lastConnectionStatus = ConnectionStatus.unknown;
  final Map<String, ChannelOnlineStatus> _directChannelOnlineStatuses = {};
  final Set<String> _subscribedDirectChannelIds = {};
  final List<BaseChannel> _selectedChannelStack = <BaseChannel>[];
  double? _channelListScrollOffset;
  bool _needsChannelListScrollRestore = false;
  int _activeChannelListViews = 0;
  late final String _userHandlerKey;

  ChannelProvider({
    required this.engineProvider,
    List<ChannelType>? channelTypes,
    this.pageSize = defaultPageSize,
    this.channelListDataProcessor,
    List<BaseChannel>? initialChannels,
  }) : channelTypes =
           channelTypes ??
           const [
             ChannelType.direct,
             ChannelType.group,
             ChannelType.system,
             ChannelType.open,
             ChannelType.community,
           ] {
    _userHandlerKey = '$_userHandlerPrefix#$hashCode';
    _usesSdkChannelQuery = initialChannels == null;
    _lastConnectionStatus = engineProvider.connectionStatus;
    _channels = _processChannels(initialChannels ?? <BaseChannel>[]);
    _hasMore = initialChannels == null;
    engineProvider.channelRefreshNotifier.addListener(
      _handleChannelRefreshRequested,
    );
    engineProvider.channelMessageUpsertedNotifier.addListener(
      _handleChannelMessageUpserted,
    );
    engineProvider.connectionStatusNotifier.addListener(
      _handleConnectionStatusChanged,
    );
    engineProvider.readReceiptVersionNotifier.addListener(
      _handleReadReceiptCapabilityChanged,
    );
    engineProvider.readReceiptRepository.addListener(
      _handleReadReceiptDataChanged,
    );
    engineProvider.addLocalNotificationFilter(_shouldSuppressLocalNotification);
    NCEngine.addUserHandler(
      _userHandlerKey,
      UserHandler(onSubscriptionChanged: _handleSubscriptionChanged),
    );
    unawaited(engineProvider.refreshConnectionStatus());
    unawaited(engineProvider.refreshAppSettings());
    scheduleMicrotask(() {
      unawaited(_syncDirectChannelOnlineStatuses());
      unawaited(_syncChannelReadReceipts());
    });
  }

  /// Loaded channels ready for display.
  List<BaseChannel> get channels => List.unmodifiable(_channels);

  /// Whether the first channel page is loading.
  bool get isFetching => _isFetching;

  /// Whether more channels are loading.
  bool get isLoadingMore => _isLoadingMore;

  /// Whether more channels can be loaded.
  bool get hasMore => _hasMore;

  /// Last channel loading or mutation error.
  NCError? get lastError => _lastError;

  /// Current connection status from EngineProvider.
  ConnectionStatus get connectionStatus => engineProvider.connectionStatus;

  /// Stack of channels currently opened from the channel list.
  List<BaseChannel> get selectedChannelStack =>
      List<BaseChannel>.unmodifiable(_selectedChannelStack);

  /// Last opened channel from [selectedChannelStack].
  BaseChannel? get currentSelectedChannel =>
      _selectedChannelStack.isEmpty ? null : _selectedChannelStack.last;

  /// Last remembered channel list scroll offset.
  double? get channelListScrollOffset => _channelListScrollOffset;

  /// Whether ChannelPage should restore the remembered scroll offset.
  bool get needsChannelListScrollRestore => _needsChannelListScrollRestore;

  /// Returns online status for a direct channel.
  ChannelOnlineStatus onlineStatusOf(BaseChannel channel) {
    if (channel.channelType != ChannelType.direct) {
      return ChannelOnlineStatus.unknown;
    }
    return _directChannelOnlineStatuses[channel.channelId] ??
        ChannelOnlineStatus.unknown;
  }

  /// Returns shared V5 receipt state for an eligible direct-channel preview.
  ChatReadReceiptDisplayData? readReceiptDataFor(BaseChannel channel) {
    if (!_isChannelReadReceiptCandidate(channel)) return null;
    return engineProvider.readReceiptRepository.dataForMessage(
      channel.latestMessage!,
    );
  }

  /// Reloads channels from the first page.
  Future<void> reload() => _reload(resetEmptyRetryAttempts: true);

  Future<void> _reload({required bool resetEmptyRetryAttempts}) async {
    if (_disposed) {
      return;
    }
    _emptyChannelReloadTimer?.cancel();
    _emptyChannelReloadTimer = null;
    if (resetEmptyRetryAttempts) {
      _emptyChannelReloadAttempts = 0;
    }
    final version = ++_requestVersion;
    _query = ChannelsQuery(
      ChannelsQueryParams(channelTypes: channelTypes, pageSize: pageSize),
    );
    _hasMore = true;
    _isLoadingMore = false;
    await _loadMore(version, reset: true);
  }

  /// Pins [channel] through the SDK and refreshes the list on success.
  Future<NCError?> pinChannel(
    BaseChannel channel, {
    bool updateOperationTime = true,
  }) async {
    final actionError = await _runChannelMutation(
      (handler) => channel.pin(
        PinParams(updateOperationTime: updateOperationTime),
        handler,
      ),
    );
    if (_isSuccess(actionError)) {
      await reload();
    }
    return actionError;
  }

  /// Unpins [channel] through the SDK.
  Future<NCError?> unpinChannel(BaseChannel channel) async {
    final actionError = await _runChannelMutation(channel.unpin);
    if (_isSuccess(actionError)) {
      await reload();
    }
    return actionError;
  }

  /// Deletes [channel] through the SDK and refreshes the list on success.
  Future<NCError?> deleteChannel(BaseChannel channel) async {
    final actionError = await _runChannelMutation(channel.delete);
    if (_isSuccess(actionError)) {
      await reload();
    }
    return actionError;
  }

  /// Sets [channel] notification level to blocked.
  Future<NCError?> muteChannel(BaseChannel channel) async {
    final actionError = await _runChannelMutation(
      (handler) =>
          channel.setNoDisturbLevel(ChannelNoDisturbLevel.blocked, handler),
    );
    if (_isSuccess(actionError)) {
      await reload();
    }
    return actionError;
  }

  /// Clears [channel] notification blocking.
  Future<NCError?> unmuteChannel(BaseChannel channel) async {
    final actionError = await _runChannelMutation(
      (handler) =>
          channel.setNoDisturbLevel(ChannelNoDisturbLevel.none, handler),
    );
    if (_isSuccess(actionError)) {
      await reload();
    }
    return actionError;
  }

  /// Loads the next channel page when available.
  Future<void> loadMore() async {
    await _loadMore(_requestVersion);
  }

  /// Marks a channel list view as attached.
  void attachChannelListView() {
    _activeChannelListViews += 1;
  }

  /// Marks a channel list view as detached.
  void detachChannelListView() {
    if (_activeChannelListViews <= 0) {
      return;
    }
    _activeChannelListViews -= 1;
  }

  /// Stores the current or provided channel list scroll offset.
  void rememberChannelListScrollOffset([double? offset]) {
    final currentOffset =
        offset ??
        (scrollController.hasClients ? scrollController.offset : null);
    if (currentOffset == null) {
      return;
    }
    _channelListScrollOffset = currentOffset;
  }

  /// Requests scroll restoration after returning to ChannelPage.
  void requestChannelListScrollRestore([double? offset]) {
    rememberChannelListScrollOffset(offset);
    if (_channelListScrollOffset != null) {
      _needsChannelListScrollRestore = true;
    }
  }

  /// Marks channel list scroll restoration as complete.
  void markChannelListScrollRestoreComplete() {
    _needsChannelListScrollRestore = false;
  }

  /// Adds [channel] to the selected channel stack.
  void pushSelectedChannel(BaseChannel channel) {
    _selectedChannelStack.add(channel);
    _safeNotifyListeners();
  }

  /// Removes and returns the last selected channel.
  BaseChannel? popSelectedChannel() {
    if (_selectedChannelStack.isEmpty) {
      return null;
    }
    final channel = _selectedChannelStack.removeLast();
    _safeNotifyListeners();
    return channel;
  }

  /// Clears selected channels and their local unread state.
  void clearSelectedChannels() {
    if (_selectedChannelStack.isEmpty) {
      return;
    }
    _selectedChannelStack.clear();
    _safeNotifyListeners();
  }

  Future<void> _loadMore(int version, {bool reset = false}) async {
    if (_disposed) {
      return;
    }
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    _isFetching = _channels.isEmpty;
    _isLoadingMore = true;
    _lastError = null;
    _safeNotifyListeners();

    _query ??= ChannelsQuery(
      ChannelsQueryParams(channelTypes: channelTypes, pageSize: pageSize),
    );

    await _query!.loadNextPage((page, error) {
      if (_disposed || version != _requestVersion) {
        return;
      }
      _isFetching = false;
      _isLoadingMore = false;
      _lastError = error;
      final data = page?.data ?? const <BaseChannel>[];
      _hasMore = data.length >= pageSize;
      if (error == null) {
        _channels = _processChannels(
          _mergeFailedLatestMessages(reset ? data : [..._channels, ...data]),
        );
        _updateTotalUnreadCount();
        _syncDirectChannelOnlineStatuses();
        unawaited(_syncChannelReadReceipts());
      }
      _handleChannelLoadSettled(reset: reset, error: error);
      _safeNotifyListeners();
    });
  }

  /// Replaces the loaded channel list, mainly for host-managed data sources.
  void replaceChannels(List<BaseChannel> channels) {
    _channels = _processChannels(
      _mergeFailedLatestMessages(List<BaseChannel>.of(channels)),
    );
    _hasMore = false;
    _lastError = null;
    _updateTotalUnreadCount();
    _syncDirectChannelOnlineStatuses();
    unawaited(_syncChannelReadReceipts());
    _safeNotifyListeners();
  }

  List<BaseChannel> _processChannels(List<BaseChannel> channels) {
    final processor = channelListDataProcessor;
    if (processor == null) {
      final nextChannels = List<BaseChannel>.of(channels);
      nextChannels.sort(_compareChannels);
      return nextChannels;
    }
    return List<BaseChannel>.of(
      processor(List<BaseChannel>.unmodifiable(channels)),
    );
  }

  int _compareChannels(BaseChannel a, BaseChannel b) {
    final pinnedCompare = _comparePinned(b, a);
    if (pinnedCompare != 0) {
      return pinnedCompare;
    }
    return _channelSortTimeOf(b).compareTo(_channelSortTimeOf(a));
  }

  int _comparePinned(BaseChannel a, BaseChannel b) {
    final aPinned = a.isPinned == true ? 1 : 0;
    final bPinned = b.isPinned == true ? 1 : 0;
    return aPinned.compareTo(bPinned);
  }

  int _channelSortTimeOf(BaseChannel channel) {
    return channel.latestMessage?.sentTime ?? channel.operationTime ?? 0;
  }

  Future<NCError?> _runChannelMutation(
    Future<int> Function(ErrorHandler handler) mutate,
  ) async {
    final completer = Completer<NCError?>();
    try {
      await mutate((error) {
        if (!completer.isCompleted) {
          completer.complete(error);
        }
      });
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(NCError(message: error.toString()));
      }
    }
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => NCError(message: 'Request timed out. Please try again.'),
    );
  }

  bool _isSuccess(NCError? error) {
    return error == null || error.code == 0;
  }

  void _updateTotalUnreadCount() {
    engineProvider.updateTotalUnreadCount(
      _channels.fold<int>(
        0,
        (sum, channel) => sum + (channel.unreadCount ?? 0),
      ),
    );
  }

  void _handleConnectionStatusChanged() {
    final previousStatus = _lastConnectionStatus;
    final currentStatus = connectionStatus;
    _lastConnectionStatus = currentStatus;
    if (_shouldReloadAfterConnectionChange(previousStatus, currentStatus)) {
      unawaited(reload());
      return;
    }
    if (currentStatus == ConnectionStatus.connected) {
      unawaited(_syncChannelReadReceipts());
    }
    _safeNotifyListeners();
  }

  void _handleReadReceiptCapabilityChanged() {
    if (_disposed) return;
    if (engineProvider.readReceiptRepository.isEnabledFor(ChannelType.direct) ||
        engineProvider.readReceiptRepository.isEnabledFor(ChannelType.group)) {
      unawaited(_syncChannelReadReceipts());
    } else {
      engineProvider.readReceiptRepository.releaseOwner(this);
    }
    _safeNotifyListeners();
  }

  void _handleReadReceiptDataChanged() => _safeNotifyListeners();

  bool _shouldReloadAfterConnectionChange(
    ConnectionStatus previousStatus,
    ConnectionStatus currentStatus,
  ) {
    return _usesSdkChannelQuery &&
        !_disposed &&
        !_isReloadSuppressed &&
        !_isLoadingMore &&
        _channels.isEmpty &&
        currentStatus == ConnectionStatus.connected &&
        previousStatus != ConnectionStatus.connected;
  }

  void _handleChannelLoadSettled({
    required bool reset,
    required NCError? error,
  }) {
    if (!_usesSdkChannelQuery) {
      return;
    }
    if (_channels.isNotEmpty) {
      _emptyChannelReloadTimer?.cancel();
      _emptyChannelReloadTimer = null;
      _emptyChannelReloadAttempts = 0;
      return;
    }
    if (reset && error == null) {
      _scheduleEmptyChannelReload();
    }
  }

  void _scheduleEmptyChannelReload() {
    if (_disposed ||
        _isReloadSuppressed ||
        _isLoadingMore ||
        _channels.isNotEmpty ||
        !_canRetryEmptyChannelLoad(connectionStatus) ||
        _emptyChannelReloadAttempts >= _maxEmptyChannelReloadAttempts ||
        (_emptyChannelReloadTimer?.isActive ?? false)) {
      return;
    }
    _emptyChannelReloadTimer = Timer(_emptyChannelReloadDelay, () {
      _emptyChannelReloadTimer = null;
      if (_disposed ||
          _isReloadSuppressed ||
          _isLoadingMore ||
          _channels.isNotEmpty ||
          !_canRetryEmptyChannelLoad(connectionStatus)) {
        return;
      }
      _emptyChannelReloadAttempts += 1;
      unawaited(_reload(resetEmptyRetryAttempts: false));
    });
  }

  bool _canRetryEmptyChannelLoad(ConnectionStatus status) {
    return status == ConnectionStatus.connected ||
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.unknown;
  }

  void _handleChannelRefreshRequested() {
    _requestChannelReload();
  }

  void _handleChannelMessageUpserted() {
    final message = engineProvider.channelMessageUpsertedNotifier.value;
    if (message == null) {
      return;
    }
    if (engineProvider.isFailedMessage(message) &&
        _applyFailedMessageOverlay(message)) {
      if (_usesSdkChannelQuery) {
        _suppressReloadBriefly();
      }
    }
    unawaited(_syncChannelReadReceipts());
  }

  Future<void> _syncChannelReadReceipts() async {
    if (_disposed) return;
    final messages = _channels
        .where(_isChannelReadReceiptCandidate)
        .map((channel) => channel.latestMessage!)
        .toList(growable: false);
    await engineProvider.readReceiptRepository.replaceOwnerMessages(
      this,
      messages,
    );
  }

  bool _isChannelReadReceiptCandidate(BaseChannel channel) {
    if ((channel.channelType != ChannelType.direct &&
            channel.channelType != ChannelType.group) ||
        !_isEmpty(channel.draft) ||
        channel.editedMessageDraft != null) {
      return false;
    }
    final message = channel.latestMessage;
    if (message == null ||
        _safeMessageValue(() => message.direction) != MessageDirection.send ||
        _safeMessageValue(() => message.needReceipt) != true ||
        engineProvider.isFailedMessage(message)) {
      return false;
    }
    final status = _safeMessageValue(() => message.sentStatus);
    if (status != SentStatus.sent &&
        status != SentStatus.received &&
        status != SentStatus.read &&
        status != SentStatus.destroyed) {
      return false;
    }
    final messageId = _safeMessageValue(() => message.messageId);
    final messageType = _safeMessageValue(() => message.messageType);
    return messageId?.isNotEmpty == true &&
        messageType != null &&
        messageType != MessageType.unknown &&
        messageType != MessageType.command &&
        messageType != MessageType.commandNotification &&
        messageType != MessageType.groupNotification &&
        messageType != MessageType.informationNotification;
  }

  bool _isEmpty(String? value) => value == null || value.trim().isEmpty;

  T? _safeMessageValue<T>(T? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return null;
    }
  }

  void _requestChannelReload() {
    if (_disposed || !_usesSdkChannelQuery) {
      return;
    }
    if (_isReloadSuppressed) {
      _hasPendingSuppressedReload = true;
      _scheduleSuppressedReloadDrain();
      return;
    }
    unawaited(reload());
  }

  @visibleForTesting
  Future<BaseChannel?> fetchChannel(ChannelIdentifier identifier) async {
    final completer =
        Completer<({List<BaseChannel>? channels, NCError? error})>();
    try {
      await BaseChannel.getChannels([identifier], (channels, error) {
        if (!completer.isCompleted) {
          completer.complete((channels: channels, error: error));
        }
      });
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete((
          channels: null,
          error: NCError(message: error.toString()),
        ));
      }
    }
    final result = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => (
        channels: null,
        error: NCError(message: 'Request timed out. Please try again.'),
      ),
    );
    if (!_isSuccess(result.error)) {
      return null;
    }
    for (final channel in result.channels ?? const <BaseChannel>[]) {
      if (_matchesChannelIdentifier(channel, identifier)) {
        return channel;
      }
    }
    return null;
  }

  bool get _isReloadSuppressed {
    final deadline = _suppressReloadUntil;
    if (deadline == null) {
      return false;
    }
    if (DateTime.now().isAfter(deadline)) {
      _suppressReloadUntil = null;
      return false;
    }
    return true;
  }

  void _suppressReloadBriefly() {
    _suppressReloadUntil = DateTime.now().add(
      const Duration(milliseconds: 600),
    );
    _scheduleSuppressedReloadDrain();
  }

  void _scheduleSuppressedReloadDrain() {
    _suppressedReloadTimer?.cancel();
    final deadline = _suppressReloadUntil;
    if (deadline == null) {
      return;
    }
    final delay = deadline.difference(DateTime.now());
    _suppressedReloadTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _suppressedReloadTimer = null;
        _suppressReloadUntil = null;
        if (_disposed || !_hasPendingSuppressedReload) {
          return;
        }
        _hasPendingSuppressedReload = false;
        unawaited(reload());
      },
    );
  }

  bool _shouldSuppressLocalNotification(Message message) {
    if (_activeChannelListViews > 0) {
      return true;
    }
    final selectedChannel = currentSelectedChannel;
    if (selectedChannel != null && _matchesMessage(selectedChannel, message)) {
      return true;
    }
    final index = _channels.indexWhere(
      (channel) => _matchesMessage(channel, message),
    );
    if (index < 0) {
      return false;
    }
    return _channels[index].notificationLevel == ChannelNoDisturbLevel.blocked;
  }

  bool _matchesMessage(BaseChannel channel, Message message) {
    return channel.channelType == message.channelType &&
        channel.channelId == message.channelId &&
        _normalizedSubChannelId(channel.channelIdentifier.subChannelId) ==
            _normalizedSubChannelId(_subChannelIdOf(message));
  }

  String? _subChannelIdOf(Message message) {
    try {
      return message.subChannelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _normalizedSubChannelId(String? subChannelId) {
    return subChannelId == null || subChannelId.isEmpty ? null : subChannelId;
  }

  int? _messageTimeOf(Message message) =>
      message.sentTime ?? message.receivedTime;

  List<BaseChannel> _mergeFailedLatestMessages(List<BaseChannel> channels) {
    return channels.map(_mergeFailedLatestMessage).toList(growable: false);
  }

  bool _applyFailedMessageOverlay(Message message) {
    final index = _channels.indexWhere(
      (channel) => _matchesMessage(channel, message),
    );
    if (index < 0) {
      return false;
    }
    final merged = _mergeFailedLatestMessage(_channels[index]);
    if (identical(merged, _channels[index])) {
      return false;
    }
    final nextChannels = List<BaseChannel>.of(_channels);
    nextChannels[index] = merged;
    _channels = _processChannels(nextChannels);
    _safeNotifyListeners();
    return true;
  }

  BaseChannel _mergeFailedLatestMessage(BaseChannel channel) {
    final failedMessage = engineProvider.failedMessageForChannel(
      channel.channelType,
      channel.channelId,
      subChannelId: channel.channelIdentifier.subChannelId,
    );
    if (failedMessage == null) {
      return channel;
    }
    final failedTime = _messageTimeOf(failedMessage) ?? -1;
    final latestTime = channel.latestMessage != null
        ? (_messageTimeOf(channel.latestMessage!) ?? -1)
        : -1;
    final shouldOverlay =
        channel.latestMessage == null ||
        failedTime > latestTime ||
        _isSameMessageIdentity(channel.latestMessage!, failedMessage);
    if (!shouldOverlay) {
      return channel;
    }
    return _cloneChannel(
      channel,
      latestMessage: failedMessage,
      operationTime: failedTime >= 0
          ? ((channel.operationTime ?? 0) > failedTime
                ? channel.operationTime
                : failedTime)
          : channel.operationTime,
    );
  }

  bool _isSameMessageIdentity(Message a, Message b) {
    final aMessageId = a.messageId;
    final bMessageId = b.messageId;
    if (aMessageId != null &&
        aMessageId.isNotEmpty &&
        bMessageId != null &&
        bMessageId.isNotEmpty) {
      return aMessageId == bMessageId;
    }
    final aClientId = a.clientId;
    final bClientId = b.clientId;
    if (aClientId != null && bClientId != null) {
      return aClientId == bClientId;
    }
    return a.channelType == b.channelType &&
        a.channelId == b.channelId &&
        _normalizedSubChannelId(_subChannelIdOf(a)) ==
            _normalizedSubChannelId(_subChannelIdOf(b)) &&
        a.messageType == b.messageType &&
        _messageTimeOf(a) == _messageTimeOf(b) &&
        a.senderUserId == b.senderUserId;
  }

  BaseChannel _cloneChannel(
    BaseChannel channel, {
    int? unreadCount,
    int? mentionedCount,
    int? mentionedMeCount,
    Message? latestMessage,
    int? operationTime,
  }) {
    if (channel is DirectChannel) {
      return DirectChannel(
        channel.channelId,
        unreadCount: unreadCount ?? channel.unreadCount,
        mentionedCount: mentionedCount ?? channel.mentionedCount,
        mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
        isPinned: channel.isPinned,
        draft: channel.draft,
        editedMessageDraft: channel.editedMessageDraft,
        latestMessage: latestMessage ?? channel.latestMessage,
        notificationLevel: channel.notificationLevel,
        firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
        operationTime: operationTime ?? channel.operationTime,
        translateStrategy: channel.translateStrategy,
      );
    }
    if (channel is GroupChannel) {
      return GroupChannel(
        channel.channelId,
        unreadCount: unreadCount ?? channel.unreadCount,
        mentionedCount: mentionedCount ?? channel.mentionedCount,
        mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
        isPinned: channel.isPinned,
        draft: channel.draft,
        editedMessageDraft: channel.editedMessageDraft,
        latestMessage: latestMessage ?? channel.latestMessage,
        notificationLevel: channel.notificationLevel,
        firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
        operationTime: operationTime ?? channel.operationTime,
        translateStrategy: channel.translateStrategy,
      );
    }
    if (channel is SystemChannel) {
      return SystemChannel(
        channel.channelId,
        unreadCount: unreadCount ?? channel.unreadCount,
        mentionedCount: mentionedCount ?? channel.mentionedCount,
        mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
        isPinned: channel.isPinned,
        draft: channel.draft,
        editedMessageDraft: channel.editedMessageDraft,
        latestMessage: latestMessage ?? channel.latestMessage,
        notificationLevel: channel.notificationLevel,
        firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
        operationTime: operationTime ?? channel.operationTime,
        translateStrategy: channel.translateStrategy,
      );
    }
    if (channel is OpenChannel) {
      return OpenChannel(
        channel.channelId,
        unreadCount: unreadCount ?? channel.unreadCount,
        mentionedCount: mentionedCount ?? channel.mentionedCount,
        mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
        isPinned: channel.isPinned,
        draft: channel.draft,
        editedMessageDraft: channel.editedMessageDraft,
        latestMessage: latestMessage ?? channel.latestMessage,
        notificationLevel: channel.notificationLevel,
        firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
        operationTime: operationTime ?? channel.operationTime,
        translateStrategy: channel.translateStrategy,
      );
    }
    if (channel is CommunitySubChannel) {
      return CommunitySubChannel(
        channel.channelId,
        channel.subChannelId,
        unreadCount: unreadCount ?? channel.unreadCount,
        mentionedCount: mentionedCount ?? channel.mentionedCount,
        mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
        isPinned: channel.isPinned,
        draft: channel.draft,
        editedMessageDraft: channel.editedMessageDraft,
        latestMessage: latestMessage ?? channel.latestMessage,
        notificationLevel: channel.notificationLevel,
        firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
        operationTime: operationTime ?? channel.operationTime,
        translateStrategy: channel.translateStrategy,
      );
    }
    if (channel is CommunityChannel) {
      return CommunityChannel(
        channel.channelId,
        unreadCount: unreadCount ?? channel.unreadCount,
        mentionedCount: mentionedCount ?? channel.mentionedCount,
        mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
        isPinned: channel.isPinned,
        draft: channel.draft,
        editedMessageDraft: channel.editedMessageDraft,
        latestMessage: latestMessage ?? channel.latestMessage,
        notificationLevel: channel.notificationLevel,
        firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
        operationTime: operationTime ?? channel.operationTime,
        translateStrategy: channel.translateStrategy,
      );
    }
    return BaseChannel(
      channel.channelType,
      channel.channelId,
      unreadCount: unreadCount ?? channel.unreadCount,
      mentionedCount: mentionedCount ?? channel.mentionedCount,
      mentionedMeCount: mentionedMeCount ?? channel.mentionedMeCount,
      isPinned: channel.isPinned,
      draft: channel.draft,
      editedMessageDraft: channel.editedMessageDraft,
      latestMessage: latestMessage ?? channel.latestMessage,
      notificationLevel: channel.notificationLevel,
      firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
      operationTime: operationTime ?? channel.operationTime,
      translateStrategy: channel.translateStrategy,
    );
  }

  Future<void> _syncDirectChannelOnlineStatuses() async {
    final directChannelIds = _channels
        .where((channel) => channel.channelType == ChannelType.direct)
        .map((channel) => channel.channelId)
        .where((channelId) => channelId.isNotEmpty)
        .toSet();

    final removedIds = _subscribedDirectChannelIds.difference(directChannelIds);
    if (removedIds.isNotEmpty) {
      _subscribedDirectChannelIds.removeAll(removedIds);
      for (final userId in removedIds) {
        _directChannelOnlineStatuses.remove(userId);
      }
      try {
        await NCEngine.user.unsubscribeEvent(
          UnsubscribeEventParams(
            subscribeType: SubscribeType.onlineStatus,
            userIds: removedIds.toList(),
          ),
          (_, _) {},
        );
      } catch (_) {}
    }

    final newIds = directChannelIds.difference(_subscribedDirectChannelIds);
    if (newIds.isEmpty) {
      return;
    }
    _subscribedDirectChannelIds.addAll(newIds);
    try {
      await NCEngine.user.subscribeEvent(
        SubscribeEventParams(
          subscribeType: SubscribeType.onlineStatus,
          userIds: newIds.toList(),
        ),
        (_, _) {},
      );
      await NCEngine.user.getSubscribeEvent(
        GetSubscribeEventParams(
          subscribeType: SubscribeType.onlineStatus,
          userIds: newIds.toList(),
        ),
        (events, error) {
          if (error == null) {
            _applySubscriptionEvents(events);
          }
        },
      );
    } catch (_) {}
  }

  void _handleSubscriptionChanged(SubscriptionChangedEvent event) {
    _applySubscriptionEvents(event.events);
  }

  void _applySubscriptionEvents(List<SubscribeStatusInfo>? events) {
    var changed = false;
    for (final event in events ?? const <SubscribeStatusInfo>[]) {
      if (event.subscribeType != SubscribeType.onlineStatus) {
        continue;
      }
      final userId = event.userId;
      if (userId == null || userId.isEmpty) {
        continue;
      }
      final status = _toOnlineStatus(event);
      if (_directChannelOnlineStatuses[userId] != status) {
        _directChannelOnlineStatuses[userId] = status;
        changed = true;
      }
    }
    if (changed) {
      _safeNotifyListeners();
    }
  }

  ChannelOnlineStatus _toOnlineStatus(SubscribeStatusInfo event) {
    final hasOnlinePlatform = event.details.any(
      (detail) => (detail.eventValue ?? 0) > 0,
    );
    if (hasOnlinePlatform) {
      return ChannelOnlineStatus.online;
    }
    return event.details.isEmpty
        ? ChannelOnlineStatus.unknown
        : ChannelOnlineStatus.offline;
  }

  bool _matchesChannelIdentifier(
    BaseChannel channel,
    ChannelIdentifier identifier,
  ) {
    return channel.channelType == identifier.channelType &&
        channel.channelId == identifier.channelId &&
        _normalizedSubChannelId(channel.channelIdentifier.subChannelId) ==
            _normalizedSubChannelId(identifier.subChannelId);
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    NCEngine.removeUserHandler(_userHandlerKey);
    final subscribedIds = _subscribedDirectChannelIds.toList();
    _subscribedDirectChannelIds.clear();
    _directChannelOnlineStatuses.clear();
    _selectedChannelStack.clear();
    if (subscribedIds.isNotEmpty) {
      try {
        NCEngine.user.unsubscribeEvent(
          UnsubscribeEventParams(
            subscribeType: SubscribeType.onlineStatus,
            userIds: subscribedIds,
          ),
          (_, _) {},
        );
      } catch (_) {}
    }
    engineProvider.channelRefreshNotifier.removeListener(
      _handleChannelRefreshRequested,
    );
    engineProvider.channelMessageUpsertedNotifier.removeListener(
      _handleChannelMessageUpserted,
    );
    engineProvider.connectionStatusNotifier.removeListener(
      _handleConnectionStatusChanged,
    );
    engineProvider.readReceiptVersionNotifier.removeListener(
      _handleReadReceiptCapabilityChanged,
    );
    engineProvider.readReceiptRepository.removeListener(
      _handleReadReceiptDataChanged,
    );
    engineProvider.readReceiptRepository.releaseOwner(this);
    engineProvider.removeLocalNotificationFilter(
      _shouldSuppressLocalNotification,
    );
    _emptyChannelReloadTimer?.cancel();
    _suppressedReloadTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }
}
