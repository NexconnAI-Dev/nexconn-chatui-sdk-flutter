part of '../channel_item.dart';

extension _ChannelItemAvatarHelpers on ChannelItem {
  String get _typedProfileKey =>
      '${channel.channelType.name}:${channel.channelId}';

  Widget _avatarImage(ChannelDisplayProfile? displayProfile, String label) {
    final avatarUrl = displayProfile?.avatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackAvatar(displayProfile, label),
      );
    }
    final assetName = displayProfile?.avatarAssetName ?? _configuredAssetName;
    if (assetName != null && assetName.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ChatUIAsset.image(assetName, fit: BoxFit.cover),
          Opacity(
            opacity: 0,
            child: Center(child: Text(_avatarInitial(label))),
          ),
        ],
      );
    }
    return _fallbackAvatar(displayProfile, label);
  }

  Widget _fallbackAvatar(ChannelDisplayProfile? displayProfile, String label) {
    if (displayProfile?.avatarFallback != null) {
      return displayProfile!.avatarFallback!;
    }
    if (config.useDefaultAvatarAsset) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ChatUIAsset.image(
            _defaultAvatarAsset(channel.channelType),
            fit: BoxFit.cover,
          ),
          Opacity(
            opacity: 0,
            child: Center(child: Text(_avatarInitial(label))),
          ),
        ],
      );
    }
    return Container(
      color: _avatarColor(channel.channelType),
      alignment: Alignment.center,
      child: Text(
        _avatarInitial(label),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }

  String? get _configuredAssetName {
    return switch (channel.channelType) {
      ChannelType.direct => config.directChannelAvatarAssetName,
      ChannelType.group ||
      ChannelType.community => config.groupChannelAvatarAssetName,
      ChannelType.system ||
      ChannelType.open => config.systemChannelAvatarAssetName,
    };
  }

  Color _avatarColor(ChannelType type) {
    switch (type) {
      case ChannelType.direct:
        return const Color(0xFF147BFF);
      case ChannelType.group:
        return const Color(0xFF18A058);
      case ChannelType.open:
        return const Color(0xFF7C3AED);
      case ChannelType.community:
        return const Color(0xFFE67E22);
      case ChannelType.system:
        return const Color(0xFF6B7280);
    }
  }

  String _defaultAvatarAsset(ChannelType type) {
    return switch (type) {
      ChannelType.group || ChannelType.community => 'avatar_default_group.png',
      ChannelType.system || ChannelType.open => 'avatar_default_system.png',
      ChannelType.direct => 'avatar_default_single.png',
    };
  }

  String _avatarInitial(String label) {
    return label.isNotEmpty ? label.characters.first.toUpperCase() : '#';
  }

  ChannelOnlineStatus? _onlineStatus(BuildContext context) {
    if (!config.showDirectChannelOnlineStatus ||
        channel.channelType != ChannelType.direct) {
      return null;
    }
    final status =
        config.onlineStatusProvider?.call(channel) ??
        context.read<ChannelProvider?>()?.onlineStatusOf(channel) ??
        ChannelOnlineStatus.unknown;
    return status == ChannelOnlineStatus.unknown ? null : status;
  }

  Widget _defaultOnlineStatusBadge(ChannelOnlineStatus status) {
    final color = switch (status) {
      ChannelOnlineStatus.online => const Color(0xFF22C55E),
      ChannelOnlineStatus.offline => const Color(0xFF9CA3AF),
      ChannelOnlineStatus.unknown => Colors.transparent,
    };
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
