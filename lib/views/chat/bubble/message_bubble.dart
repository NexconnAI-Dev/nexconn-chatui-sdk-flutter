import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/chat_profile_info.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../routes/nexconn_chat_ui_routes.dart';
import '../../../ui_config/chat/bubble/bubble_config.dart';
import '../../../ui_config/chat/bubble/message_style_config.dart';
import '../../../ui_config/chat/page/chat_page_config.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/chatui_image_util.dart';
import '../../../utils/constants.dart';
import '../../../utils/message_content_util.dart';
import '../../../utils/time_util.dart';
import '../../../utils/voice_message_layout.dart';
import '../../chat_extras/file_preview_page.dart';
import '../../chat_extras/photo_preview_page.dart';
import '../../chat_extras/read_receipt_users_sheet.dart';
import '../../chat_extras/short_video_preview_page.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';

part 'core/message_bubble_layout.dart';
part 'core/message_bubble_accessories.dart';
part 'core/message_bubble_profile.dart';
part 'content/message_bubble_content.dart';
part 'content/typed_message_bubbles.dart';
part 'content/combine_message_bubble.dart';
part 'content/group_notification_bubble.dart';
part 'media/message_media_bubbles.dart';
part 'media/image_message_media_bubble.dart';
part 'media/voice_message_media_bubble.dart';
part 'media/file_video_message_media_bubbles.dart';
part 'media/video_message_media_bubble.dart';
part 'core/message_status_line.dart';
part 'core/message_send_status_indicator.dart';
part 'behavior/message_preview_actions.dart';
part 'behavior/message_reference_helpers.dart';
part 'content/linkified_text.dart';

/// Notification emitted when a referenced message is tapped.
class ReferenceMessageTapNotification extends Notification {
  final Message targetMessage;

  ReferenceMessageTapNotification(this.targetMessage);
}

final Map<String, Future<ChatProfileInfo?>> _messageProfileFutureCache =
    <String, Future<ChatProfileInfo?>>{};
final Map<String, ChatProfileInfo?> _messageProfileValueCache =
    <String, ChatProfileInfo?>{};

/// Default renderer for a Nexconn Message bubble.
class MessageBubble extends StatelessWidget {
  static const Key mediaPreviewKey = ValueKey('message-media-preview');
  static const Key mediaPreviewContentKey = ValueKey(
    'message-media-preview-content',
  );
  static const Key referenceImagePreviewKey = ValueKey(
    'message-reference-image-preview',
  );
  static const Key filePreviewContentKey = ValueKey(
    'message-file-preview-content',
  );
  static const Key combinePreviewKey = ValueKey('message-combine-preview');
  static const Key voiceDurationWidthKey = ValueKey(
    'message-voice-duration-width',
  );
  static const Key sendingStatusKey = ValueKey('message-sending-status');
  static const Key failedStatusKey = ValueKey('message-failed-status');
  static const double _mediaPreviewSize = 180;
  static const double _voiceIconLegacySize = 20;

  final Message message;
  final BaseChannel? channel;
  final ChatPageConfig config;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final ValueChanged<ChatMessageSwipeDirection>? onSwipe;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final bool multiSelectMode;
  final bool showTime;
  final Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders;

  const MessageBubble({
    super.key,
    this.channel,
    required this.message,
    required this.config,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onSwipe,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.multiSelectMode = false,
    this.showTime = false,
    this.customMessageBubbleBuilders,
  });

  @override
  Widget build(BuildContext context) {
    return _MessageBubbleBase.create(
      channel: channel,
      message: message,
      config: config,
      selected: selected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onSwipe: onSwipe,
      onAvatarTap: onAvatarTap,
      onAvatarLongPress: onAvatarLongPress,
      multiSelectMode: multiSelectMode,
      showTime: showTime,
      customMessageBubbleBuilders: customMessageBubbleBuilders,
    );
  }
}

abstract class _MessageBubbleBase extends StatelessWidget {
  final Message message;
  final BaseChannel? channel;
  final ChatPageConfig config;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final ValueChanged<ChatMessageSwipeDirection>? onSwipe;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final bool multiSelectMode;
  final bool showTime;
  final Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders;

  const _MessageBubbleBase({
    this.channel,
    required this.message,
    required this.config,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onSwipe,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.multiSelectMode = false,
    this.showTime = false,
    this.customMessageBubbleBuilders,
  });

  factory _MessageBubbleBase.create({
    BaseChannel? channel,
    required Message message,
    required ChatPageConfig config,
    bool selected = false,
    VoidCallback? onTap,
    VoidCallback? onDoubleTap,
    VoidCallback? onLongPress,
    GestureLongPressStartCallback? onLongPressStart,
    ValueChanged<ChatMessageSwipeDirection>? onSwipe,
    VoidCallback? onAvatarTap,
    VoidCallback? onAvatarLongPress,
    bool multiSelectMode = false,
    bool showTime = false,
    Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders,
  }) {
    final args = _MessageBubbleArgs(
      channel: channel,
      message: message,
      config: config,
      selected: selected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onSwipe: onSwipe,
      onAvatarTap: onAvatarTap,
      onAvatarLongPress: onAvatarLongPress,
      multiSelectMode: multiSelectMode,
      showTime: showTime,
      customMessageBubbleBuilders: customMessageBubbleBuilders,
    );
    if (message is TextMessage) return _TextMessageBubble(args);
    if (message is ReferenceMessage) return _ReferenceMessageBubble(args);
    if (message is ImageMessage || message is GIFMessage) {
      return _ImageMessageBubble(args);
    }
    if (message is HDVoiceMessage) return _VoiceMessageBubble(args);
    if (message is ShortVideoMessage) return _ShortVideoMessageBubble(args);
    if (message is FileMessage) return _FileMessageBubble(args);
    if (message is CombineMessage) return _CombineMessageBubble(args);
    if (message is LocationMessage) return _LocationMessageBubble(args);
    if (_isGroupNotificationMessage(message)) {
      return _GroupNotificationMessageBubble(args);
    }
    if (message.messageType == MessageType.recall) {
      return _RecallMessageBubble(args);
    }
    return _UnknownMessageBubble(args);
  }

  bool get usesPlainMediaPreview => false;

  bool get withoutBubble => false;

  bool get withoutStatusLine => false;

  double get verticalPadding => kBubblePaddingVertical;

  double get extraOuterVerticalPadding => 0;

  bool get isSystemChannelMessage {
    final resolvedChannelType =
        channel?.channelType ?? _safeMessageChannelType(message);
    return resolvedChannelType == ChannelType.system;
  }

  double resolvedVerticalPadding(double basePadding) {
    if (!isSystemChannelMessage) {
      return basePadding;
    }
    return basePadding + kSystemChannelMessageSpacingIncrease / 2;
  }

  ChannelType? _safeMessageChannelType(Message target) {
    try {
      return target.channelType;
    } on NoSuchMethodError {
      return null;
    }
  }

  Widget buildMessageContent(BuildContext context, MessageStyleConfig style);

  @override
  Widget build(BuildContext context) {
    final profileProvider = config.profileProvider;
    if (profileProvider == null) {
      return _buildWithProfile(context, null);
    }
    final profileChannel = channel ?? _messageChannel();
    if (profileChannel == null) {
      return _buildWithProfile(context, _profileFromMessage());
    }
    final profileCacheKey = _profileCacheKey(profileChannel);
    final cachedInitialProfile =
        _messageProfileValueCache[profileCacheKey] ?? _profileFromMessage();
    final cachedFuture = _messageProfileFutureCache.putIfAbsent(
      profileCacheKey,
      () =>
          Future<ChatProfileInfo?>.sync(
            () => profileProvider(profileChannel, message: message),
          ).then((profile) {
            _messageProfileValueCache[profileCacheKey] = profile;
            return profile;
          }),
    );
    return FutureBuilder<ChatProfileInfo?>(
      future: cachedFuture,
      initialData: cachedInitialProfile,
      builder: (context, snapshot) => _buildWithProfile(context, snapshot.data),
    );
  }

  _ImageCacheSize _previewCacheSize(BuildContext context, Size size) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    return _ImageCacheSize(
      width: size.width > 0 ? (size.width * devicePixelRatio).ceil() : null,
      height: size.height > 0 ? (size.height * devicePixelRatio).ceil() : null,
    );
  }
}

class _MessageBubbleArgs {
  final Message message;
  final BaseChannel? channel;
  final ChatPageConfig config;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final GestureLongPressStartCallback? onLongPressStart;
  final ValueChanged<ChatMessageSwipeDirection>? onSwipe;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;
  final bool multiSelectMode;
  final bool showTime;
  final Map<MessageType, ChatMessageBubbleBuilder>? customMessageBubbleBuilders;

  const _MessageBubbleArgs({
    required this.message,
    required this.channel,
    required this.config,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onLongPressStart,
    required this.onSwipe,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
    required this.multiSelectMode,
    required this.showTime,
    required this.customMessageBubbleBuilders,
  });
}

class _ImageCacheSize {
  final int? width;
  final int? height;

  const _ImageCacheSize({this.width, this.height});
}

bool _isGroupNotificationMessage(Message message) {
  if (message is GroupNotificationMessage) {
    return true;
  }
  if (message is CustomMessage) {
    return message.messageIdentifier == 'ST:GrpNtf';
  }
  return false;
}
