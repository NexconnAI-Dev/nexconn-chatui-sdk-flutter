part of '../message_bubble.dart';

extension _MessageBubbleProfile on _MessageBubbleBase {
  Widget _avatar(BuildContext context, ChatProfileInfo? profile) {
    final avatar = config.bubbleConfig.avatarConfig;
    final imageUrl = _profileAvatar(profile);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: ChatUIAsset.provider(_fallbackAvatarAsset()),
          fit: BoxFit.cover,
        ),
      ),
    );
    final child = SizedBox.square(
      dimension: avatar.size,
      child: imageUrl != null && imageUrl.startsWith('http')
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
    final clipped = avatar.shape == ChatAvatarShape.circle
        ? ClipOval(child: child)
        : ClipRRect(borderRadius: avatar.effectiveBorderRadius, child: child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAvatarTap,
      onLongPress: onAvatarLongPress,
      child: clipped,
    );
  }

  String _fallbackAvatarAsset() {
    ChannelType? type;
    try {
      type = message.channelType;
    } catch (_) {
      type = null;
    }
    return switch (type) {
      ChannelType.system || ChannelType.open => 'avatar_default_system.png',
      _ => 'avatar_default_single.png',
    };
  }

  BaseChannel? _messageChannel() {
    ChannelType? type;
    String? id;
    try {
      type = message.channelType;
      id = message.channelId;
    } catch (_) {
      return null;
    }
    if (type == null || id == null || id.isEmpty) {
      return null;
    }
    return BaseChannel(type, id);
  }

  ChatProfileInfo? _profileFromMessage() {
    try {
      final userInfo = message.userInfo;
      if (userInfo == null) {
        return null;
      }
      return ChatProfileInfo(
        id: userInfo.userId ?? message.senderUserId ?? '',
        name: userInfo.alias ?? userInfo.name,
        portraitUri: userInfo.avatarUrl,
        extra: userInfo.extra,
      );
    } catch (_) {
      return null;
    }
  }

  String? _profileAvatar(ChatProfileInfo? profile) {
    final resolvedAvatar = profile?.portraitUri?.trim();
    if (resolvedAvatar != null && resolvedAvatar.isNotEmpty) {
      return resolvedAvatar;
    }
    try {
      return message.userInfo?.avatarUrl;
    } catch (_) {
      return null;
    }
  }

  String _profileCacheKey(BaseChannel channel) {
    final senderId = message.senderUserId?.trim();
    final userInfoId = message.userInfo?.userId?.trim();
    final resolvedUserId = senderId?.isNotEmpty == true
        ? senderId!
        : userInfoId?.isNotEmpty == true
        ? userInfoId!
        : 'unknown';
    final subChannelId = channel.channelIdentifier.subChannelId;
    return [
      channel.channelType.name,
      channel.channelId,
      if (subChannelId != null && subChannelId.isNotEmpty) subChannelId,
      resolvedUserId,
    ].join('#');
  }

  bool get _isRecallMessage => isDeleteForAllPlaceholderMessage(message);

  ChatMessageBubbleBuilder? get _customBubbleBuilder {
    final type = message.messageType;
    if (type == null) {
      return null;
    }
    final builders =
        customMessageBubbleBuilders ?? config.customMessageBubbleBuilders;
    return builders?[type];
  }
}
