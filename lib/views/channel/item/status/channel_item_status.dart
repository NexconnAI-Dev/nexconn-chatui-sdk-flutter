part of '../channel_item.dart';

extension _ChannelItemStatus on ChannelItem {
  bool _shouldShowTransientReadStatus(BuildContext context) {
    if (_hasDraft) {
      return false;
    }
    final status = _readStatus(context);
    return status == ChannelReadStatus.sending ||
        status == ChannelReadStatus.failed;
  }

  Widget _readStatusIndicator(BuildContext context) {
    final status = _readStatus(context);
    if (status == null) {
      return const SizedBox.shrink();
    }
    final custom = config.readStatusBuilder?.call(context, channel, status);
    if (custom != null) {
      return Padding(padding: const EdgeInsets.only(right: 4), child: custom);
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: switch (status) {
        ChannelReadStatus.sending => const KeyedSubtree(
          key: ValueKey('channel-read-status-sending'),
          child: _RotatingChannelStatusAsset(
            assetName: 'messageSending.png',
            size: 14,
          ),
        ),
        ChannelReadStatus.failed => KeyedSubtree(
          key: const ValueKey('channel-read-status-failed'),
          child: ChatUIAsset.image(
            'messageSendFail.png',
            width: 14,
            height: 14,
          ),
        ),
        _ => Text(
          _readStatusText(context, status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      },
    );
  }

  ChannelReadStatus? _readStatus(BuildContext context) {
    if (_hasDraft) {
      return null;
    }
    final message = channel.latestMessage;
    if (message == null || _directionOf(message) != MessageDirection.send) {
      return null;
    }
    final engineProvider = _maybeEngineProvider(context, listen: true);
    if (engineProvider?.isFailedMessage(message) == true) {
      return ChannelReadStatus.failed;
    }
    switch (_sentStatusOf(message)) {
      case SentStatus.sending:
        return ChannelReadStatus.sending;
      case SentStatus.failed:
      case SentStatus.canceled:
        return ChannelReadStatus.failed;
      case SentStatus.sent:
        if (channel.channelType != ChannelType.direct) {
          return null;
        }
        return ChannelReadStatus.sent;
      case SentStatus.received:
        if (channel.channelType != ChannelType.direct) {
          return null;
        }
        return ChannelReadStatus.delivered;
      case SentStatus.read:
      case SentStatus.destroyed:
        if (channel.channelType != ChannelType.direct) {
          return null;
        }
        return ChannelReadStatus.read;
      case null:
        if (channel.channelType != ChannelType.direct) {
          return null;
        }
        if (message.receivedStatusInfo?.read == true ||
            _receivedStatusOf(message) == ReceivedStatus.read) {
          return ChannelReadStatus.read;
        }
        return null;
    }
  }

  EngineProvider? _maybeEngineProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<EngineProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  MessageDirection? _directionOf(Message message) {
    try {
      return message.direction;
    } on NoSuchMethodError {
      return null;
    }
  }

  SentStatus? _sentStatusOf(Message message) {
    try {
      return message.sentStatus;
    } on NoSuchMethodError {
      return null;
    }
  }

  ReceivedStatus? _receivedStatusOf(Message message) {
    try {
      return message.receivedStatus;
    } on NoSuchMethodError {
      return null;
    }
  }

  String _readStatusText(BuildContext context, ChannelReadStatus status) {
    switch (status) {
      case ChannelReadStatus.sending:
        return context.chatUIL10n.channelReadStatusSending;
      case ChannelReadStatus.failed:
        return context.chatUIL10n.channelReadStatusFailed;
      case ChannelReadStatus.sent:
        return context.chatUIL10n.channelReadStatusSent;
      case ChannelReadStatus.delivered:
        return context.chatUIL10n.channelReadStatusDelivered;
      case ChannelReadStatus.read:
        return context.chatUIL10n.channelReadStatusRead;
    }
  }

  Widget _notificationLevelIndicator(BuildContext context) {
    final custom = config.notificationLevelBuilder?.call(
      context,
      channel,
      channel.notificationLevel,
    );
    if (custom != null) {
      return custom;
    }
    final level = channel.notificationLevel;
    if (level == ChannelNoDisturbLevel.blocked) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ChatUIAsset.image(
          'NexconnLightIcon/Do-not-disturb-1.png',
          width: 16,
          height: 16,
          color: const Color(0xFFC1C1C1),
        ),
      );
    }
    final assetName = _notificationIconAsset(level);
    if (assetName == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: ChatUIAsset.image(
        assetName,
        width: 16,
        height: 16,
        color: Colors.grey[500],
      ),
    );
  }

  String? _notificationIconAsset(ChannelNoDisturbLevel? level) {
    switch (level) {
      case ChannelNoDisturbLevel.blocked:
        return 'NexconnLightIcon/Do-not-disturb-1.png';
      case ChannelNoDisturbLevel.mention:
      case ChannelNoDisturbLevel.mentionUsers:
      case ChannelNoDisturbLevel.mentionAll:
        return 'NexconnLightIcon/Attention.png';
      case ChannelNoDisturbLevel.allMessage:
      case ChannelNoDisturbLevel.none:
      case null:
        return null;
    }
  }

  bool get _isNotificationMuted =>
      channel.notificationLevel == ChannelNoDisturbLevel.blocked;

  bool get _hasDraft {
    final draft = channel.draft?.trim();
    return draft != null && draft.isNotEmpty;
  }
}

class _RotatingChannelStatusAsset extends StatefulWidget {
  const _RotatingChannelStatusAsset({
    required this.assetName,
    required this.size,
  });

  final String assetName;
  final double size;

  @override
  State<_RotatingChannelStatusAsset> createState() =>
      _RotatingChannelStatusAssetState();
}

class _RotatingChannelStatusAssetState
    extends State<_RotatingChannelStatusAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: ChatUIAsset.image(
        widget.assetName,
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
