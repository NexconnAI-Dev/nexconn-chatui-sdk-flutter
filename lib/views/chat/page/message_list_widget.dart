import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../providers/chat_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/channel_provider.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/message_input_provider.dart';
import '../../../routes/nexconn_chat_ui_routes.dart';
import '../../../ui_config/chat/page/chat_page_config.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/constants.dart';
import '../../../utils/message_type_util.dart';
import '../../../utils/time_util.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';
import '../../chat_extras/combine_message_detail_page.dart';
import 'message_list_controller.dart';
import '../bubble/message_bubble.dart';

export 'message_list_controller.dart';

part 'message_list/message_list_layout.dart';
part 'message_list/message_item.dart';
part 'message_list/message_menu_actions.dart';
part 'message_list/message_long_press_menu.dart';
part 'message_list/message_menu_operations.dart';
part 'message_list/message_reference_actions.dart';
part 'message_list/message_scroll_controller.dart';
part 'message_list/message_list_events.dart';
part 'message_list/message_scroll_positioning.dart';
part 'message_list/message_status_tips.dart';

const String _outgoingAppendReserveChromeId = 'outgoing_append_reserve';
const Duration _outgoingAppendReserveTimeout = Duration(milliseconds: 700);

/// Builds a custom message row in MessageListWidget.
typedef MessageWidgetBuilder =
    Widget Function(
      BuildContext context,
      Message message,
      ChatPageConfig config,
    );

/// Scrollable message list for one BaseChannel.
class MessageListWidget extends StatefulWidget {
  final BaseChannel channel;
  final ChatPageConfig config;
  final MessageListController? controller;
  final ChannelProvider Function(BuildContext context)?
  forwardChannelProviderBuilder;
  final MessageWidgetBuilder? messageBuilder;
  final ValueChanged<Message>? onMessageTap;
  final ValueChanged<Message>? onMessageDoubleTap;
  final ValueChanged<Message>? onMessageLongPress;
  final ValueChanged<Message>? onMessageAvatarTap;
  final ValueChanged<Message>? onMessageAvatarLongPress;
  final ChatMessageSwipeCallback? onMessageSwipe;
  final WidgetBuilder? headerBuilder;
  final WidgetBuilder? footerBuilder;
  final WidgetBuilder? emptyBuilder;
  final int initialUnreadCount;
  final int initialUnreadMentionCount;
  final Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders;

  const MessageListWidget({
    super.key,
    required this.channel,
    required this.config,
    this.controller,
    this.forwardChannelProviderBuilder,
    this.messageBuilder,
    this.onMessageTap,
    this.onMessageDoubleTap,
    this.onMessageLongPress,
    this.onMessageAvatarTap,
    this.onMessageAvatarLongPress,
    this.onMessageSwipe,
    this.headerBuilder,
    this.footerBuilder,
    this.emptyBuilder,
    this.initialUnreadCount = 0,
    this.initialUnreadMentionCount = 0,
    this.customMessageBubbleBuilders,
  });

  @override
  State<MessageListWidget> createState() => _MessageListWidgetState();
}

class _MessageListWidgetState extends State<MessageListWidget> {
  EngineProvider? _engineProvider;
  ChatProvider? _chatProvider;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final GlobalKey _messageListViewportMeasureKey = GlobalKey();
  TypingStatusChangedEvent? _typingStatusEvent;
  int? _lastMessageCount;
  bool _didInitialScrollToBottom = false;
  bool _isInitialScrollRevealPending = false;
  bool _wasNearBottom = true;
  bool _preserveBottomForInputTransition = true;
  bool _scrollToBottomCoalesced = false;
  bool _pendingScrollToBottom = false;
  bool _keepBottomVisibleCoalesced = false;
  bool _pendingKeepBottomVisible = false;
  bool _scrollRecoveryCoalesced = false;
  bool _pendingScrollRecovery = false;
  bool _pendingKeepBottomOnScrollRecovery = false;
  Timer? _outgoingAppendReserveTimer;
  int _outgoingAppendReserveGeneration = 0;
  int? _activeOutgoingAppendReserveGeneration;
  int _initialScrollRevealGeneration = 0;
  bool _initialScrollRevealScheduled = false;
  int? _initialScrollRevealMessageCount;
  String? _initialScrollRevealMessageIdentity;
  double? _messageListViewportHeight;
  bool _contentMeasureShowNetworkTip = false;
  bool _contentMeasureShowTypingTip = false;
  bool _isLoadingOlderWithAnchor = false;
  bool _isRefreshingOlderMessages = false;
  String? _lastLastMessageKey;
  String? _lastLastMessageScrollIdentity;
  final Map<String, GlobalKey> _messageItemKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _listChromeItemKeys = <String, GlobalKey>{};
  final Map<String, double> _messageVisibleFractions = <String, double>{};

  bool get _hasOutgoingAppendReserve =>
      _activeOutgoingAppendReserveGeneration != null;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(
      _handleVisibleItemsChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chatProvider = context.read<ChatProvider>();
    if (_chatProvider != chatProvider) {
      _unbindChatProvider();
      _chatProvider = chatProvider;
      _lastMessageCount = null;
      _didInitialScrollToBottom = false;
      _isInitialScrollRevealPending = false;
      _initialScrollRevealGeneration += 1;
      _initialScrollRevealScheduled = false;
      _initialScrollRevealMessageCount = null;
      _initialScrollRevealMessageIdentity = null;
      _messageListViewportHeight = null;
      _contentMeasureShowNetworkTip = false;
      _contentMeasureShowTypingTip = false;
      _wasNearBottom = true;
      _preserveBottomForInputTransition = true;
      _outgoingAppendReserveTimer?.cancel();
      _outgoingAppendReserveTimer = null;
      _activeOutgoingAppendReserveGeneration = null;
      _listChromeItemKeys.remove(_outgoingAppendReserveChromeId);
    }
    _bindMessageListController();
    final engineProvider = context.read<EngineProvider>();
    if (_engineProvider == engineProvider) {
      return;
    }
    _unbindEngineProvider();
    _engineProvider = engineProvider;
    _engineProvider!.receivedMessageNotifier.addListener(_handleMessageEvent);
    _engineProvider!.typingStatusNotifier.addListener(_handleTypingEvent);
    _handleTypingEvent();
  }

  @override
  void dispose() {
    final controller = widget.controller;
    controller?.clear();
    _outgoingAppendReserveTimer?.cancel();
    _outgoingAppendReserveTimer = null;
    _itemPositionsListener.itemPositions.removeListener(
      _handleVisibleItemsChanged,
    );
    _unbindChatProvider();
    _unbindEngineProvider();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MessageListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.clear();
      _bindMessageListController();
    }
  }

  void _setMessageListState(VoidCallback callback) {
    if (!mounted) {
      return;
    }
    setState(callback);
  }

  void _bindMessageListController() {
    final controller = widget.controller;
    final provider = _chatProvider;
    if (controller == null || provider == null) {
      return;
    }
    controller.bind(
      prepareForOutgoingAppend: () => _prepareForOutgoingAppend(provider),
      scrollToBottom: () => _scrollToBottom(provider),
      keepBottomVisible: () => _keepBottomVisible(provider),
      jumpToIndex: _jumpToOverallIndex,
      isAttached: () => _itemScrollController.isAttached,
      isNearBottom: () => _isNearBottom(provider),
      shouldKeepBottomForInputTransition: () =>
          _shouldKeepBottomForInputTransition(provider),
      getScrollOffset: _getScrollOffset,
      jumpToScrollOffset: _jumpToScrollOffset,
    );
  }

  bool get _isSystemChannel => widget.channel.channelType == ChannelType.system;

  @override
  Widget build(BuildContext context) => _buildMessageList(context);
}

class _MessageListRenderState {
  final bool isLoading;
  final int messageCount;
  final int messageSignature;
  final bool multiSelectMode;
  final int selectedSignature;
  final int unreadMentionedCount;
  final int unreadMentionedSignature;
  final ConnectionStatus connectionStatus;

  const _MessageListRenderState({
    required this.isLoading,
    required this.messageCount,
    required this.messageSignature,
    required this.multiSelectMode,
    required this.selectedSignature,
    required this.unreadMentionedCount,
    required this.unreadMentionedSignature,
    required this.connectionStatus,
  });

  factory _MessageListRenderState.fromProvider(ChatProvider provider) {
    final messages = provider.messages;
    final unreadMentionedMessages = provider.unreadMentionedMessages;
    final selectedMessages = provider.selectedMessages;
    return _MessageListRenderState(
      isLoading: provider.isLoading,
      messageCount: messages.length,
      messageSignature: Object.hashAll(messages.map(_messageRenderSignature)),
      multiSelectMode: provider.multiSelectMode,
      selectedSignature: Object.hashAll(
        selectedMessages.map(_messageIdentitySignature),
      ),
      unreadMentionedCount: unreadMentionedMessages.length,
      unreadMentionedSignature: Object.hashAll(
        unreadMentionedMessages.map(_messageIdentitySignature),
      ),
      connectionStatus: provider.connectionStatus,
    );
  }

  static Object _messageRenderSignature(Message message) {
    return Object.hash(
      _messageIdentitySignature(message),
      message.messageType,
      _safeRead(() => message.sentStatus),
      _safeRead(() => message.receivedStatus),
      message.sentTime,
      _safeRead(() => message.receivedTime),
    );
  }

  static T? _safeRead<T>(T? Function() read) {
    try {
      return read();
    } on NoSuchMethodError {
      return null;
    }
  }

  static Object _messageIdentitySignature(Message message) {
    final messageId = message.messageId;
    if (messageId != null && messageId.isNotEmpty) {
      return messageId;
    }
    return Object.hash(
      message.channelType,
      message.channelId,
      message.sentTime,
      message.receivedTime,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _MessageListRenderState &&
        other.isLoading == isLoading &&
        other.messageCount == messageCount &&
        other.messageSignature == messageSignature &&
        other.multiSelectMode == multiSelectMode &&
        other.selectedSignature == selectedSignature &&
        other.unreadMentionedCount == unreadMentionedCount &&
        other.unreadMentionedSignature == unreadMentionedSignature &&
        other.connectionStatus == connectionStatus;
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    messageCount,
    messageSignature,
    multiSelectMode,
    selectedSignature,
    unreadMentionedCount,
    unreadMentionedSignature,
    connectionStatus,
  );
}
