import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../../models/chat_profile_info.dart';
import '../../../providers/chat_provider.dart';
import '../bubble/bubble_config.dart';
import '../input/message_input_config.dart';

/// Deletes a message from a channel.
typedef ChatMessageDeleteHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel channel,
      Message message,
    );

/// Copies text extracted from a message.
typedef ChatMessageCopyHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel channel,
      Message message,
      String text,
    );

/// Deletes a sent message for all users.
typedef ChatMessageDeleteForAllHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel channel,
      Message message,
    );

/// References a message in the input area.
typedef ChatMessageReferenceHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel channel,
      Message message,
    );

/// Handles taps on links detected in text messages.
typedef ChatMessageLinkTap =
    FutureOr<void> Function(BuildContext context, Message message, Uri uri);

/// Handles taps on phone numbers detected in text messages.
typedef ChatMessagePhoneTap =
    FutureOr<void> Function(
      BuildContext context,
      Message message,
      String phoneNumber,
    );

/// Handles taps on a message read-receipt status.
typedef ChatReadReceiptStatusTap =
    void Function(BuildContext context, Message message);

/// Retries sending a failed message.
typedef ChatMessageResendHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel? channel,
      Message message,
    );

/// Forwards selected messages from a source channel.
typedef ChatMessageForwardHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel sourceChannel,
      List<Message> messages,
    );

/// Builds a custom bubble for a message type.
typedef ChatMessageBubbleBuilder =
    Widget Function(
      BuildContext context,
      Message message,
      ChatPageConfig config,
    );

/// Display data passed to a custom read-receipt member row.
class ChatReadReceiptMemberViewData {
  /// Raw receipt entry returned by the configured loader or SDK page source.
  final ChatReadReceiptUserEntry receiptUser;

  /// Profile resolved for [receiptUser], with a user-ID fallback.
  final ChatProfileInfo profile;

  /// Whether this row belongs to the read or unread tab.
  final MessageReadReceiptStatus readStatus;

  /// Zero-based index within the current tab.
  final int index;

  const ChatReadReceiptMemberViewData({
    required this.receiptUser,
    required this.profile,
    required this.readStatus,
    required this.index,
  });
}

/// Builds one custom member row in the read-receipt detail sheet.
typedef ChatReadReceiptMemberBuilder =
    Widget Function(BuildContext context, ChatReadReceiptMemberViewData data);

/// Resolves a chat title for a channel.
typedef ChatTitleResolver =
    FutureOr<String?> Function(BuildContext context, BaseChannel channel);

/// Receives async message events scoped to ChatPage.
typedef ChatAsyncMessageReceivedListener =
    FutureOr<void> Function(BuildContext context, Message message);

/// Delete mode used by the message long-press menu.
enum ChatMessageDeleteBehavior { forMe, forAll, custom }

/// Deprecated swipe direction kept for source compatibility.
enum ChatMessageSwipeDirection { left, right }

/// Deprecated message swipe callback kept for source compatibility.
typedef ChatMessageSwipeCallback =
    void Function(
      BuildContext context,
      Message message,
      ChatMessageSwipeDirection direction,
    );

/// Background configuration for ChatPage.
class ChatBackgroundConfig {
  /// Solid background color behind the message list.
  final Color? backgroundColor;

  /// Safe-area background color override.
  final Color? safeAreaColor;

  /// Local background image provider.
  final ImageProvider? backgroundImage;

  /// Remote background image URL.
  final String? backgroundImageUrl;

  /// Fit mode for [backgroundImage] or [backgroundImageUrl].
  final BoxFit imageFitMode;

  /// Repeat mode for the background image.
  final ImageRepeat imageRepeat;

  const ChatBackgroundConfig({
    this.backgroundColor,
    this.safeAreaColor,
    this.backgroundImage,
    this.backgroundImageUrl,
    this.imageFitMode = BoxFit.cover,
    this.imageRepeat = ImageRepeat.noRepeat,
  });

  /// Whether any background override has been configured.
  bool get hasBackground =>
      backgroundColor != null ||
      safeAreaColor != null ||
      backgroundImage != null ||
      backgroundImageUrl != null;
}

/// Top-level configuration for ChatPage.
class ChatPageConfig {
  /// Top bar configuration.
  final ChatAppBarConfig appBarConfig;

  /// Page background configuration.
  final ChatBackgroundConfig backgroundConfig;

  /// Message list behavior configuration.
  final MessageListConfig messageListConfig;

  /// Input area configuration.
  final MessageInputConfig inputConfig;

  /// Message bubble configuration.
  final BubbleConfig bubbleConfig;

  /// Long-press message menu configuration.
  final ChatMessageLongPressMenuConfig longPressMenuConfig;

  /// Optional host handler for forwarding selected messages.
  final ChatMessageForwardHandler? onForwardSelectedMessages;

  /// Custom bubble builders keyed by Nexconn [MessageType].
  final Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders;

  /// Optional profile resolver used by titles, sender names, and avatars.
  final ChatProfileProvider? profileProvider;

  /// Optional custom builder for read-receipt member rows.
  final ChatReadReceiptMemberBuilder? readReceiptMemberBuilder;

  /// Optional hook that can block or adjust send flow before SDK send.
  final ChatBeforeSendMessageInterceptor? onBeforeSendMessage;

  /// Optional hook invoked after SDK send completes.
  final ChatAfterSendMessageInterceptor? onAfterSendMessage;

  /// Optional async listener for messages received while this page is active.
  final ChatAsyncMessageReceivedListener? onAsyncMessageReceived;

  const ChatPageConfig({
    this.appBarConfig = const ChatAppBarConfig(),
    this.backgroundConfig = const ChatBackgroundConfig(),
    this.messageListConfig = const MessageListConfig(),
    this.inputConfig = const MessageInputConfig(),
    this.bubbleConfig = const BubbleConfig(),
    this.longPressMenuConfig = const ChatMessageLongPressMenuConfig(),
    this.onForwardSelectedMessages,
    this.customMessageBubbleBuilders,
    this.profileProvider,
    this.readReceiptMemberBuilder,
    this.onBeforeSendMessage,
    this.onAfterSendMessage,
    this.onAsyncMessageReceived,
  });
}

/// Configuration for the chat top bar.
class ChatAppBarConfig {
  /// Preferred app bar height.
  final double height;

  /// Static title used when [titleResolver] returns null.
  final String? title;

  /// Async title resolver for the current channel.
  final ChatTitleResolver? titleResolver;

  /// Whether the title is centered.
  final bool centerTitle;

  /// Top bar background color.
  final Color? backgroundColor;

  /// Title text style override.
  final TextStyle? titleTextStyle;

  /// Whether to show the built-in message search button.
  final bool showSearchButton;

  /// Whether the back button shows unread count.
  final bool showBackUnreadBadge;
  final String? searchButtonTooltip;
  final String? searchPageTitle;
  final List<Widget>? actions;

  const ChatAppBarConfig({
    this.height = 56,
    this.title,
    this.titleResolver,
    this.centerTitle = true,
    this.backgroundColor,
    this.titleTextStyle,
    this.showSearchButton = false,
    this.showBackUnreadBadge = true,
    this.searchButtonTooltip,
    this.searchPageTitle,
    this.actions,
  });
}

/// Configuration for MessageListWidget behavior and status tips.
class MessageListConfig {
  /// Message list background color override.
  final Color? backgroundColor;

  /// Empty-state text override.
  final String? emptyText;

  /// Whether message avatars are shown.
  final bool showAvatar;

  /// Whether sender names are shown above incoming messages.
  final bool showSenderName;

  /// Whether outgoing send status is shown.
  ///
  /// Deprecated: 对齐 IMKit 已读状态 V5 后，发送状态不再以文字形式展示，
  /// 发送中/失败图标始终显示；已读状态由 [showReadReceiptIndicator] 控制。
  @Deprecated('Use showReadReceiptIndicator to control the V5 read status.')
  final bool showSentStatus;

  /// Whether unread history tips are shown.
  final bool showUnreadHistoryTip;
  final bool showNewMessageTip;
  final bool showTypingStatusTip;

  /// Number of messages to request per history page.
  final int historyMessageCount;

  /// Maximum selected messages allowed in multi-select mode.
  final int maxSelectedMessages;
  final bool showNetworkStatusTip;
  final String? networkStatusText;
  final String? unreadHistoryTipText;
  final String? newMessageTipText;
  final String? typingStatusTipText;
  final bool showReadReceiptUserList;
  final bool showReadReceiptIndicator;
  final double readReceiptIndicatorSize;
  final Color? readReceiptReadColor;
  final Color? readReceiptUnreadColor;
  final String? readReceiptUsersTitle;
  final String? readReceiptUsersReadTabText;
  final String? readReceiptUsersUnreadTabText;
  final String? readReceiptUsersLoadingText;
  final String? readReceiptUsersEmptyText;
  final String? readReceiptUsersLoadFailedText;
  final int readReceiptUsersPageSize;
  final ChatMessageLinkTap? onLinkTap;
  final ChatMessagePhoneTap? onPhoneTap;
  final ChatReadReceiptStatusTap? onReadReceiptStatusTap;
  final ChatMessageResendHandler? onResendMessage;

  /// Optional loader for read-receipt user details.
  final ChatReadReceiptUsersLoader? readReceiptUsersLoader;

  /// Deprecated; message references are triggered from the long-press menu.
  @Deprecated(
    'Message swipe actions are disabled; use long press reply instead.',
  )
  final bool enableSwipeToReference;

  const MessageListConfig({
    this.backgroundColor,
    this.emptyText,
    this.showAvatar = true,
    this.showSenderName = false,
    this.showSentStatus = false,
    this.showUnreadHistoryTip = true,
    this.showNewMessageTip = true,
    this.showTypingStatusTip = true,
    this.historyMessageCount = 20,
    this.maxSelectedMessages = 100,
    this.showNetworkStatusTip = true,
    this.networkStatusText,
    this.unreadHistoryTipText,
    this.newMessageTipText,
    this.typingStatusTipText,
    this.showReadReceiptUserList = true,
    this.showReadReceiptIndicator = true,
    this.readReceiptIndicatorSize = 16,
    this.readReceiptReadColor,
    this.readReceiptUnreadColor,
    this.readReceiptUsersTitle,
    this.readReceiptUsersReadTabText,
    this.readReceiptUsersUnreadTabText,
    this.readReceiptUsersLoadingText,
    this.readReceiptUsersEmptyText,
    this.readReceiptUsersLoadFailedText,
    this.readReceiptUsersPageSize = 50,
    this.onLinkTap,
    this.onPhoneTap,
    this.onReadReceiptStatusTap,
    this.onResendMessage,
    this.readReceiptUsersLoader,
    this.enableSwipeToReference = false,
  }) : assert(readReceiptUsersPageSize >= 1 && readReceiptUsersPageSize <= 100),
       assert(readReceiptIndicatorSize > 0);
}

/// Configuration for the message long-press action menu.
class ChatMessageLongPressMenuConfig {
  /// Whether the long-press menu is enabled.
  final bool enabled;

  /// Whether the copy action is shown when supported.
  final bool showCopyButton;

  /// Whether the delete action is shown.
  final bool showDeleteButton;

  /// Whether the delete-for-all action is shown.
  final bool showDeleteForAllButton;

  /// Whether the reference action is shown.
  final bool showReferenceButton;

  /// Whether the built-in text-message edit action is shown.
  final bool showEditButton;
  final bool showMoreButton;
  final bool showForwardButton;
  final String? copyText;
  final String? deleteText;
  final String? deleteForAllText;
  final String? referenceText;
  final String? editText;
  final String? moreText;
  final String? forwardText;

  /// Default delete behavior for the built-in delete action.
  final ChatMessageDeleteBehavior deleteBehavior;

  /// Optional host override for copy behavior.
  final ChatMessageCopyHandler? onCopy;

  /// Optional host override for delete behavior.
  final ChatMessageDeleteHandler? onDelete;

  /// Optional host override for delete-for-all behavior.
  final ChatMessageDeleteForAllHandler? onDeleteForAll;

  /// Optional host override for reference behavior.
  final ChatMessageReferenceHandler? onReference;

  const ChatMessageLongPressMenuConfig({
    this.enabled = true,
    this.showCopyButton = true,
    this.showDeleteButton = true,
    this.showDeleteForAllButton = true,
    this.showReferenceButton = true,
    this.showEditButton = true,
    this.showMoreButton = true,
    this.showForwardButton = true,
    this.copyText,
    this.deleteText,
    this.deleteForAllText,
    this.referenceText,
    this.editText,
    this.moreText,
    this.forwardText,
    this.deleteBehavior = ChatMessageDeleteBehavior.forMe,
    this.onCopy,
    this.onDelete,
    this.onDeleteForAll,
    this.onReference,
  });
}
