part of '../channel_item.dart';

class _ChannelSwipeActionHost extends StatefulWidget {
  final BaseChannel channel;
  final ChannelSwipeActionsConfig config;
  final ValueChanged<ChannelActionType> onAction;
  final Widget child;

  const _ChannelSwipeActionHost({
    required this.channel,
    required this.config,
    required this.onAction,
    required this.child,
  });

  @override
  State<_ChannelSwipeActionHost> createState() =>
      _ChannelSwipeActionHostState();
}

class _ChannelSwipeActionHostState extends State<_ChannelSwipeActionHost> {
  static final ValueNotifier<String?> _openedChannelKey =
      ValueNotifier<String?>(null);
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _openedChannelKey.addListener(_handleOpenedChannelKeyChanged);
  }

  @override
  void dispose() {
    _openedChannelKey.removeListener(_handleOpenedChannelKeyChanged);
    if (_openedChannelKey.value == _channelSwipeKey) {
      _openedChannelKey.value = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _effectiveActions();
    if (actions.isEmpty) {
      return widget.child;
    }
    final maxExtent = actions.length * widget.config.actionWidth;
    final offset = _dragOffset.clamp(-maxExtent, 0).toDouble();
    return ClipRect(
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned.fill(
            child: Row(
              children: [const Spacer(), ...actions.map(_actionButton)],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              final nextOffset = (_dragOffset + details.delta.dx).clamp(
                -maxExtent,
                0,
              );
              if (nextOffset < 0 &&
                  _openedChannelKey.value != _channelSwipeKey) {
                _openedChannelKey.value = _channelSwipeKey;
              }
              setState(() {
                _dragOffset = nextOffset.toDouble();
              });
            },
            onHorizontalDragEnd: (_) {
              final shouldOpen =
                  _dragOffset.abs() >=
                  maxExtent * widget.config.revealThreshold;
              _openedChannelKey.value = shouldOpen ? _channelSwipeKey : null;
              setState(() {
                _dragOffset = shouldOpen ? -maxExtent : 0;
              });
            },
            child: Transform.translate(
              offset: Offset(offset, 0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  String get _channelSwipeKey {
    final subChannelId = widget.channel.channelIdentifier.subChannelId;
    final normalizedSubChannelId = subChannelId == null || subChannelId.isEmpty
        ? ''
        : subChannelId;
    return '${widget.channel.channelType.name}:${widget.channel.channelId}:$normalizedSubChannelId';
  }

  void _handleOpenedChannelKeyChanged() {
    if (!mounted ||
        _dragOffset == 0 ||
        _openedChannelKey.value == _channelSwipeKey) {
      return;
    }
    setState(() {
      _dragOffset = 0;
    });
  }

  List<ChannelActionType> _effectiveActions() {
    return widget.config.actions.take(3).map((action) {
      return switch (action) {
        ChannelActionType.pin =>
          (widget.channel.isPinned ?? false)
              ? ChannelActionType.unpin
              : ChannelActionType.pin,
        ChannelActionType.mute =>
          widget.channel.notificationLevel == ChannelNoDisturbLevel.blocked
              ? ChannelActionType.unmute
              : ChannelActionType.mute,
        _ => action,
      };
    }).toList();
  }

  Widget _actionButton(ChannelActionType action) {
    final backgroundColor =
        widget.config.backgroundColors[action] ?? const Color(0xFF8E8E93);
    return SizedBox(
      width: widget.config.actionWidth,
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: () {
            widget.onAction(action);
            _openedChannelKey.value = null;
            setState(() {
              _dragOffset = 0;
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionIcon(action),
              const SizedBox(height: 4),
              Text(
                widget.config.labels[action] ?? action.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.config.foregroundColor,
                  fontSize: 12,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionIcon(ChannelActionType action) {
    return Icon(
      widget.config.icons[action] ?? Icons.more_horiz,
      size: 30,
      color: widget.config.foregroundColor,
    );
  }
}
