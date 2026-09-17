import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../providers/channel_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/chatui_asset.dart';

/// Lets the user choose a target channel for message forwarding.
class ForwardSelectPage extends StatefulWidget {
  final ChannelProvider provider;
  final List<Message> messages;
  final ChatForwardMode? initialMode;
  final Future<bool> Function(BaseChannel channel, ChatForwardMode mode)
  onChannelSelected;

  const ForwardSelectPage({
    super.key,
    required this.provider,
    required this.messages,
    this.initialMode,
    required this.onChannelSelected,
  });

  @override
  State<ForwardSelectPage> createState() => _ForwardSelectPageState();
}

class _ForwardSelectPageState extends State<ForwardSelectPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  bool _isForwarding = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final keyword = _searchController.text.trim().toLowerCase();
      if (keyword == _keyword) {
        return;
      }
      setState(() => _keyword = keyword);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6FA),
        foregroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: ChatUIAsset.image(
            'NexconnLightIcon/Left-arrow.png',
            width: 24,
            height: 24,
            color: const Color(0xFF111111),
          ),
          onPressed: _isForwarding
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.chatUIL10n.forwardSelectTitle(widget.messages.length),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEAEAEA)),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.provider,
        builder: (context, _) {
          final channels = _filteredChannels(widget.provider.channels);
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: channels.isEmpty
                        ? _ForwardEmptyState(
                            text: _keyword.isEmpty
                                ? context.chatUIL10n.forwardNoChannels
                                : context.chatUIL10n.searchNoMatchingMessages,
                          )
                        : ListView.builder(
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final channel = channels[index];
                              return _ForwardChannelTile(
                                channel: channel,
                                onTap: _isForwarding
                                    ? null
                                    : () => _handleChannelSelected(channel),
                              );
                            },
                          ),
                  ),
                ],
              ),
              if (_isForwarding)
                Container(
                  color: Colors.black.withValues(alpha: 0.12),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  List<BaseChannel> _filteredChannels(List<BaseChannel> channels) {
    if (_keyword.isEmpty) {
      return channels;
    }
    return channels.where((channel) {
      final title = _channelTitle(channel).toLowerCase();
      final type = channel.channelType.name.toLowerCase();
      return title.contains(_keyword) || type.contains(_keyword);
    }).toList();
  }

  Future<void> _handleChannelSelected(BaseChannel channel) async {
    final mode = await _resolveForwardMode(context);
    if (mode == null || !mounted) {
      return;
    }
    final confirmed = await _confirmForward(channel, mode);
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _isForwarding = true);
    try {
      final shouldClose = await widget.onChannelSelected(channel, mode);
      if (shouldClose && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.chatUIL10n.chatForwardFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isForwarding = false);
      }
    }
  }

  Future<bool> _confirmForward(
    BaseChannel channel,
    ChatForwardMode mode,
  ) async {
    final modeLabel = mode == ChatForwardMode.combined
        ? context.chatUIL10n.forwardAsCombined
        : context.chatUIL10n.forwardIndividually;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.chatUIL10n.forwardConfirmTitle),
            content: Text(
              context.chatUIL10n.forwardConfirmMessage(
                widget.messages.length,
                _channelTitle(channel),
                modeLabel,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.chatUIL10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.chatUIL10n.commonConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<ChatForwardMode?> _resolveForwardMode(BuildContext context) async {
    if (widget.initialMode != null) {
      return widget.initialMode;
    }
    if (widget.messages.length <= 1) {
      return ChatForwardMode.individually;
    }
    return showModalBottomSheet<ChatForwardMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionSheetItem(
                  label: context.chatUIL10n.forwardIndividually,
                  onTap: () =>
                      Navigator.of(context).pop(ChatForwardMode.individually),
                ),
                const Divider(height: 1, color: Color(0xFFEAEAEA)),
                _ActionSheetItem(
                  label: context.chatUIL10n.forwardAsCombined,
                  onTap: () =>
                      Navigator.of(context).pop(ChatForwardMode.combined),
                ),
                const Divider(
                  height: 8,
                  thickness: 8,
                  color: Color(0xFFF5F6FA),
                ),
                _ActionSheetItem(
                  label: context.chatUIL10n.commonCancel,
                  isCancel: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ForwardChannelTile extends StatelessWidget {
  final BaseChannel channel;
  final VoidCallback? onTap;

  const _ForwardChannelTile({required this.channel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = _channelTitle(channel);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        color: Colors.white,
        child: Row(
          children: [
            _ChannelAvatar(channel: channel, title: title),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelAvatar extends StatelessWidget {
  final BaseChannel channel;
  final String title;

  const _ChannelAvatar({required this.channel, required this.title});

  @override
  Widget build(BuildContext context) {
    final isGroup = channel.channelType == ChannelType.group;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGroup
              ? const [Color(0xFF7DC8FF), Color(0xFF3D6DCC)]
              : const [Color(0xFFFFC36D), Color(0xFFFF8B4D)],
        ),
      ),
      alignment: Alignment.center,
      child: ChatUIAsset.image(
        isGroup
            ? 'NexconnLightIcon/Group-default-avatar.png'
            : 'NexconnLightIcon/User-default-avatar.png',
        color: Colors.white,
        width: 22,
        height: 22,
      ),
    );
  }
}

class _ActionSheetItem extends StatelessWidget {
  final String label;
  final bool isCancel;
  final VoidCallback onTap;

  const _ActionSheetItem({
    required this.label,
    required this.onTap,
    this.isCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isCancel
                  ? const Color(0xFF666666)
                  : const Color(0xFF111111),
              fontSize: 17,
              fontWeight: isCancel ? FontWeight.normal : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ForwardEmptyState extends StatelessWidget {
  final String text;

  const _ForwardEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/No-messages.png',
            width: 44,
            height: 44,
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Color(0xFF999999))),
        ],
      ),
    );
  }
}

String _channelTitle(BaseChannel channel) {
  final latestName = channel.latestMessage?.senderUserId;
  if (channel.channelId.isNotEmpty) {
    return channel.channelId;
  }
  if (latestName?.isNotEmpty == true) {
    return latestName!;
  }
  return channel.channelType.name;
}
