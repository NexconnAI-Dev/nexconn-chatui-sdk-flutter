import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
// ignore: implementation_imports
import 'package:ai_nexconn_chat_plugin/src/enum/read_receipt_status.dart'
    as sdk_read_receipt;
// ignore: implementation_imports
import 'package:ai_nexconn_chat_plugin/src/model/message_read_receipt_user.dart'
    as sdk_read_receipt;
// ignore: implementation_imports
import 'package:ai_nexconn_chat_plugin/src/query/message_read_receipt_query.dart'
    as sdk_read_receipt;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rongcloud_im_wrapper_plugin/rongcloud_im_wrapper_plugin.dart';
import 'package:dio/dio.dart';

import 'engine_provider.dart';
part 'chat/chat_message_types.dart';
part 'chat/chat_read_receipt_types.dart';
part 'chat/chat_message_search_types.dart';
part 'chat/chat_message_operations.dart';
part 'chat/chat_message_loading.dart';
part 'chat/chat_forward_helpers.dart';
part 'chat/chat_combined_forward_helpers.dart';
part 'chat/chat_send_hooks.dart';
part 'chat/chat_message_events.dart';
part 'chat/chat_message_store.dart';
part 'chat/chat_message_identity.dart';
part 'chat/chat_provider_internals.dart';

const String _messageEditUnsupportedReason =
    'The Nexconn SDK does not expose a message editing API yet';
final RegExp _phonePattern = RegExp(r'(?<!\d)(?:\+?\d[\d\s-]{5,}\d)(?!\d)');
const Duration _deleteForAllWindow = Duration(minutes: 2);
const int _combinedForwardMessageLimit = 100;

class _ResendMessagePayload {
  final MessageParams params;
  final List<String>? directedUserIds;

  const _ResendMessagePayload({required this.params, this.directedUserIds});
}

/// Manages messages, selection, search, forwarding, delete-for-all, and sending for one BaseChannel.
class ChatProvider with ChangeNotifier {
  /// Global engine state used for connection status and SDK event bridging.
  final EngineProvider engineProvider;

  /// Channel whose messages are managed by this provider.
  BaseChannel channel;

  /// Message query page size used for initial and incremental loading.
  final int pageSize;

  /// Maximum number of selected messages allowed in multi-select mode.
  final int maxSelectedMessages;

  /// Scroll controller shared by the built-in message list.
  final ScrollController scrollController = ScrollController();
  final ChatMessageOperations _operations;
  final ChatMessageActionCallbacks _callbacks;

  MessagesQuery? _query;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasResolvedInitialLoad = false;
  bool _hasMore = true;
  bool _disposed = false;
  int _requestVersion = 0;
  NCError? _lastError;
  bool _multiSelectMode = false;
  final Set<String> _selectedMessageKeys = <String>{};
  bool _isSearching = false;
  List<Message> _searchResults = const [];
  ChatMessageSearchRequest? _lastSearchRequest;
  Message? _referenceMessage;
  int _unreadHistoryCount;
  int _unreadMentionCount;
  List<Message> _unreadMentionedMessages = const [];
  bool _isClearingUnread = false;
  bool _hasPendingClearUnread = false;
  int _clearedUnreadFromChannel = 0;
  Timer? _clearUnreadTimer;
  Future<void>? _initialMessagesLoadFuture;
  int? _suppressedUnreadSyncTimestamp;
  DateTime? _suppressUnreadSyncUntil;
  final Map<String, SentStatus> _outgoingStatusOverrides =
      <String, SentStatus>{};
  final Set<String> _locallyDeletedSendingMessageKeys = <String>{};
  final Set<String> _unavailableReferenceMessageKeys = <String>{};
  final Set<String> _suppressedChannelUpsertKeys = <String>{};
  final Map<String, Future<void>> _mediaDownloadFutures =
      <String, Future<void>>{};
  final Map<String, MediaMessage> _activeMediaDownloads =
      <String, MediaMessage>{};

  ChatProvider({
    required this.engineProvider,
    required this.channel,
    this.pageSize = 20,
    this.maxSelectedMessages = 100,
    ChatMessageOperations? operations,
    ChatMessageActionCallbacks callbacks = const ChatMessageActionCallbacks(),
    List<Message>? initialMessages,
  }) : _messages = initialMessages ?? <Message>[],
       _hasResolvedInitialLoad = initialMessages != null,
       _unreadHistoryCount = channel.unreadCount ?? 0,
       _unreadMentionCount = channel.mentionedMeCount ?? 0,
       _operations = operations ?? const _NexconnChatMessageOperations(),
       _callbacks = callbacks {
    engineProvider.receivedMessageNotifier.addListener(_onMessageReceived);
    engineProvider.channelMessageUpsertedNotifier.addListener(
      _onChannelMessageUpserted,
    );
    engineProvider.deletedMessagesNotifier.addListener(_onMessagesDeleted);
    engineProvider.connectionStatusNotifier.addListener(
      _onConnectionStatusChanged,
    );
    engineProvider.channelUnreadStatusSyncNotifier.addListener(
      _onChannelUnreadStatusSync,
    );
    _syncLoadedMessagesDisplayState(_messages);
    unawaited(engineProvider.refreshConnectionStatus());
    unawaited(engineProvider.refreshAppSettings());
  }

  /// Loaded messages ready for display, excluding internal placeholder entries.
  List<Message> get messages => List.unmodifiable(
    _messages.where((m) => !_isLegacyPlaceholderMessage(m)),
  );

  /// Whether the first page is currently loading.
  bool get isLoading => _isLoading;

  /// Whether older messages are currently loading.
  bool get isLoadingMore => _isLoadingMore;

  /// Whether initial loading has completed at least once.
  bool get hasResolvedInitialLoad => _hasResolvedInitialLoad;

  /// Whether more history can be loaded.
  bool get hasMore => _hasMore;

  /// Last SDK error produced by message loading.
  NCError? get lastError => _lastError;

  /// Whether selected-message mode is active.
  bool get multiSelectMode => _multiSelectMode;

  /// Whether a message search is in progress.
  bool get isSearching => _isSearching;

  /// Latest message search results.
  List<Message> get searchResults => List.unmodifiable(_searchResults);

  /// Last search request submitted to this provider.
  ChatMessageSearchRequest? get lastSearchRequest => _lastSearchRequest;

  /// Message editing is currently unavailable because the SDK has no edit API.
  bool get canEditMessage => false;

  /// User-facing reason explaining why message editing is unavailable.
  String get editMessageUnsupportedReason => _messageEditUnsupportedReason;

  /// Current connection status from EngineProvider.
  ConnectionStatus get connectionStatus => engineProvider.connectionStatus;

  /// Message currently referenced by the input area.
  Message? get referenceMessage => _referenceMessage;

  /// Whether the input area has a reference message.
  bool get hasReferenceMessage => _referenceMessage != null;

  /// Unread history count captured when the channel opened.
  int get unreadHistoryCount => _unreadHistoryCount;

  /// Number of unread mentioned messages for the current channel.
  int get unreadMentionCount => _unreadMentionedMessages.isNotEmpty
      ? _unreadMentionedMessages.length
      : _unreadMentionCount;

  /// Unread mentioned messages available for jump-to-mentioned UI.
  List<Message> get unreadMentionedMessages => List.unmodifiable(
    _unreadMentionedMessages.where((m) => !_isLegacyPlaceholderMessage(m)),
  );

  /// Messages selected for batch actions such as forwarding or deletion.
  List<Message> get selectedMessages => _messages
      .where(
        (m) =>
            !_isLegacyPlaceholderMessage(m) &&
            _selectedMessageKeys.contains(_keyOf(m)),
      )
      .toList();

  /// Returns whether a referenced message can no longer be resolved locally.
  bool isReferenceMessageUnavailable(Message? message) {
    if (message == null) {
      return false;
    }
    final keys = _identityKeysOf(message);
    if (keys.isEmpty) {
      return false;
    }
    return keys.any(_unavailableReferenceMessageKeys.contains);
  }

  /// Maximum number of messages supported by combined forwarding.
  static int get combinedForwardMessageLimit => _combinedForwardMessageLimit;

  /// Returns true when [count] reaches the combined-forwarding limit.
  static bool exceedsCombinedForwardMessageLimit(int count) {
    return count >= _combinedForwardMessageLimit;
  }

  /// Returns the send status that should be rendered for [message].
  SentStatus? sentStatusForDisplay(Message message) {
    for (final key in _identityKeysOf(message)) {
      final override = _outgoingStatusOverrides[key];
      if (override != null) {
        return override;
      }
    }
    return _sentStatusOf(message);
  }

  /// Extracts copyable text from supported message types.
  static String? extractCopyText(Message message) {
    if (message is TextMessage) return message.text?.trim();
    if (message is ReferenceMessage) return message.text?.trim();
    if (message is GroupNotificationMessage) {
      return message.message?.trim();
    }
    if (message is CommandNotificationMessage) {
      return message.data?.trim() ?? message.name?.trim();
    }
    if (message is CommandMessage) {
      return message.data?.trim() ?? message.name?.trim();
    }
    if (message is MediaMessage ||
        message is CombineMessage ||
        message is LocationMessage ||
        message is CustomMessage ||
        message is CustomMediaMessage) {
      return null;
    }
    return null;
  }

  /// Extracts the first phone number from a copyable message.
  static String? extractPhoneNumber(Message message) {
    final text = extractCopyText(message);
    if (text == null || text.isEmpty) return null;
    final match = _phonePattern.firstMatch(text);
    if (match == null) return null;
    return match.group(0)?.replaceAll(RegExp(r'[\s-]'), '');
  }

  /// Loads the first page of messages and clears channel unread state.
  Future<void> loadInitialMessages() async {
    if (_disposed) {
      return;
    }
    final existingLoad = _initialMessagesLoadFuture;
    if (existingLoad != null) {
      return existingLoad;
    }
    final loadFuture = _loadInitialMessages();
    _initialMessagesLoadFuture = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_initialMessagesLoadFuture, loadFuture)) {
        _initialMessagesLoadFuture = null;
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    final version = ++_requestVersion;
    _hasResolvedInitialLoad = false;
    _query = MessagesQuery(
      MessagesQueryParams(
        channelIdentifier: channel.channelIdentifier,
        pageSize: _effectivePageSize,
        policy: _messageQueryPolicy,
      ),
    );
    _hasMore = true;
    _isLoadingMore = false;
    await _loadMoreMessages(version, reset: true);
    if (_disposed || version != _requestVersion) {
      return;
    }
    await _refreshUnreadMentionedMessages();
    if (_disposed || version != _requestVersion) {
      return;
    }
    await clearUnreadCount();
  }

  MessageOperationPolicy get _messageQueryPolicy =>
      _isOfflineConnection(connectionStatus)
      ? MessageOperationPolicy.local
      : MessageOperationPolicy.localRemote;

  bool _isOfflineConnection(ConnectionStatus status) {
    return status == ConnectionStatus.networkUnavailable ||
        status == ConnectionStatus.unconnected ||
        status == ConnectionStatus.suspend ||
        status == ConnectionStatus.timeout;
  }

  /// Loads the next page of older messages when available.
  Future<void> loadMoreMessages() async {
    await _loadMoreMessages(_requestVersion);
  }

  /// Sends text, or a reference message when [referenceMessage] is provided.
  Future<void> sendText(
    String text, {
    Message? referenceMessage,
    List<String>? mentionUserIds,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final params = referenceMessage != null
        ? ReferenceMessageParams(
            referenceMessage: referenceMessage,
            text: trimmed,
            mentionedInfo: _mentionedInfo(mentionUserIds),
          )
        : TextMessageParams(
            text: trimmed,
            mentionedInfo: _mentionedInfo(mentionUserIds),
          );

    if (!await _shouldSend(params)) {
      return;
    }

    final code = await channel.sendMessage(
      SendMessageParams(messageParams: params),
      callback: SendMessageCallback(
        onMessageSaved: (message) {
          if (message != null) {
            _markOutgoingStatusSending(message);
            _upsertMessage(message);
          }
        },
        onMessageSent: (code, message) {
          _handleSendResult(params, code, message);
        },
      ),
    );
    if (code != 0) {
      _notifyAfterSend(params, null, NCError(code: code));
    }
  }

  /// Sends a media message params object through the current channel.
  ///
  /// This is the generic entry point for image, GIF, voice, short video, and
  /// file messages. For convenience, use the type-specific helpers below when
  /// the media type is already known.
  Future<void> sendMediaMessage(MessageParams params) async {
    if (!await _shouldSend(params)) {
      return;
    }

    final code = await channel.sendMediaMessage(
      SendMediaMessageParams(messageParams: params),
      handler: SendMediaMessageHandler(
        onMediaMessageSaved: (message) {
          if (message != null) {
            _markOutgoingStatusSending(message);
            _upsertMessage(message);
          }
        },
        onMediaMessageSending: (message, _) {
          if (message != null) {
            _markOutgoingStatusSending(message);
            _upsertMessage(message);
          }
        },
        onSendingMediaMessageCanceled: (message) {
          if (message != null) {
            _handleSendResult(params, -1, message);
            _safeNotifyListeners();
          }
        },
        onMediaMessageSent: (code, message) {
          _handleSendResult(params, code, message);
        },
      ),
    );
    if (code != 0) {
      _notifyAfterSend(params, null, NCError(code: code));
    }
  }

  /// Backward-compatible alias for [sendMediaMessage].
  @Deprecated('Use sendMediaMessage or the type-specific media helpers.')
  Future<void> sendMedia(MessageParams params) async {
    await sendMediaMessage(params);
  }

  /// Sends an image message from a local or remote file path.
  Future<void> sendImageMessage(
    String path, {
    List<String>? mentionUserIds,
    bool needReceipt = false,
  }) async {
    await sendMediaMessage(
      ImageMessageParams(
        path: path,
        mentionedInfo: _mentionedInfo(mentionUserIds),
        needReceipt: needReceipt,
      ),
    );
  }

  /// Sends a GIF message from a local or remote file path.
  Future<void> sendGifMessage(
    String path, {
    List<String>? mentionUserIds,
    bool needReceipt = false,
  }) async {
    await sendMediaMessage(
      GIFMessageParams(
        path: path,
        mentionedInfo: _mentionedInfo(mentionUserIds),
        needReceipt: needReceipt,
      ),
    );
  }

  /// Sends a voice message with a duration in seconds.
  Future<void> sendVoiceMessage(
    String path,
    int duration, {
    List<String>? mentionUserIds,
    bool needReceipt = false,
  }) async {
    final sendPath = await _voiceMessageSendPath(path);
    await sendMediaMessage(
      HDVoiceMessageParams(
        path: sendPath,
        duration: duration,
        mentionedInfo: _mentionedInfo(mentionUserIds),
        needReceipt: needReceipt,
      ),
    );
  }

  Future<String> _voiceMessageSendPath(String path) async {
    final file = _localFileFromPath(path);
    if (file == null || !await file.exists()) {
      return path;
    }
    final normalizedPath = file.path;
    if (normalizedPath.toLowerCase().endsWith('.m4a')) {
      return normalizedPath;
    }
    if (!await _isMpeg4Container(file)) {
      return path;
    }
    final m4aPath = _pathWithExtension(normalizedPath, '.m4a');
    if (m4aPath == normalizedPath) {
      return normalizedPath;
    }
    await file.copy(m4aPath);
    return m4aPath;
  }

  File? _localFileFromPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme.toLowerCase() == 'file') {
        return File.fromUri(uri);
      }
      return null;
    }
    return File(path);
  }

  Future<bool> _isMpeg4Container(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final header = await handle.read(12);
      return header.length >= 8 &&
          header[4] == 0x66 &&
          header[5] == 0x74 &&
          header[6] == 0x79 &&
          header[7] == 0x70;
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }

  String _pathWithExtension(String path, String extension) {
    final separator = Platform.pathSeparator;
    final separatorIndex = path.lastIndexOf(separator);
    final fileNameStart = separatorIndex < 0 ? 0 : separatorIndex + 1;
    final extensionIndex = path.lastIndexOf('.');
    if (extensionIndex >= fileNameStart) {
      return '${path.substring(0, extensionIndex)}$extension';
    }
    return '$path$extension';
  }

  /// Sends a short-video message with a duration in seconds.
  Future<void> sendShortVideoMessage(
    String path,
    int duration, {
    List<String>? mentionUserIds,
    bool needReceipt = false,
  }) async {
    await sendMediaMessage(
      ShortVideoMessageParams(
        path: path,
        duration: duration,
        mentionedInfo: _mentionedInfo(mentionUserIds),
        needReceipt: needReceipt,
      ),
    );
  }

  /// Sends a file message from a local or remote file path.
  Future<void> sendFileMessage(
    String path, {
    List<String>? mentionUserIds,
    bool needReceipt = false,
  }) async {
    await sendMediaMessage(
      FileMessageParams(
        path: path,
        mentionedInfo: _mentionedInfo(mentionUserIds),
        needReceipt: needReceipt,
      ),
    );
  }

  /// Sends a location message with optional title and thumbnail data.
  Future<void> sendLocationMessage({
    required double longitude,
    required double latitude,
    required String poiName,
    required String thumbnailPath,
    List<String>? mentionUserIds,
    bool needReceipt = false,
  }) async {
    final params = LocationMessageParams(
      longitude: longitude,
      latitude: latitude,
      poiName: poiName,
      thumbnailPath: thumbnailPath,
      mentionedInfo: _mentionedInfo(mentionUserIds),
      needReceipt: needReceipt,
    );
    if (!await _shouldSend(params)) {
      return;
    }
    final code = await channel.sendMessage(
      SendMessageParams(messageParams: params),
      callback: SendMessageCallback(
        onMessageSaved: (message) {
          if (message != null) {
            _markOutgoingStatusSending(message);
            _upsertMessage(message);
          }
        },
        onMessageSent: (code, message) {
          _handleSendResult(params, code, message);
        },
      ),
    );
    if (code != 0) {
      _notifyAfterSend(params, null, NCError(code: code));
    }
  }

  /// Inserts messages into the current channel through the SDK.
  Future<List<Message>> insertMessages(InsertMessagesParams params) async {
    try {
      final completer = Completer<List<Message>>();
      final code = await channel.insertMessages(params, (messages, error) {
        if (error != null && error.code != 0) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
          return;
        }
        if (!completer.isCompleted) {
          completer.complete(messages ?? const []);
        }
      });
      if (code != 0 && !completer.isCompleted) {
        throw NCError(code: code);
      }
      final inserted = await completer.future;
      _lastError = null;
      _upsertMessages(inserted);
      return inserted;
    } catch (error) {
      final converted = _toNCError(error);
      _lastError = converted;
      rethrow;
    } finally {
      _safeNotifyListeners();
    }
  }

  /// Forwards messages one by one to a target channel.
  Future<ChatForwardResult> forwardMessagesIndividually(
    BaseChannel targetChannel,
    List<Message> messages,
  ) async {
    var forwardedCount = 0;
    var skippedCount = 0;
    for (final message in messages) {
      if (message is CombineMessage &&
          _shouldForwardCombineMessageAsRaw(message)) {
        final params = _rawForwardCombineHookParams(message);
        if (params == null) {
          skippedCount++;
          continue;
        }
        if (!await _shouldSendForChannel(targetChannel, params)) {
          skippedCount++;
          continue;
        }
        await _sendForwardRawCombineMessage(targetChannel, message, params);
        forwardedCount++;
        continue;
      }
      final params = await _forwardMessageParams(message);
      if (params == null) {
        skippedCount++;
        continue;
      }
      if (!await _shouldSendForChannel(targetChannel, params)) {
        skippedCount++;
        continue;
      }
      await _sendForwardParams(targetChannel, params);
      forwardedCount++;
    }
    return ChatForwardResult(
      forwardedCount: forwardedCount,
      skippedCount: skippedCount,
    );
  }

  /// Sends one combined-forward message to a target channel.
  Future<ChatForwardResult> forwardMessagesAsCombined(
    BaseChannel targetChannel,
    List<Message> messages,
  ) async {
    if (messages.isEmpty) {
      return const ChatForwardResult();
    }
    if (exceedsCombinedForwardMessageLimit(messages.length)) {
      throw NCError(
        code: -1,
        message:
            'Combined forwarding supports fewer than '
            '$_combinedForwardMessageLimit messages.',
      );
    }
    if (messages.any(_isReferenceForwardMessage)) {
      throw NCError(
        code: -1,
        message: 'Reference messages cannot be forwarded as combined.',
      );
    }
    final skippedCount = messages
        .where((message) => _combinedForwardItems(message).isEmpty)
        .length;
    final items = messages
        .expand(_combinedForwardItems)
        .toList(growable: false);
    if (items.isEmpty) {
      return ChatForwardResult(skippedCount: messages.length);
    }
    final summaryList = items
        .map((item) => '${item.senderName}：${item.summary}')
        .where((summary) => summary.isNotEmpty)
        .toList(growable: false);
    final nameList = items
        .map((item) => item.senderName.trim())
        .toList(growable: false);
    final msgList = items.map((item) => item.info).toList(growable: false);
    final params = CombineMessageParams(
      sourceChannelType: channel.channelType,
      summaryList: summaryList,
      nameList: nameList,
      msgList: msgList,
    );
    if (!await _shouldSendForChannel(targetChannel, params)) {
      return ChatForwardResult(skippedCount: messages.length);
    }
    await _sendForwardParams(targetChannel, params);
    return ChatForwardResult(forwardedCount: 1, skippedCount: skippedCount);
  }

  /// Forwards messages using the requested [mode].
  Future<ChatForwardResult> forwardMessages(
    BaseChannel targetChannel,
    List<Message> messages, {
    ChatForwardMode mode = ChatForwardMode.individually,
  }) {
    return switch (mode) {
      ChatForwardMode.individually => forwardMessagesByDefault(
        targetChannel,
        messages,
      ),
      ChatForwardMode.combined => forwardMessagesAsCombined(
        targetChannel,
        messages,
      ),
    };
  }

  /// Forwards messages using the default individual mode.
  Future<ChatForwardResult> forwardMessagesByDefault(
    BaseChannel targetChannel,
    List<Message> messages,
  ) {
    return forwardMessagesIndividually(targetChannel, messages);
  }

  /// Enables or disables message multi-select mode.
  void setMultiSelectMode(bool enabled) {
    if (_multiSelectMode == enabled) {
      return;
    }
    _multiSelectMode = enabled;
    if (!enabled) {
      _selectedMessageKeys.clear();
    }
    _safeNotifyListeners();
  }

  /// Downloads the media payload for [message] when the SDK supports it.
  Future<void> downloadMediaMessage(
    MediaMessage message, {
    void Function(MediaMessage message)? onDownloaded,
    void Function(MediaMessage message, int progress)? onDownloading,
  }) async {
    final key = _keyOf(message);
    final existing = _mediaDownloadFutures[key];
    if (existing != null) {
      final activeMessage = _activeMediaDownloads[key] ?? message;
      await existing;
      final downloaded = activeMessage.localPath?.isNotEmpty == true
          ? activeMessage
          : message;
      if (downloaded.localPath?.isNotEmpty == true) {
        onDownloaded?.call(downloaded);
      }
      return;
    }
    late final Future<void> future;
    future =
        _downloadMediaMessage(
          message,
          onDownloaded: onDownloaded,
          onDownloading: onDownloading,
        ).whenComplete(() {
          if (identical(_mediaDownloadFutures[key], future)) {
            _mediaDownloadFutures.remove(key);
            _activeMediaDownloads.remove(key);
          }
        });
    _mediaDownloadFutures[key] = future;
    _activeMediaDownloads[key] = message;
    await future;
  }

  Future<void> _downloadMediaMessage(
    MediaMessage message, {
    void Function(MediaMessage message)? onDownloaded,
    void Function(MediaMessage message, int progress)? onDownloading,
  }) async {
    final completion = Completer<void>();
    final code = await message.downloadMedia(
      handler: DownloadMediaMessageHandler(
        onProgress: (downloading, progress) {
          if (downloading == null || progress == null) {
            return;
          }
          onDownloading?.call(downloading, progress);
        },
        onCanceled: (_) {
          if (completion.isCompleted) {
            return;
          }
          completion.completeError(
            NCError(code: -1, message: 'Media download canceled'),
          );
        },
        onComplete: (code, downloaded) {
          if (completion.isCompleted) {
            return;
          }
          if (code == 0 && downloaded != null) {
            message.localPath = downloaded.localPath;
            _upsertMessageFromEngine(downloaded);
            onDownloaded?.call(downloaded);
            completion.complete();
            return;
          }
          completion.completeError(NCError(code: code ?? -1));
        },
      ),
    );
    if (code != 0) {
      throw NCError(code: code);
    }
    await completion.future;
  }

  /// Cancels an ongoing media download for [message] when one exists.
  Future<NCError?> cancelMediaDownload(MediaMessage message) async {
    final key = _keyOf(message);
    final activeMessage = _activeMediaDownloads[key];
    if (activeMessage == null) {
      return null;
    }
    NCError? callbackError;
    try {
      final code = await activeMessage.cancelDownloadingMedia((_, error) {
        callbackError = error;
      });
      if (code != 0) {
        return NCError(code: code);
      }
      return callbackError;
    } catch (error) {
      return _toNCError(error);
    }
  }

  Future<NCError?> _cancelMediaDownloadBeforeMutation(Message message) async {
    if (message is! MediaMessage) {
      return null;
    }
    if (!_activeMediaDownloads.containsKey(_keyOf(message))) {
      return null;
    }
    return cancelMediaDownload(message);
  }

  /// Sends an existing combined-forward message.
  Future<void> sendCombineMessage(CombineMessage message) async {
    final msgList = _sanitizeCombineMessageInfos(
      message.msgList ?? const <CombineMessageInfo>[],
    );
    final jsonMsgKey = message.jsonMsgKey?.trim();
    final hasRemotePayloadKey = jsonMsgKey != null && jsonMsgKey.isNotEmpty;
    final summaryList = message.summaryList ?? const <String>[];
    final nameList = message.nameList ?? const <String>[];
    if ((msgList.isEmpty && !hasRemotePayloadKey) ||
        summaryList.isEmpty ||
        nameList.isEmpty) {
      return;
    }
    final params = CombineMessageParams(
      sourceChannelType: message.sourceChannelType ?? channel.channelType,
      summaryList: summaryList,
      nameList: nameList,
      msgList: msgList,
      needReceipt: message.needReceipt,
    );
    if (!await _shouldSendForChannel(channel, params)) {
      return;
    }
    await _sendForwardParams(channel, params);
  }

  Future<NCError?> resendMessage(Message message) async {
    try {
      final payload = _resendPayloadFromMessage(message);
      if (payload == null) {
        final error = NCError(
          code: 50101,
          message: 'This message type cannot be resent',
        );
        _lastError = error;
        _trackFailedMessage(message, error);
        _safeNotifyListeners();
        return error;
      }

      if (!await _shouldSend(payload.params)) {
        return null;
      }

      final deleteError = await _deleteLocalMessageBeforeResend(message);
      if (!_isSuccess(deleteError)) {
        _lastError = deleteError;
        _trackFailedMessage(message, deleteError);
        _safeNotifyListeners();
        return deleteError;
      }

      _removeMessages([message], notifyListeners: false);
      return _sendResentMessage(payload);
    } catch (error) {
      final converted = _toNCError(error);
      _lastError = converted;
      _syncOutgoingStatusAfterResult(message, error: converted);
      _trackFailedMessage(message, converted);
      _safeNotifyListeners();
      return converted;
    }
  }

  Future<NCError?> retryFailedMessage(Message message) async {
    _lastError = null;
    return resendMessage(message);
  }

  _ResendMessagePayload? _resendPayloadFromMessage(Message message) {
    final mentionedInfo = _mentionedInfoFromMessage(message);
    final needReceipt = _readMessageValue(() => message.needReceipt);
    final directedUserIds = _readMessageValue(() => message.directedUserIds);

    if (message is TextMessage) {
      return _ResendMessagePayload(
        params: TextMessageParams(
          text: _readMessageValue(() => message.text) ?? '',
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
        directedUserIds: directedUserIds,
      );
    }

    if (message is ReferenceMessage) {
      final referenceMessage = _readMessageValue(() => message.referenceMsg);
      if (referenceMessage == null) {
        return null;
      }
      return _ResendMessagePayload(
        params: ReferenceMessageParams(
          referenceMessage: referenceMessage,
          text: _readMessageValue(() => message.text) ?? '',
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
        directedUserIds: directedUserIds,
      );
    }

    if (message is LocationMessage) {
      final longitude = _readMessageValue(() => message.longitude);
      final latitude = _readMessageValue(() => message.latitude);
      final poiName = _readMessageValue(() => message.poiName);
      final thumbnailPath = _readMessageValue(() => message.thumbnailPath);
      if (longitude == null ||
          latitude == null ||
          poiName == null ||
          thumbnailPath == null ||
          thumbnailPath.isEmpty) {
        return null;
      }
      return _ResendMessagePayload(
        params: LocationMessageParams(
          longitude: longitude,
          latitude: latitude,
          poiName: poiName,
          thumbnailPath: thumbnailPath,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
        directedUserIds: directedUserIds,
      );
    }

    if (message is ImageMessage) {
      final path = _mediaLocalPathOf(message);
      if (path == null || path.isEmpty) {
        return null;
      }
      return _ResendMessagePayload(
        params: ImageMessageParams(
          path: path,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is GIFMessage) {
      final path = _mediaLocalPathOf(message);
      if (path == null || path.isEmpty) {
        return null;
      }
      return _ResendMessagePayload(
        params: GIFMessageParams(
          path: path,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is HDVoiceMessage) {
      final path = _mediaLocalPathOf(message);
      final duration = _readMessageValue(() => message.duration);
      if (path == null || path.isEmpty || duration == null) {
        return null;
      }
      return _ResendMessagePayload(
        params: HDVoiceMessageParams(
          path: path,
          duration: duration,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is ShortVideoMessage) {
      final path = _mediaLocalPathOf(message);
      final duration = _readMessageValue(() => message.duration);
      if (path == null || path.isEmpty || duration == null) {
        return null;
      }
      return _ResendMessagePayload(
        params: ShortVideoMessageParams(
          path: path,
          duration: duration,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is FileMessage) {
      final path = _mediaLocalPathOf(message);
      if (path == null || path.isEmpty) {
        return null;
      }
      return _ResendMessagePayload(
        params: FileMessageParams(
          path: path,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is CombineMessage) {
      final msgList = _sanitizeCombineMessageInfos(
        _readMessageValue(() => message.msgList) ??
            const <CombineMessageInfo>[],
      );
      final jsonMsgKey = _readMessageValue(() => message.jsonMsgKey)?.trim();
      final hasRemotePayloadKey = jsonMsgKey != null && jsonMsgKey.isNotEmpty;
      final summaryList =
          _readMessageValue(() => message.summaryList) ?? const <String>[];
      final nameList =
          _readMessageValue(() => message.nameList) ?? const <String>[];
      if ((msgList.isEmpty && !hasRemotePayloadKey) ||
          summaryList.isEmpty ||
          nameList.isEmpty) {
        return null;
      }
      return _ResendMessagePayload(
        params: CombineMessageParams(
          sourceChannelType:
              _readMessageValue(() => message.sourceChannelType) ??
              channel.channelType,
          summaryList: summaryList,
          nameList: nameList,
          msgList: msgList,
          jsonMsgKey: jsonMsgKey,
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is CustomMediaMessage) {
      final messageIdentifier = _readMessageValue(
        () => message.messageIdentifier,
      );
      final path = _mediaLocalPathOf(message);
      final fields = _readMessageValue(() => message.fields);
      if (messageIdentifier == null ||
          messageIdentifier.isEmpty ||
          path == null ||
          path.isEmpty ||
          fields == null) {
        return null;
      }
      return _ResendMessagePayload(
        params: CustomMediaMessageParams(
          messageIdentifier: messageIdentifier,
          path: path,
          fields: fields,
          searchableWords: _readMessageValue(() => message.searchableWords),
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
      );
    }

    if (message is CustomMessage) {
      final messageIdentifier = _readMessageValue(
        () => message.messageIdentifier,
      );
      final fields = _readMessageValue(() => message.fields);
      if (messageIdentifier == null ||
          messageIdentifier.isEmpty ||
          fields == null) {
        return null;
      }
      return _ResendMessagePayload(
        params: CustomMessageParams(
          messageIdentifier: messageIdentifier,
          fields: fields,
          searchableWords: _readMessageValue(() => message.searchableWords),
          mentionedInfo: mentionedInfo,
          needReceipt: needReceipt,
        ),
        directedUserIds: directedUserIds,
      );
    }

    return null;
  }

  MentionedInfoParams? _mentionedInfoFromMessage(Message message) {
    final mentionedInfo = _readMessageValue(() => message.mentionedInfo);
    final type = _readMessageValue(() => mentionedInfo?.type);
    if (type == null) {
      return null;
    }
    return MentionedInfoParams(
      type: type,
      userIdList: _readMessageValue(() => mentionedInfo?.userIdList),
      mentionedContent: _readMessageValue(
        () => mentionedInfo?.mentionedContent,
      ),
    );
  }

  T? _readMessageValue<T>(T? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return null;
    }
  }

  Future<NCError?> _deleteLocalMessageBeforeResend(Message message) async {
    final clientId = _clientIdOf(message);
    if (clientId == null) {
      return NCError(code: -1, message: 'Message client id is unavailable');
    }
    return _operations.deleteLocalMessages([clientId]);
  }

  Future<NCError?> _sendResentMessage(_ResendMessagePayload payload) async {
    final params = payload.params;
    final code = _isMediaMessageParams(params)
        ? await channel.sendMediaMessage(
            SendMediaMessageParams(messageParams: params),
            handler: SendMediaMessageHandler(
              onMediaMessageSaved: (message) {
                if (message != null) {
                  _markOutgoingStatusSending(message);
                  _upsertMessage(message);
                }
              },
              onMediaMessageSending: (message, _) {
                if (message != null) {
                  _markOutgoingStatusSending(message);
                  _upsertMessage(message);
                }
              },
              onSendingMediaMessageCanceled: (message) {
                if (message != null) {
                  _handleSendResult(params, -1, message);
                  _safeNotifyListeners();
                }
              },
              onMediaMessageSent: (code, message) {
                _handleSendResult(params, code, message);
              },
            ),
          )
        : await channel.sendMessage(
            SendMessageParams(
              messageParams: params,
              directedUserIds: payload.directedUserIds,
            ),
            callback: SendMessageCallback(
              onMessageSaved: (message) {
                if (message != null) {
                  _markOutgoingStatusSending(message);
                  _upsertMessage(message);
                }
              },
              onMessageSent: (code, message) {
                _handleSendResult(params, code, message);
              },
            ),
          );
    if (code != 0) {
      final error = NCError(code: code);
      _lastError = error;
      _notifyAfterSend(params, null, error);
      _safeNotifyListeners();
      return error;
    }
    return null;
  }

  bool _isMediaMessageParams(MessageParams params) {
    return params is ImageMessageParams ||
        params is GIFMessageParams ||
        params is HDVoiceMessageParams ||
        params is ShortVideoMessageParams ||
        params is FileMessageParams ||
        params is CombineMessageParams ||
        params is CustomMediaMessageParams;
  }

  _CombinedForwardItem? _combinedForwardItem(Message message) {
    final objectName = _combineObjectName(message);
    final content = _combineContent(message);
    if (objectName == null || content == null || content.isEmpty) {
      return null;
    }
    final senderName = _senderDisplayName(message).trim();
    final resolvedSender = senderName.isNotEmpty
        ? senderName
        : message.senderUserId ?? channel.channelId;
    final summary = _combinedForwardSummary(message);
    if (summary.isEmpty) {
      return null;
    }
    return _CombinedForwardItem(
      senderName: resolvedSender,
      summary: summary,
      info: CombineMessageInfo(
        fromUserId: message.senderUserId,
        channelId: message.channelId,
        timestamp: message.sentTime ?? message.receivedTime,
        objectName: objectName,
        content: content,
      ),
    );
  }

  /// Toggles selection state for [message] in multi-select mode.
  bool toggleMessageSelected(Message message) {
    final key = _keyOf(message);
    if (_selectedMessageKeys.contains(key)) {
      _selectedMessageKeys.remove(key);
    } else {
      final limit = maxSelectedMessages <= 0 ? 1 : maxSelectedMessages;
      if (_selectedMessageKeys.length >= limit) {
        return false;
      }
      _selectedMessageKeys.add(key);
    }
    _safeNotifyListeners();
    return true;
  }

  /// Returns whether [message] is currently selected.
  bool isMessageSelected(Message message) {
    return _selectedMessageKeys.contains(_keyOf(message));
  }

  /// Returns whether [message] represents a forwarded reference message.
  static bool isReferenceForwardMessage(Message message) {
    return _isReferenceForwardMessage(message);
  }

  /// Searches messages in the current channel.
  Future<List<Message>> searchMessages(ChatMessageSearchRequest request) async {
    _beginSearch(request);
    try {
      final messages = switch (request.mode) {
        ChatMessageSearchMode.keyword => await _operations.searchMessages(
          request,
        ),
        ChatMessageSearchMode.user => await _operations.searchMessagesByUser(
          request,
        ),
        ChatMessageSearchMode.timeRange =>
          await _operations.searchMessagesByTimeRange(request),
        ChatMessageSearchMode.aroundTime =>
          await _operations.getMessagesAroundTime(request),
      };
      _searchResults = messages;
      _lastError = null;
      return messages;
    } catch (error) {
      _lastError = _toNCError(error);
      rethrow;
    } finally {
      _isSearching = false;
      _safeNotifyListeners();
    }
  }

  /// Deletes [message] only from the current user's local view.
  Future<NCError?> deleteMessageForMe(Message message) async {
    final cancelDownloadError = await _cancelMediaDownloadBeforeMutation(
      message,
    );
    if (!_isSuccess(cancelDownloadError)) {
      return cancelDownloadError;
    }
    if (message is MediaMessage &&
        _directionOf(message) == MessageDirection.send &&
        sentStatusForDisplay(message) == SentStatus.sending) {
      final cancelError = await _runChannelOperation(
        () => _operations.cancelSendingMediaMessage(channel, message),
        'cancelSendingMediaMessage',
      );
      if (!_isSuccess(cancelError)) {
        return cancelError;
      }
      final clientId = _clientIdOf(message);
      if (clientId == null) {
        final error = NCError(
          code: -1,
          message: 'Message client id is unavailable',
        );
        _lastError = error;
        return error;
      }
      _markLocallyDeletedSendingMessage(message);
      return _runChannelOperation(
        () => _operations.deleteLocalMessages([clientId]),
        'deleteLocalMessages',
        onSuccess: () {
          _removeMessages([message]);
          engineProvider.notifyChannelNeedsRefresh();
        },
      );
    }
    return _runChannelOperation(
      () => _operations.deleteMessageForMe(channel, message),
      'deleteMessageForMe',
      onSuccess: () async {
        await _refreshMessagesAfterStableMutation(
          fallback: () => _removeMessages([message]),
        );
        engineProvider.notifyChannelNeedsRefresh();
      },
    );
  }

  /// Deletes [message] for all users and updates local message state.
  Future<NCError?> deleteMessageForAll(Message message) async {
    final cancelDownloadError = await _cancelMediaDownloadBeforeMutation(
      message,
    );
    if (!_isSuccess(cancelDownloadError)) {
      return cancelDownloadError;
    }
    final sentStatus = _sentStatusOf(message);
    final sentTime = _sentTimeOf(message);
    final isConnectedEnough = !_isOfflineConnection(connectionStatus);
    final canDeleteForAll =
        isConnectedEnough &&
        (sentTime == null ||
            isMessageWithinDeleteForAllWindowForCurrentServerTime(sentTime)) &&
        sentStatus != SentStatus.sending &&
        sentStatus != SentStatus.failed &&
        sentStatus != SentStatus.canceled;
    if (!canDeleteForAll) {
      final error = NCError(code: 50102);
      _lastError = error;
      _callbacks.onUnsupportedAction?.call('deleteMessageForAll', '');
      _safeNotifyListeners();
      return error;
    }
    try {
      final result = await _operations.deleteMessageForAll(channel, message);
      _lastError = result.error;
      if (_isSuccess(result.error)) {
        final deletedForAllMessage = _resolveRecalledMessage(
          result.message,
          original: message,
        );
        if (deletedForAllMessage != null) {
          _replaceMessageWithRecall(
            deletedForAllMessage,
            original: message,
            notifyChannel: false,
          );
        } else {
          await _refreshMessagesAfterStableMutation(
            fallback: () => _removeMessages([message], notifyListeners: false),
          );
        }
        engineProvider.notifyChannelNeedsRefresh();
      }
      return result.error;
    } catch (error) {
      final converted = _toNCError(error);
      _lastError = converted;
      _callbacks.onUnsupportedAction?.call(
        'deleteMessageForAll',
        converted.message ?? '',
      );
      return converted;
    } finally {
      _safeNotifyListeners();
    }
  }

  /// Returns whether [sentTime] is inside the delete-for-all window.
  static bool isMessageWithinDeleteForAllWindow(
    int? sentTime, {
    DateTime? now,
    int? serverTimeDelta,
  }) {
    if (sentTime == null || sentTime <= 0) {
      return false;
    }
    final sentDate = DateTime.fromMillisecondsSinceEpoch(sentTime);
    final localNow = now ?? DateTime.now();
    final currentTime = serverTimeDelta == null
        ? localNow
        : localNow.subtract(Duration(milliseconds: serverTimeDelta));
    if (sentDate.isAfter(currentTime)) {
      return false;
    }
    return currentTime.difference(sentDate) <= _deleteForAllWindow;
  }

  /// Uses server-adjusted time to check the delete-for-all window.
  bool isMessageWithinDeleteForAllWindowForCurrentServerTime(int? sentTime) {
    return isMessageWithinDeleteForAllWindow(
      sentTime,
      now: engineProvider.serverNow,
    );
  }

  /// Deletes local messages sent before [timestamp].
  Future<NCError?> deleteMessagesForMeByTimestamp({
    required int timestamp,
    MessageOperationPolicy policy = MessageOperationPolicy.localRemote,
  }) {
    return _runChannelOperation(
      () => _operations.deleteMessagesForMeByTimestamp(
        channel,
        timestamp: timestamp,
        policy: policy,
      ),
      'deleteMessagesForMeByTimestamp',
    );
  }

  /// Saves a channel draft through the SDK.
  Future<NCError?> saveDraft(String draft) {
    return _runChannelOperation(
      () => _operations.saveDraft(channel, draft),
      'saveDraft',
    );
  }

  /// Clears the current channel draft through the SDK.
  Future<NCError?> clearDraft() {
    return _runChannelOperation(
      () => _operations.clearDraft(channel),
      'clearDraft',
    );
  }

  /// Loads unread mentioned messages for the current channel.
  Future<List<Message>> getUnreadMentionedMessages() async {
    try {
      final messages = await _operations.getUnreadMentionedMessages(channel);
      _setUnreadMentionedMessages(messages);
      _lastError = null;
      return messages;
    } catch (error) {
      _lastError = _toNCError(error);
      rethrow;
    } finally {
      _safeNotifyListeners();
    }
  }

  /// Loads read-receipt users for [message].
  Future<ChatReadReceiptUsersData> loadReadReceiptUsers(
    Message message, {
    ChatReadReceiptUsersLoader? loader,
  }) async {
    if (loader != null) {
      return loader(channel, message);
    }
    return _operations.loadReadReceiptUsers(channel, message);
  }

  /// Copies text from [message] to the clipboard or injected copy callback.
  Future<bool> copyMessage(Message message, {String? overrideText}) async {
    final text =
        overrideText ??
        extractCopyText(message) ??
        jsonEncode(message.toJson());
    if (text.isEmpty) {
      return false;
    }
    if (_callbacks.onCopyText != null) {
      await _callbacks.onCopyText!(text);
      return true;
    }
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  /// Dials the first phone number found in [message] through the injected callback.
  Future<bool> dialPhoneFromMessage(
    Message message, {
    String? phoneNumber,
  }) async {
    final resolvedPhone = phoneNumber ?? extractPhoneNumber(message);
    if (resolvedPhone == null || resolvedPhone.isEmpty) {
      return false;
    }
    if (_callbacks.onDialPhone != null) {
      await _callbacks.onDialPhone!(resolvedPhone);
      return true;
    }
    return false;
  }

  /// Hides unread history and mention tips for the current session.
  void dismissUnreadHistoryTip() {
    if (_unreadHistoryCount == 0 &&
        _unreadMentionCount == 0 &&
        _unreadMentionedMessages.isEmpty) {
      return;
    }
    _unreadHistoryCount = 0;
    _unreadMentionCount = 0;
    _unreadMentionedMessages = const [];
    _safeNotifyListeners();
  }

  /// Clears unread state for the current channel.
  Future<void> clearUnreadCount() async {
    if (_disposed) {
      return;
    }
    if (_isClearingUnread) {
      _hasPendingClearUnread = true;
      return;
    }
    final unreadClearChannel = _channelForUnreadClear();
    final channelUnread =
        unreadClearChannel.unreadCount ?? channel.unreadCount ?? 0;
    final currentUnread = channelUnread > _clearedUnreadFromChannel
        ? channelUnread - _clearedUnreadFromChannel
        : 0;
    _isClearingUnread = true;
    _suppressNextLocalUnreadSyncFrom(unreadClearChannel);
    try {
      final completion = Completer<NCError?>();
      final code = await unreadClearChannel.clearUnreadCount((error) {
        if (completion.isCompleted) {
          return;
        }
        completion.complete(error);
      });
      if (code != 0) {
        throw NCError(code: code);
      }
      final result = await completion.future;
      if ((result?.code ?? 0) != 0) {
        throw result!;
      }
      if (_disposed) {
        return;
      }
      _markChannelUnreadStateCleared();
      if (currentUnread > 0) {
        _clearedUnreadFromChannel += currentUnread;
        engineProvider.reduceTotalUnreadCount(currentUnread);
      }
      engineProvider.notifyChannelNeedsRefresh();
    } finally {
      _isClearingUnread = false;
    }
    if (_hasPendingClearUnread && !_disposed) {
      _hasPendingClearUnread = false;
      await clearUnreadCount();
    }
  }

  void _scheduleClearUnreadCount() {
    if (_disposed) {
      return;
    }
    _clearUnreadTimer?.cancel();
    _clearUnreadTimer = Timer(const Duration(milliseconds: 1000), () {
      _clearUnreadTimer = null;
      if (_disposed) {
        return;
      }
      unawaited(clearUnreadCount());
    });
  }

  BaseChannel _channelForUnreadClear() {
    final latestLoadedMessage = messages.isEmpty ? null : messages.last;
    final latestLoadedSentTime = latestLoadedMessage == null
        ? 0
        : (_sentTimeOf(latestLoadedMessage) ?? 0);
    final latestChannelSentTime = channel.latestMessage == null
        ? 0
        : (_sentTimeOf(channel.latestMessage!) ?? 0);
    if (latestLoadedMessage == null ||
        latestLoadedSentTime <= latestChannelSentTime) {
      return channel;
    }
    return BaseChannel(
      channel.channelType,
      channel.channelId,
      unreadCount: channel.unreadCount,
      mentionedCount: channel.mentionedCount,
      mentionedMeCount: channel.mentionedMeCount,
      isPinned: channel.isPinned,
      draft: channel.draft,
      latestMessage: latestLoadedMessage,
      notificationLevel: channel.notificationLevel,
      firstUnreadMsgSendTime: channel.firstUnreadMsgSendTime,
      operationTime: channel.operationTime,
      translateStrategy: channel.translateStrategy,
    );
  }

  bool _markChannelUnreadStateCleared() {
    final hadUnreadState =
        (channel.unreadCount ?? 0) > 0 ||
        (channel.mentionedCount ?? 0) > 0 ||
        (channel.mentionedMeCount ?? 0) > 0 ||
        _unreadHistoryCount > 0 ||
        _unreadMentionCount > 0 ||
        _unreadMentionedMessages.isNotEmpty;
    channel = _channelWithUnreadState(
      channel,
      unreadCount: 0,
      mentionedCount: 0,
      mentionedMeCount: 0,
    );
    _unreadHistoryCount = 0;
    _unreadMentionCount = 0;
    _unreadMentionedMessages = const [];
    if (hadUnreadState) {
      _safeNotifyListeners();
    }
    return hadUnreadState;
  }

  void _suppressNextLocalUnreadSyncFrom(BaseChannel unreadClearChannel) {
    _suppressedUnreadSyncTimestamp =
        unreadClearChannel.latestMessage?.sentTime ?? 0;
    _suppressUnreadSyncUntil = DateTime.now().add(const Duration(seconds: 2));
  }

  bool _consumeSuppressedUnreadSync(ChannelUnreadStatusSyncEvent event) {
    final timestamp = _suppressedUnreadSyncTimestamp;
    final until = _suppressUnreadSyncUntil;
    if (timestamp == null || until == null) {
      return false;
    }
    if (DateTime.now().isAfter(until)) {
      _suppressedUnreadSyncTimestamp = null;
      _suppressUnreadSyncUntil = null;
      return false;
    }
    if (event.timestamp != timestamp) {
      return false;
    }
    _suppressedUnreadSyncTimestamp = null;
    _suppressUnreadSyncUntil = null;
    return true;
  }

  BaseChannel _channelWithUnreadState(
    BaseChannel source, {
    required int unreadCount,
    required int mentionedCount,
    required int mentionedMeCount,
  }) {
    if (source is DirectChannel) {
      return DirectChannel(
        source.channelId,
        unreadCount: unreadCount,
        mentionedCount: mentionedCount,
        mentionedMeCount: mentionedMeCount,
        isPinned: source.isPinned,
        draft: source.draft,
        latestMessage: source.latestMessage,
        notificationLevel: source.notificationLevel,
        firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
        operationTime: source.operationTime,
        translateStrategy: source.translateStrategy,
      );
    }
    if (source is GroupChannel) {
      return GroupChannel(
        source.channelId,
        unreadCount: unreadCount,
        mentionedCount: mentionedCount,
        mentionedMeCount: mentionedMeCount,
        isPinned: source.isPinned,
        draft: source.draft,
        latestMessage: source.latestMessage,
        notificationLevel: source.notificationLevel,
        firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
        operationTime: source.operationTime,
        translateStrategy: source.translateStrategy,
      );
    }
    if (source is SystemChannel) {
      return SystemChannel(
        source.channelId,
        unreadCount: unreadCount,
        mentionedCount: mentionedCount,
        mentionedMeCount: mentionedMeCount,
        isPinned: source.isPinned,
        draft: source.draft,
        latestMessage: source.latestMessage,
        notificationLevel: source.notificationLevel,
        firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
        operationTime: source.operationTime,
        translateStrategy: source.translateStrategy,
      );
    }
    if (source is OpenChannel) {
      return OpenChannel(
        source.channelId,
        unreadCount: unreadCount,
        mentionedCount: mentionedCount,
        mentionedMeCount: mentionedMeCount,
        isPinned: source.isPinned,
        draft: source.draft,
        latestMessage: source.latestMessage,
        notificationLevel: source.notificationLevel,
        firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
        operationTime: source.operationTime,
        translateStrategy: source.translateStrategy,
      );
    }
    if (source is CommunitySubChannel) {
      return CommunitySubChannel(
        source.channelId,
        source.subChannelId,
        unreadCount: unreadCount,
        mentionedCount: mentionedCount,
        mentionedMeCount: mentionedMeCount,
        isPinned: source.isPinned,
        draft: source.draft,
        latestMessage: source.latestMessage,
        notificationLevel: source.notificationLevel,
        firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
        operationTime: source.operationTime,
        translateStrategy: source.translateStrategy,
      );
    }
    if (source is CommunityChannel) {
      return CommunityChannel(
        source.channelId,
        unreadCount: unreadCount,
        mentionedCount: mentionedCount,
        mentionedMeCount: mentionedMeCount,
        isPinned: source.isPinned,
        draft: source.draft,
        latestMessage: source.latestMessage,
        notificationLevel: source.notificationLevel,
        firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
        operationTime: source.operationTime,
        translateStrategy: source.translateStrategy,
      );
    }
    return BaseChannel(
      source.channelType,
      source.channelId,
      unreadCount: unreadCount,
      mentionedCount: mentionedCount,
      mentionedMeCount: mentionedMeCount,
      isPinned: source.isPinned,
      draft: source.draft,
      latestMessage: source.latestMessage,
      notificationLevel: source.notificationLevel,
      firstUnreadMsgSendTime: source.firstUnreadMsgSendTime,
      operationTime: source.operationTime,
      translateStrategy: source.translateStrategy,
    );
  }

  /// Removes [message] from the unread-mentioned list.
  void removeUnreadMentionedMessage(Message message) {
    if (_unreadMentionedMessages.isEmpty) {
      return;
    }
    final key = _keyOf(message);
    final updated = _unreadMentionedMessages
        .where((item) => _keyOf(item) != key)
        .toList();
    if (updated.length == _unreadMentionedMessages.length) {
      return;
    }
    _unreadMentionedMessages = updated;
    _unreadMentionCount = updated.length;
    _safeNotifyListeners();
  }

  /// Message editing placeholder; currently returns an unsupported SDK error.
  Future<NCError> editMessage({
    required Message message,
    String? replacementText,
  }) async {
    final error = NCError(code: 50101, message: _messageEditUnsupportedReason);
    _callbacks.onUnsupportedAction?.call(
      'editMessage',
      _messageEditUnsupportedReason,
    );
    _lastError = error;
    _safeNotifyListeners();
    return error;
  }

  /// Sets the message referenced by the input area.
  void setReferenceMessage(Message? message) {
    if (_referenceMessage == message) {
      return;
    }
    _referenceMessage = message;
    _safeNotifyListeners();
  }

  /// Clears the referenced message from the input area.
  void clearReferenceMessage() {
    if (_referenceMessage == null) {
      return;
    }
    _referenceMessage = null;
    _safeNotifyListeners();
  }

  /// Clears message search state and results.
  void clearSearchState() {
    _searchResults = const [];
    _lastSearchRequest = null;
    _lastError = null;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> _refreshMessagesAfterStableMutation({
    required VoidCallback fallback,
  }) async {
    if (_query == null && _hasResolvedInitialLoad) {
      fallback();
      return;
    }
    await loadInitialMessages();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _clearUnreadTimer?.cancel();
    _clearUnreadTimer = null;
    for (final message in _activeMediaDownloads.values.toList()) {
      unawaited(message.cancelDownloadingMedia((_, _) {}).catchError((_) => 0));
    }
    _mediaDownloadFutures.clear();
    _activeMediaDownloads.clear();
    engineProvider.receivedMessageNotifier.removeListener(_onMessageReceived);
    engineProvider.channelMessageUpsertedNotifier.removeListener(
      _onChannelMessageUpserted,
    );
    engineProvider.deletedMessagesNotifier.removeListener(_onMessagesDeleted);
    engineProvider.connectionStatusNotifier.removeListener(
      _onConnectionStatusChanged,
    );
    engineProvider.channelUnreadStatusSyncNotifier.removeListener(
      _onChannelUnreadStatusSync,
    );
    scrollController.dispose();
    super.dispose();
  }
}
