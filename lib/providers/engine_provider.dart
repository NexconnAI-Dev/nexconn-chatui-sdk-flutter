import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;

import '../utils/message_content_util.dart';
import 'read_receipt_repository.dart';

/// Receives messages after EngineProvider accepts SDK events.
typedef NexconnAsyncMessageReceivedListener =
    FutureOr<void> Function(Message message);

/// Decides whether a received message should show a local notification.
typedef NexconnLocalNotificationFilter = bool Function(Message message);

/// Returns the server-to-local clock delta in milliseconds.
typedef NexconnServerTimeDeltaResolver = FutureOr<int> Function();

/// Returns application-level settings reported by the SDK.
typedef NexconnAppSettingsResolver = FutureOr<AppSettings?> Function();

const Duration _serverTimeDeltaResolverTimeout = Duration(seconds: 5);
const Duration _appSettingsResolverTimeout = Duration(seconds: 15);

/// Initializes NCEngine, manages connection state, and bridges global SDK events into ChatUI.
class EngineProvider with ChangeNotifier {
  static const _connectionHandlerKey = 'ai_nexconn_chatui_connection';
  static const _messageHandlerKey = 'ai_nexconn_chatui_message';
  static const _channelHandlerKey = 'ai_nexconn_chatui_channel';
  static const _channelRefreshThrottleDuration = Duration(milliseconds: 300);

  /// Emits the latest SDK connection status.
  final ValueNotifier<ConnectionStatus> connectionStatusNotifier =
      ValueNotifier<ConnectionStatus>(ConnectionStatus.unknown);

  /// Emits newly received messages accepted by the current session.
  final ValueNotifier<Message?> receivedMessageNotifier =
      ValueNotifier<Message?>(null);

  /// Emits messages that should update channel list previews.
  final ValueNotifier<Message?> channelMessageUpsertedNotifier =
      ValueNotifier<Message?>(null);

  /// Emits deleted messages that open chat pages should remove.
  final ValueNotifier<List<Message>?> deletedMessagesNotifier =
      ValueNotifier<List<Message>?>(null);

  /// Emits messages changed by message-edit synchronization.
  final ValueNotifier<List<Message>?> modifiedMessagesNotifier =
      ValueNotifier<List<Message>?>(null);

  /// Emits when offline message-edit synchronization has completed.
  final ValueNotifier<int> modifiedMessageSyncCompletedNotifier =
      ValueNotifier<int>(0);

  /// Emits V5 read-receipt responses for outgoing messages.
  final ValueNotifier<List<MessageReadReceiptResponse>?>
  messageReceiptResponsesNotifier =
      ValueNotifier<List<MessageReadReceiptResponse>?>(null);

  /// Emits the server-reported read-receipt protocol capability.
  final ValueNotifier<ReadReceiptVersion?> readReceiptVersionNotifier =
      ValueNotifier<ReadReceiptVersion?>(null);

  /// Increments whenever the active engine session is replaced or invalidated.
  final ValueNotifier<int> sessionGenerationNotifier = ValueNotifier<int>(0);

  /// Emits typing status changes from the SDK.
  final ValueNotifier<TypingStatusChangedEvent?> typingStatusNotifier =
      ValueNotifier<TypingStatusChangedEvent?>(null);

  /// Emits channel pinned-state sync events.
  final ValueNotifier<ChannelPinnedSyncEvent?> channelPinnedSyncNotifier =
      ValueNotifier<ChannelPinnedSyncEvent?>(null);

  /// Emits channel notification-level sync events.
  final ValueNotifier<ChannelNoDisturbLevelSyncEvent?>
  channelNoDisturbLevelSyncNotifier =
      ValueNotifier<ChannelNoDisturbLevelSyncEvent?>(null);

  /// Emits channel unread-state sync events.
  final ValueNotifier<ChannelUnreadStatusSyncEvent?>
  channelUnreadStatusSyncNotifier =
      ValueNotifier<ChannelUnreadStatusSyncEvent?>(null);

  /// Increments when channel lists should refresh.
  final ValueNotifier<int> channelRefreshNotifier = ValueNotifier<int>(0);
  final Set<NexconnAsyncMessageReceivedListener> _messageReceivedListeners =
      <NexconnAsyncMessageReceivedListener>{};
  final Set<NexconnLocalNotificationFilter> _localNotificationFilters =
      <NexconnLocalNotificationFilter>{};
  final NexconnServerTimeDeltaResolver _serverTimeDeltaResolver;
  final NexconnAppSettingsResolver _appSettingsResolver;
  late final NexconnReadReceiptV5Repository readReceiptRepository;
  final Map<String, Message> _failedMessages = <String, Message>{};

  String _currentUserId = '';
  bool _acceptingEngineEvents = false;
  bool _disposed = false;
  int _connectionGeneration = 0;
  int _sessionGeneration = 0;
  bool _destroyEngineBeforeNextInitialize = false;
  int _totalUnreadCount = 0;
  bool _enableLocalNotification = false;
  bool _localNotificationReady = false;
  int? _serverTimeDelta;
  int? _messageModifiableMinutes;
  FlutterLocalNotificationsPlugin? _localNotifications;
  Timer? _channelRefreshThrottleTimer;
  Future<void>? _appSettingsFuture;
  int? _appSettingsFutureGeneration;
  String? _appSettingsFutureUserId;

  /// Current connected user id.
  String get currentUserId => _currentUserId;

  /// Identity of the current engine session for guarding asynchronous work.
  int get sessionGeneration => _sessionGeneration;

  /// Total unread count tracked by ChatUI.
  int get totalUnreadCount => _totalUnreadCount;

  /// Latest SDK connection status.
  ConnectionStatus get connectionStatus => connectionStatusNotifier.value;

  /// Whether local notifications are enabled.
  bool get enableLocalNotification => _enableLocalNotification;

  /// Server-to-local clock delta in milliseconds.
  int? get serverTimeDelta => _serverTimeDelta;

  /// Server-reported read-receipt protocol capability, when available.
  ReadReceiptVersion? get readReceiptVersion =>
      readReceiptVersionNotifier.value;

  /// Waits briefly for the initial app-settings response before a message send.
  Future<bool> waitForReadReceiptV5(ChannelType channelType) async {
    if (channelType != ChannelType.direct && channelType != ChannelType.group) {
      return false;
    }
    if (readReceiptVersion == null) {
      try {
        await refreshAppSettings().timeout(const Duration(seconds: 1));
      } catch (_) {
        return false;
      }
    }
    return readReceiptVersion == ReadReceiptVersion.version5;
  }

  /// Server-reported message edit window in minutes.
  int? get messageModifiableMinutes => _messageModifiableMinutes;

  /// Waits for the server time and message-edit window required to validate
  /// persisted edit drafts without treating a pending refresh as unsupported.
  Future<bool> waitForMessageEditSettings() async {
    if ((_messageModifiableMinutes ?? 0) <= 0 || _serverTimeDelta == null) {
      try {
        await refreshAppSettings();
      } catch (_) {
        return false;
      }
    }
    return (_messageModifiableMinutes ?? 0) > 0 && _serverTimeDelta != null;
  }

  /// Current server-adjusted timestamp in milliseconds.
  int get serverNowMilliseconds =>
      DateTime.now().millisecondsSinceEpoch - (_serverTimeDelta ?? 0);

  /// Current server-adjusted DateTime.
  DateTime get serverNow =>
      DateTime.fromMillisecondsSinceEpoch(serverNowMilliseconds);

  @visibleForTesting
  int get failedMessageCount => _failedMessages.length;

  set enableLocalNotification(bool value) {
    if (_enableLocalNotification == value) {
      return;
    }
    _enableLocalNotification = value;
    notifyListeners();
  }

  bool get _canAcceptEngineEvents => _acceptingEngineEvents;

  @visibleForTesting
  bool get isAcceptingEngineEvents => _canAcceptEngineEvents;

  @visibleForTesting
  void updateReadReceiptVersionForTesting(ReadReceiptVersion? version) {
    readReceiptVersionNotifier.value = version;
  }

  @visibleForTesting
  void resetSessionStateForTesting() {
    _advanceConnectionGeneration();
    _acceptingEngineEvents = false;
    _clearSessionState(clearCurrentUser: true, resetConnectionStatus: true);
    notifyListeners();
  }

  @visibleForTesting
  void updateEngineEventsAcceptedForTesting(bool value) {
    if (_acceptingEngineEvents == value) {
      return;
    }
    _acceptingEngineEvents = value;
    notifyListeners();
  }

  EngineProvider({
    String currentUserId = '',
    NexconnServerTimeDeltaResolver? serverTimeDeltaResolver,
    NexconnAppSettingsResolver? appSettingsResolver,
    NexconnReadReceiptInfoQuery? readReceiptInfoQuery,
  }) : _serverTimeDeltaResolver =
           serverTimeDeltaResolver ?? NCEngine.getServerTimeDelta,
       _appSettingsResolver =
           appSettingsResolver ??
           (() {
             if (!NCEngine.isInitialized) {
               throw StateError('NCEngine is not initialized');
             }
             return NCEngine.getAppSettings();
           }),
       _currentUserId = currentUserId,
       _acceptingEngineEvents = currentUserId.isNotEmpty {
    readReceiptRepository = NexconnReadReceiptV5Repository(
      currentUserId: currentUserId,
      connectionStatus: connectionStatus,
      version: readReceiptVersion,
      query: readReceiptInfoQuery,
    );
    connectionStatusNotifier.addListener(_syncReadReceiptConnection);
    readReceiptVersionNotifier.addListener(_syncReadReceiptCapability);
    messageReceiptResponsesNotifier.addListener(_syncReadReceiptResponses);
    _bindHandlers();
  }

  void _syncReadReceiptConnection() {
    readReceiptRepository.updateConnectionStatus(connectionStatus);
  }

  void _syncReadReceiptCapability() {
    readReceiptRepository.updateCapability(readReceiptVersion);
  }

  void _syncReadReceiptResponses() {
    readReceiptRepository.handleResponses(
      messageReceiptResponsesNotifier.value,
    );
  }

  /// Initializes NCEngine and binds ChatUI event handlers.
  Future<void> initialize(InitParams params) async {
    if (_destroyEngineBeforeNextInitialize && NCEngine.isInitialized) {
      await NCEngine.destroy();
    }
    _destroyEngineBeforeNextInitialize = false;
    await NCEngine.initialize(params);
    _bindHandlers();
  }

  /// Connects NCEngine and starts accepting session events on success.
  Future<int> connect(
    ConnectParams params, {
    OperationHandler<String>? handler,
  }) async {
    final generation = _advanceConnectionGeneration();
    _clearSessionState(clearCurrentUser: true);
    _acceptingEngineEvents = false;
    notifyListeners();
    NCEngine.engine.setModuleName("nexconnchatuiflutter", "26.2.9");
    final code = await NCEngine.connect(params, (userId, error) {
      if (generation != _connectionGeneration) {
        return;
      }
      final errorCode = error?.code ?? 0;
      final isConnected = errorCode == 0 || errorCode == 34001;
      if (isConnected) {
        if (userId != null && userId.isNotEmpty) {
          if (_currentUserId != userId) {
            _currentUserId = userId;
            readReceiptRepository.updateAccount(userId);
            _advanceSessionGeneration();
          }
        }
        _acceptingEngineEvents = true;
        notifyListeners();
      } else {
        _acceptingEngineEvents = false;
      }
      handler?.call(userId, error);
      if (isConnected) {
        unawaited(refreshAppSettings());
      }
    });
    if (generation == _connectionGeneration) {
      final isConnectAccepted = code == 0 || code == 34001;
      if (isConnectAccepted && !_acceptingEngineEvents) {
        _acceptingEngineEvents = true;
        notifyListeners();
      } else if (!isConnectAccepted) {
        _acceptingEngineEvents = false;
      }
    }
    return code;
  }

  /// Disconnects NCEngine and clears ChatUI session state.
  Future<int> disconnect({bool disablePush = false}) {
    _advanceConnectionGeneration();
    _acceptingEngineEvents = false;
    _destroyEngineBeforeNextInitialize = true;
    _clearSessionState(clearCurrentUser: true, resetConnectionStatus: true);
    notifyListeners();
    return NCEngine.disconnect(disablePush: disablePush);
  }

  /// Refreshes connection status from NCEngine.
  Future<void> refreshConnectionStatus() async {
    try {
      final status = await NCEngine.getConnectionStatus();
      connectionStatusNotifier.value = status;
      notifyListeners();
    } catch (_) {
      // Keep the previous status when the native engine is not ready yet.
    }
  }

  /// Decreases the tracked total unread count by [count].
  void reduceTotalUnreadCount(int count) {
    if (count <= 0) {
      return;
    }
    updateTotalUnreadCount(
      _totalUnreadCount > count ? _totalUnreadCount - count : 0,
    );
  }

  /// Updates the current user id when the host app manages connection itself.
  void updateCurrentUserId(String userId) {
    final acceptingEngineEvents = userId.isNotEmpty;
    if (_currentUserId == userId &&
        _acceptingEngineEvents == acceptingEngineEvents) {
      return;
    }
    if (_currentUserId != userId) {
      _advanceSessionGeneration();
      _invalidateAppSettings();
    }
    _currentUserId = userId;
    readReceiptRepository.updateAccount(userId);
    _acceptingEngineEvents = acceptingEngineEvents;
    notifyListeners();
  }

  /// Replaces the tracked total unread count.
  void updateTotalUnreadCount(int count) {
    if (_totalUnreadCount == count) {
      return;
    }
    _totalUnreadCount = count;
    notifyListeners();
  }

  /// Publishes a received message to ChatUI listeners.
  void notifyMessageReceived(
    Message message, {
    bool refreshChannel = true,
    bool showNotification = true,
    bool throttleChannelRefresh = false,
  }) {
    receivedMessageNotifier.value = message;
    if (showNotification) {
      unawaited(showLocalNotification(message));
    }
    for (final listener in List<NexconnAsyncMessageReceivedListener>.of(
      _messageReceivedListeners,
    )) {
      Future.sync(() => listener(message));
    }
    if (refreshChannel) {
      if (throttleChannelRefresh) {
        _scheduleThrottledChannelRefresh();
      } else {
        notifyChannelNeedsRefresh();
      }
    }
    notifyListeners();
  }

  /// Publishes a message that should refresh channel previews.
  void notifyChannelMessageUpserted(Message message) {
    channelMessageUpsertedNotifier.value = message;
    notifyChannelNeedsRefresh();
    notifyListeners();
  }

  /// Tracks a message whose send failed locally.
  void addFailedMessage(Message message) {
    _failedMessages[_failedMessageKey(message)] = message;
    notifyChannelMessageUpserted(message);
    notifyListeners();
  }

  /// Removes a message from the local failed-message set.
  void removeFailedMessage(Message message) {
    _failedMessages.remove(_failedMessageKey(message));
    notifyChannelNeedsRefresh();
    notifyListeners();
  }

  /// Returns whether [message] is tracked as failed locally.
  bool isFailedMessage(Message message) {
    return _failedMessages.containsKey(_failedMessageKey(message));
  }

  /// Clears all locally tracked failed messages.
  void clearFailedMessages() {
    if (_failedMessages.isEmpty) {
      return;
    }
    _failedMessages.clear();
    notifyListeners();
  }

  Message? failedMessageForChannel(
    ChannelType channelType,
    String channelId, {
    String? subChannelId,
  }) {
    Message? latest;
    var latestTime = -1;
    final normalizedSubChannelId = _normalizeSubChannelId(subChannelId);
    for (final message in _failedMessages.values) {
      if (message.channelType != channelType ||
          message.channelId != channelId) {
        continue;
      }
      if (_normalizeSubChannelId(_subChannelIdOf(message)) !=
          normalizedSubChannelId) {
        continue;
      }
      final time = _messageTimeOf(message) ?? -1;
      if (latest == null || time >= latestTime) {
        latest = message;
        latestTime = time;
      }
    }
    return latest;
  }

  /// Adds a listener for accepted received messages.
  void addAsyncMessageReceivedListener(
    NexconnAsyncMessageReceivedListener listener,
  ) {
    _messageReceivedListeners.add(listener);
  }

  /// Removes a received-message listener.
  void removeAsyncMessageReceivedListener(
    NexconnAsyncMessageReceivedListener listener,
  ) {
    _messageReceivedListeners.remove(listener);
  }

  /// Adds a filter that can suppress local notifications.
  void addLocalNotificationFilter(NexconnLocalNotificationFilter filter) {
    _localNotificationFilters.add(filter);
  }

  /// Removes a local notification filter.
  void removeLocalNotificationFilter(NexconnLocalNotificationFilter filter) {
    _localNotificationFilters.remove(filter);
  }

  /// Initializes local notification support for received messages.
  Future<void> setupLocalNotification({bool enable = true}) async {
    _enableLocalNotification = enable;
    if (!enable) {
      _localNotificationReady = false;
      notifyListeners();
      return;
    }
    final plugin = _localNotifications ??= FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    try {
      await plugin.initialize(initializationSettings);
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _localNotificationReady = true;
    } catch (_) {
      _localNotificationReady = false;
    }
    notifyListeners();
  }

  /// Shows a local notification for [message] when filters allow it.
  Future<void> showLocalNotification(
    Message message, {
    String? title,
    String? body,
  }) async {
    if (!_enableLocalNotification || !_localNotificationReady) {
      return;
    }
    final plugin = _localNotifications;
    if (plugin == null) {
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'nexconn_chat_messages',
        'Messages',
        channelDescription: 'Nexconn Chat message notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    try {
      await plugin.show(
        (_messageIdOf(message) ??
                _clientIdOf(message)?.toString() ??
                message.hashCode.toString())
            .hashCode,
        title ?? _senderUserIdOf(message) ?? 'Nexconn Chat',
        body ?? messageSummary(message),
        details,
      );
    } catch (_) {
      // Local notification delivery is best effort across host app setups.
    }
  }

  /// Publishes deleted-message events to open chat pages.
  void notifyMessagesDeleted(List<Message>? messages) {
    deletedMessagesNotifier.value = messages == null
        ? null
        : List<Message>.unmodifiable(List<Message>.of(messages));
    notifyChannelNeedsRefresh();
    notifyListeners();
  }

  /// Requests channel lists to refresh.
  void notifyChannelNeedsRefresh() {
    channelRefreshNotifier.value = channelRefreshNotifier.value + 1;
    notifyListeners();
  }

  /// Publishes channel pinned-state sync events.
  void notifyChannelPinnedSync(ChannelPinnedSyncEvent event) {
    channelPinnedSyncNotifier.value = event;
    notifyChannelNeedsRefresh();
  }

  /// Publishes channel notification-level sync events.
  void notifyChannelNoDisturbLevelSync(ChannelNoDisturbLevelSyncEvent event) {
    channelNoDisturbLevelSyncNotifier.value = event;
    notifyChannelNeedsRefresh();
  }

  /// Publishes channel unread-state sync events.
  void notifyChannelUnreadStatusSync(ChannelUnreadStatusSyncEvent event) {
    channelUnreadStatusSyncNotifier.value = event;
    notifyChannelNeedsRefresh();
  }

  /// Refreshes app-wide settings such as server time delta.
  Future<void> refreshAppSettings() {
    final generation = _connectionGeneration;
    final userId = _currentUserId;
    final inFlight = _appSettingsFuture;
    if (inFlight != null &&
        _appSettingsFutureGeneration == generation &&
        _appSettingsFutureUserId == userId) {
      return inFlight;
    }
    late final Future<void> future;
    future = _refreshAppSettings(generation, userId).whenComplete(() {
      if (identical(_appSettingsFuture, future)) {
        _appSettingsFuture = null;
        _appSettingsFutureGeneration = null;
        _appSettingsFutureUserId = null;
      }
    });
    _appSettingsFuture = future;
    _appSettingsFutureGeneration = generation;
    _appSettingsFutureUserId = userId;
    return future;
  }

  Future<void> _refreshAppSettings(int generation, String userId) {
    return Future.wait<void>([
      _refreshServerTimeDelta(generation, userId),
      _refreshServerAppSettings(generation, userId),
    ]);
  }

  Future<void> _refreshServerTimeDelta(int generation, String userId) async {
    try {
      final value = await Future<int>.value(
        _serverTimeDeltaResolver(),
      ).timeout(_serverTimeDeltaResolverTimeout);
      if (!_isAppSettingsRefreshCurrent(generation, userId) ||
          _serverTimeDelta == value) {
        return;
      }
      _serverTimeDelta = value;
      notifyListeners();
    } catch (_) {
      // Keep the previous delta when the SDK cannot resolve it before deadline.
    }
  }

  Future<void> _refreshServerAppSettings(int generation, String userId) async {
    try {
      final settings = await Future<AppSettings?>.value(
        _appSettingsResolver(),
      ).timeout(_appSettingsResolverTimeout);
      if (!_isAppSettingsRefreshCurrent(generation, userId)) return;
      final version = settings?.readReceiptVersion;
      final minutes = settings?.messageModifiableMinutes;
      if (readReceiptVersionNotifier.value == version &&
          _messageModifiableMinutes == minutes) {
        return;
      }
      readReceiptVersionNotifier.value = version;
      _messageModifiableMinutes = minutes;
      notifyListeners();
    } catch (_) {
      // Settings are supplementary; retain the last successful capability.
    }
  }

  bool _isAppSettingsRefreshCurrent(int generation, String userId) {
    return !_disposed &&
        generation == _connectionGeneration &&
        userId == _currentUserId;
  }

  @visibleForTesting
  MessageHandler createMessageHandler({bool gateEngineEvents = false}) {
    return MessageHandler(
      onMessageReceived: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        _notifyEngineMessageReceived(event);
      },
      onMessageDeleted: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyMessagesDeleted(event.messages);
      },
      onMessagesModified: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) return;
        modifiedMessagesNotifier.value = event.messages;
        notifyChannelNeedsRefresh();
        notifyListeners();
      },
      onModifiedMessageSyncCompleted: (_) {
        if (gateEngineEvents && !_canAcceptEngineEvents) return;
        modifiedMessageSyncCompletedNotifier.value++;
        notifyChannelNeedsRefresh();
        notifyListeners();
      },
      onOfflineMessageSyncCompleted: (_) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyChannelNeedsRefresh();
      },
      onMessageReceiptResponse: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        messageReceiptResponsesNotifier.value = event.responses;
        notifyChannelNeedsRefresh();
        notifyListeners();
      },
      onMessageMetadataUpdated: (_) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyChannelNeedsRefresh();
      },
      onMessageMetadataDeleted: (_) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyChannelNeedsRefresh();
      },
    );
  }

  @visibleForTesting
  ChannelHandler createChannelHandler({bool gateEngineEvents = false}) {
    return ChannelHandler(
      onChannelPinnedSync: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyChannelPinnedSync(event);
      },
      onChannelNoDisturbLevelSync: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyChannelNoDisturbLevelSync(event);
      },
      onChannelUnreadStatusSync: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        notifyChannelUnreadStatusSync(event);
      },
      onRemoteChannelsSyncCompleted: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        if (event.error == null || event.error?.code == 0) {
          notifyChannelNeedsRefresh();
        }
      },
      onTypingStatusChanged: (event) {
        if (gateEngineEvents && !_canAcceptEngineEvents) {
          return;
        }
        typingStatusNotifier.value = event;
        notifyListeners();
      },
    );
  }

  void _bindHandlers() {
    NCEngine.removeConnectionStatusHandler(_connectionHandlerKey);
    NCEngine.addConnectionStatusHandler(_connectionHandlerKey, (event) {
      connectionStatusNotifier.value = event.status;
      notifyListeners();
    });

    NCEngine.removeMessageHandler(_messageHandlerKey);
    NCEngine.addMessageHandler(
      _messageHandlerKey,
      createMessageHandler(gateEngineEvents: true),
    );

    NCEngine.removeChannelHandler(_channelHandlerKey);
    NCEngine.addChannelHandler(
      _channelHandlerKey,
      createChannelHandler(gateEngineEvents: true),
    );
  }

  void _clearSessionState({
    required bool clearCurrentUser,
    bool resetConnectionStatus = false,
  }) {
    _channelRefreshThrottleTimer?.cancel();
    _channelRefreshThrottleTimer = null;
    if (clearCurrentUser) {
      _currentUserId = '';
      readReceiptRepository.updateAccount('');
      _failedMessages.clear();
    }
    _totalUnreadCount = 0;
    receivedMessageNotifier.value = null;
    channelMessageUpsertedNotifier.value = null;
    deletedMessagesNotifier.value = null;
    modifiedMessagesNotifier.value = null;
    messageReceiptResponsesNotifier.value = null;
    modifiedMessageSyncCompletedNotifier.value = 0;
    _invalidateAppSettings();
    typingStatusNotifier.value = null;
    channelPinnedSyncNotifier.value = null;
    channelNoDisturbLevelSyncNotifier.value = null;
    channelUnreadStatusSyncNotifier.value = null;
    if (resetConnectionStatus) {
      connectionStatusNotifier.value = ConnectionStatus.unconnected;
    }
  }

  void _invalidateAppSettings() {
    _appSettingsFuture = null;
    _appSettingsFutureGeneration = null;
    _appSettingsFutureUserId = null;
    _serverTimeDelta = null;
    _messageModifiableMinutes = null;
    readReceiptVersionNotifier.value = null;
  }

  int _advanceConnectionGeneration() {
    final generation = ++_connectionGeneration;
    _advanceSessionGeneration();
    return generation;
  }

  void _advanceSessionGeneration() {
    sessionGenerationNotifier.value = ++_sessionGeneration;
  }

  void _notifyEngineMessageReceived(MessageReceivedEvent event) {
    final isOfflineMessage = event.offline == true;
    final isOfflinePackage = isOfflineMessage && event.hasPackage == true;
    notifyMessageReceived(
      event.message,
      showNotification:
          !isOfflineMessage && !_shouldSuppressLocalNotification(event.message),
      throttleChannelRefresh: isOfflinePackage,
    );
  }

  bool _shouldSuppressLocalNotification(Message message) {
    final senderUserId = _senderUserIdOf(message)?.trim();
    if (_currentUserId.isNotEmpty &&
        senderUserId != null &&
        senderUserId.isNotEmpty &&
        senderUserId == _currentUserId) {
      return true;
    }
    for (final filter in _localNotificationFilters) {
      try {
        if (filter(message)) {
          return true;
        }
      } catch (_) {
        // Ignore filter failures so message delivery is not interrupted.
      }
    }
    return false;
  }

  void _scheduleThrottledChannelRefresh() {
    if (_channelRefreshThrottleTimer != null) {
      return;
    }
    _channelRefreshThrottleTimer = Timer(_channelRefreshThrottleDuration, () {
      _channelRefreshThrottleTimer = null;
      notifyChannelNeedsRefresh();
    });
  }

  String _failedMessageKey(Message message) {
    final messageId = _messageIdOf(message);
    if (messageId != null && messageId.isNotEmpty) {
      return 'uid:$messageId';
    }
    final clientId = _clientIdOf(message);
    if (clientId != null) {
      return 'client:$clientId';
    }
    final channelType = _channelTypeOf(message);
    final channelId = _channelIdOf(message);
    final messageType = _messageTypeOf(message);
    final sentTime = _sentTimeOf(message);
    final senderUserId = _senderUserIdOf(message);
    return '${channelType?.name}:$channelId:'
        '${_subChannelIdOf(message)}:${messageType?.name}:'
        '$sentTime:$senderUserId';
  }

  int? _messageTimeOf(Message message) =>
      _sentTimeOf(message) ?? _receivedTimeOf(message);

  String? _messageIdOf(Message message) {
    try {
      return message.messageId;
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _clientIdOf(Message message) {
    try {
      return message.clientId;
    } on NoSuchMethodError {
      return null;
    }
  }

  ChannelType? _channelTypeOf(Message message) {
    try {
      return message.channelType;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _channelIdOf(Message message) {
    try {
      return message.channelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  MessageType? _messageTypeOf(Message message) {
    try {
      return message.messageType;
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _sentTimeOf(Message message) {
    try {
      return message.sentTime;
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _receivedTimeOf(Message message) {
    try {
      return message.receivedTime;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _senderUserIdOf(Message message) {
    try {
      return message.senderUserId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _subChannelIdOf(Message message) {
    try {
      return message.subChannelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _normalizeSubChannelId(String? subChannelId) {
    return subChannelId == null || subChannelId.isEmpty ? null : subChannelId;
  }

  @override
  void dispose() {
    _disposed = true;
    _advanceConnectionGeneration();
    _appSettingsFuture = null;
    _appSettingsFutureGeneration = null;
    _appSettingsFutureUserId = null;
    NCEngine.removeConnectionStatusHandler(_connectionHandlerKey);
    NCEngine.removeMessageHandler(_messageHandlerKey);
    NCEngine.removeChannelHandler(_channelHandlerKey);
    connectionStatusNotifier.removeListener(_syncReadReceiptConnection);
    readReceiptVersionNotifier.removeListener(_syncReadReceiptCapability);
    messageReceiptResponsesNotifier.removeListener(_syncReadReceiptResponses);
    readReceiptRepository.dispose();
    connectionStatusNotifier.dispose();
    receivedMessageNotifier.dispose();
    channelMessageUpsertedNotifier.dispose();
    deletedMessagesNotifier.dispose();
    modifiedMessagesNotifier.dispose();
    modifiedMessageSyncCompletedNotifier.dispose();
    messageReceiptResponsesNotifier.dispose();
    readReceiptVersionNotifier.dispose();
    sessionGenerationNotifier.dispose();
    typingStatusNotifier.dispose();
    channelPinnedSyncNotifier.dispose();
    channelNoDisturbLevelSyncNotifier.dispose();
    channelUnreadStatusSyncNotifier.dispose();
    channelRefreshNotifier.dispose();
    _channelRefreshThrottleTimer?.cancel();
    _messageReceivedListeners.clear();
    _localNotificationFilters.clear();
    super.dispose();
  }
}
