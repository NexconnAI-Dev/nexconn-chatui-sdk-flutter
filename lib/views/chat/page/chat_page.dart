import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../../../providers/audio_player_provider.dart';
import '../../../providers/channel_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/message_input_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../ui_config/chat/page/chat_page_config.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/constants.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';
import '../input/message_input_widget.dart';
import 'chat_app_bar_widget.dart';
import 'message_list_widget.dart';

/// Builds a custom app bar for ChatPage.
typedef ChatAppBarBuilder =
    PreferredSizeWidget Function(BuildContext context, ChatAppBarConfig config);

/// Page that displays messages and input for one BaseChannel.
class ChatPage extends StatefulWidget {
  final BaseChannel channel;
  final ChatPageConfig config;
  final ChatProvider? provider;
  final ChatAppBarBuilder? appBarBuilder;
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
  final ChannelProvider Function(BuildContext context)?
  forwardChannelProviderBuilder;
  final Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders;

  const ChatPage({
    super.key,
    required this.channel,
    this.config = const ChatPageConfig(),
    this.provider,
    this.appBarBuilder,
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
    this.forwardChannelProviderBuilder,
    this.customMessageBubbleBuilders,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  ChatProvider? _ownedProvider;
  late final NexconnAudioPlayerProvider _audioPlayerProvider;
  late final MessageInputProvider _messageInputProvider;
  late final MessageListController _messageListController;
  ChatProvider? _listenedProvider;
  bool _isSyncingReference = false;

  ChatProvider get _provider => widget.provider ?? _ownedProvider!;

  @override
  void initState() {
    super.initState();
    _audioPlayerProvider = NexconnAudioPlayerProvider();
    _messageInputProvider = MessageInputProvider();
    _messageListController = MessageListController();
    _ensureOwnedProvider();
    _attachProviderListener(_provider);
    _messageInputProvider.addListener(_syncReferenceToChatProvider);
    _syncReferenceFromChatProvider();
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldChannel = oldWidget.channel;
    final channelChanged = _isDifferentChannel(oldChannel, widget.channel);

    if (widget.provider == null && oldWidget.provider != null) {
      _ensureOwnedProvider();
    }

    if (widget.provider == null && channelChanged) {
      _replaceOwnedProvider();
    } else if (widget.provider != null &&
        oldWidget.provider != widget.provider) {
      _ownedProvider?.dispose();
      _ownedProvider = null;
    }

    if (oldWidget.provider == null &&
        widget.provider == null &&
        !channelChanged) {
      return;
    }

    _attachProviderListener(_provider);
    if (channelChanged) {
      _clearReferenceState();
    }
    _syncReferenceFromChatProvider();
  }

  @override
  void dispose() {
    _detachProviderListener();
    _audioPlayerProvider.dispose();
    _messageInputProvider.removeListener(_syncReferenceToChatProvider);
    _messageInputProvider.dispose();
    _ownedProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final backgroundColor = _effectiveMessageListBackgroundColor(theme);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: _provider),
        ChangeNotifierProvider<NexconnAudioPlayerProvider>.value(
          value: _audioPlayerProvider,
        ),
        ChangeNotifierProvider<MessageInputProvider>.value(
          value: _messageInputProvider,
        ),
        Provider<MessageListController?>.value(value: _messageListController),
      ],
      child: Scaffold(
        backgroundColor:
            widget.config.backgroundConfig.safeAreaColor ?? backgroundColor,
        appBar:
            widget.appBarBuilder?.call(context, widget.config.appBarConfig) ??
            ChatAppBarWidget(channel: widget.channel, config: widget.config),
        body: _buildBodyBackground(
          backgroundColor: backgroundColor,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (notification.direction != ScrollDirection.idle) {
                          _collapseInputIfNeeded();
                        }
                        return false;
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: _collapseInputIfNeeded,
                              child: const SizedBox.expand(),
                            ),
                          ),
                          MessageListWidget(
                            channel: widget.channel,
                            config: widget.config,
                            controller: _messageListController,
                            messageBuilder: widget.messageBuilder,
                            onMessageTap: widget.onMessageTap,
                            onMessageDoubleTap: widget.onMessageDoubleTap,
                            onMessageLongPress: widget.onMessageLongPress,
                            onMessageAvatarTap: widget.onMessageAvatarTap,
                            onMessageAvatarLongPress:
                                widget.onMessageAvatarLongPress,
                            onMessageSwipe: widget.onMessageSwipe,
                            headerBuilder: widget.headerBuilder,
                            footerBuilder: widget.footerBuilder,
                            emptyBuilder: widget.emptyBuilder,
                            forwardChannelProviderBuilder:
                                widget.forwardChannelProviderBuilder,
                            customMessageBubbleBuilders:
                                widget.customMessageBubbleBuilders ??
                                widget.config.customMessageBubbleBuilders,
                            initialUnreadCount: widget.channel.unreadCount ?? 0,
                            initialUnreadMentionCount:
                                widget.channel.mentionedMeCount ?? 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.channel.channelType != ChannelType.system)
                    MessageInputWidget(
                      channel: widget.channel,
                      config: widget.config.inputConfig,
                      profileProvider: widget.config.profileProvider,
                      forwardChannelProviderBuilder:
                          widget.forwardChannelProviderBuilder,
                    ),
                ],
              ),
              Consumer<MessageInputProvider>(
                builder: (context, input, _) => input.isVoiceRecording
                    ? _VoiceRecordingOverlay(
                        isCanceling: input.isVoiceCanceling,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _collapseInputIfNeeded() {
    if (_messageInputProvider.mode == MessageInputMode.voice) {
      return;
    }
    _messageInputProvider.setMode(MessageInputMode.initial);
  }

  Color _defaultMessageListBackgroundColor(NexconnThemeTokens theme) {
    if (theme.brightness == Brightness.light &&
        theme.pageBackgroundColor ==
            NexconnThemeTokens.light.pageBackgroundColor) {
      return chatPageBackgroundColor;
    }
    return theme.pageBackgroundColor;
  }

  Color _effectiveMessageListBackgroundColor(NexconnThemeTokens theme) {
    return widget.config.backgroundConfig.backgroundColor ??
        widget.config.messageListConfig.backgroundColor ??
        _defaultMessageListBackgroundColor(theme);
  }

  Widget _buildBodyBackground({
    required Color backgroundColor,
    required Widget child,
  }) {
    final backgroundConfig = widget.config.backgroundConfig;
    ImageProvider? image = backgroundConfig.backgroundImage;
    final url = backgroundConfig.backgroundImageUrl;
    if (image == null && url != null && url.isNotEmpty) {
      image = NetworkImage(url);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        image: image == null
            ? null
            : DecorationImage(
                image: image,
                fit: backgroundConfig.imageFitMode,
                repeat: backgroundConfig.imageRepeat,
              ),
      ),
      child: child,
    );
  }

  void _syncReferenceFromChatProvider() {
    if (_isSyncingReference) {
      return;
    }
    var clearedInvalidEdit = false;
    _isSyncingReference = true;
    try {
      final referenceMessage = _provider.referenceMessage;
      if (referenceMessage != _messageInputProvider.referenceMessage) {
        _messageInputProvider.setReferenceMessage(referenceMessage);
      }
      final editingMessage = _messageInputProvider.editingMessage;
      if (editingMessage != null &&
          !_provider.isMessageStillEditable(editingMessage)) {
        _messageInputProvider.clearEditing();
        clearedInvalidEdit = true;
      }
    } finally {
      _isSyncingReference = false;
    }
    if (clearedInvalidEdit) {
      _syncReferenceToChatProvider();
      unawaited(_provider.clearEditedMessageDraft());
    }
  }

  void _syncReferenceToChatProvider() {
    if (_isSyncingReference) {
      return;
    }
    _isSyncingReference = true;
    try {
      final referenceMessage = _messageInputProvider.referenceMessage;
      if (referenceMessage != _provider.referenceMessage) {
        _provider.setReferenceMessage(referenceMessage);
      }
    } finally {
      _isSyncingReference = false;
    }
  }

  void _ensureOwnedProvider() {
    if (widget.provider != null || _ownedProvider != null) {
      return;
    }
    _ownedProvider = _createOwnedProvider(widget.channel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadInitialMessagesAndScrollToBottom(_ownedProvider));
      }
    });
  }

  ChatProvider _createOwnedProvider(BaseChannel channel) {
    return ChatProvider(
      engineProvider: context.read<EngineProvider>(),
      channel: channel,
      pageSize: widget.config.messageListConfig.historyMessageCount,
      maxSelectedMessages: widget.config.messageListConfig.maxSelectedMessages,
      callbacks: ChatMessageActionCallbacks(
        onBeforeSendMessage: widget.config.onBeforeSendMessage,
        onAfterSendMessage: widget.config.onAfterSendMessage,
      ),
    );
  }

  void _replaceOwnedProvider() {
    if (widget.provider != null) {
      return;
    }
    _detachProviderListener();
    _ownedProvider?.dispose();
    _ownedProvider = _createOwnedProvider(widget.channel);
    _attachProviderListener(_ownedProvider!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadInitialMessagesAndScrollToBottom(_ownedProvider));
      }
    });
  }

  Future<void> _loadInitialMessagesAndScrollToBottom(
    ChatProvider? provider,
  ) async {
    final targetProvider = provider;
    if (targetProvider == null) {
      return;
    }
    await targetProvider.loadInitialMessages();
    if (!mounted || !identical(targetProvider, _provider)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(targetProvider, _provider)) {
        return;
      }
      unawaited(_messageListController.scrollToBottom());
    });
  }

  void _attachProviderListener(ChatProvider provider) {
    if (identical(_listenedProvider, provider)) {
      return;
    }
    _detachProviderListener();
    _listenedProvider = provider;
    provider.addListener(_syncReferenceFromChatProvider);
  }

  void _detachProviderListener() {
    _listenedProvider?.removeListener(_syncReferenceFromChatProvider);
    _listenedProvider = null;
  }

  void _clearReferenceState() {
    if (_isSyncingReference) {
      return;
    }
    _isSyncingReference = true;
    try {
      _messageInputProvider.clearReferenceMessage();
      if (_provider.referenceMessage != null) {
        _provider.clearReferenceMessage();
      }
    } finally {
      _isSyncingReference = false;
    }
  }

  bool _isDifferentChannel(BaseChannel previous, BaseChannel next) {
    return previous.channelType != next.channelType ||
        previous.channelId != next.channelId ||
        previous.channelIdentifier.subChannelId !=
            next.channelIdentifier.subChannelId;
  }
}

class _VoiceRecordingOverlay extends StatelessWidget {
  final bool isCanceling;

  const _VoiceRecordingOverlay({required this.isCanceling});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          alignment: AlignmentDirectional.bottomCenter,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.grey.withValues(alpha: .5)
                      : Colors.black.withValues(alpha: .7),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Image(
                image: const AssetImage(
                  'assets/voice_send_bg.png',
                  package: 'ai_nexconn_chatui_plugin',
                ),
                height: kVoiceRecordingBackgroundHeight,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.fill,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChatUIAsset.image(
                  'NexconnLightIcon/Close.png',
                  width: kVoiceRecordingCloseIconSize,
                  height: kVoiceRecordingCloseIconSize,
                  color: Colors.black,
                ),
                const SizedBox(height: kVoiceRecordingIconSpace),
                Image(
                  image: const AssetImage(
                    'assets/voice_send_icon.png',
                    package: 'ai_nexconn_chatui_plugin',
                  ),
                  width: kVoiceRecordingVoiceIconWidth,
                  height: kVoiceRecordingVoiceIconHeight,
                ),
                const SizedBox(height: kVoiceRecordingIconSpace / 2),
                Text(
                  isCanceling
                      ? context.chatUIL10n.messageInputVoiceReleaseToCancel
                      : context.chatUIL10n.messageInputVoiceReleaseToSend,
                  style: const TextStyle(
                    fontSize: kVoiceRecordingFontSize,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: kVoiceRecordingBottomSpace),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
