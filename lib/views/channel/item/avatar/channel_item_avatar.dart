part of '../channel_item.dart';

extension _ChannelItemAvatar on ChannelItem {
  Widget _avatar(BuildContext context, ChannelDisplayProfile? displayProfile) {
    final label = _title(context, displayProfile);
    final avatarContent =
        config.avatarBuilder?.call(context, channel, displayProfile, config) ??
        _clipAvatar(
          SizedBox.square(
            dimension: channelAvatarSize,
            child: _avatarImage(displayProfile, label),
          ),
        );
    final avatar = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAvatarTap == null
          ? null
          : () => onAvatarTap!.call(channel, index, context),
      onLongPress: onAvatarLongPress == null
          ? null
          : () => onAvatarLongPress!.call(channel, index, context),
      child: avatarContent,
    );
    final onlineStatus = _onlineStatus(context);
    if (onlineStatus == null) {
      return avatar;
    }
    return SizedBox(
      width: channelAvatarSize,
      height: channelAvatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child:
                config.onlineStatusBuilder?.call(
                  context,
                  channel,
                  onlineStatus,
                ) ??
                _defaultOnlineStatusBadge(onlineStatus),
          ),
        ],
      ),
    );
  }

  Widget _clipAvatar(Widget child) {
    switch (config.avatarShape) {
      case ChannelAvatarShape.circle:
        return ClipOval(child: child);
      case ChannelAvatarShape.rectangle:
        return ClipRRect(borderRadius: BorderRadius.zero, child: child);
      case ChannelAvatarShape.roundedRectangle:
        return ClipRRect(
          borderRadius: BorderRadius.circular(config.avatarRadius),
          child: child,
        );
    }
  }
}
