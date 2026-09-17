part of '../message_input_widget.dart';

extension _MessageInputMultiSelectBar on _MessageInputWidgetState {
  Widget _buildMultiSelectBar(
    BuildContext context,
    ChatProvider chat,
    NexconnThemeTokens theme,
  ) {
    final selectedCount = chat.selectedMessages.length;
    final hasSelection = selectedCount > 0;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.config.backgroundColor ?? theme.surfaceColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: SizedBox(
          height: kInputMultiSelectHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MultiSelectActionButton(
                iconName: 'NexconnLightIcon/Forward-single.png',
                label: context.chatUIL10n.chatLongPressForward,
                enabled: hasSelection,
                onTap: hasSelection
                    ? () => _chooseForwardModeAndForward(context, chat)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseForwardModeAndForward(
    BuildContext context,
    ChatProvider chat,
  ) async {
    if (chat.selectedMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.chatUIL10n.chatNoMessagesToForward)),
      );
      return;
    }
    final mode = await showModalBottomSheet<ChatForwardMode>(
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
                _ForwardModeSheetItem(
                  label: context.chatUIL10n.forwardIndividually,
                  onTap: () =>
                      Navigator.of(context).pop(ChatForwardMode.individually),
                ),
                const Divider(height: 1, color: Color(0xFFEAEAEA)),
                _ForwardModeSheetItem(
                  label: context.chatUIL10n.forwardAsCombined,
                  onTap: () =>
                      Navigator.of(context).pop(ChatForwardMode.combined),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mode == null || !context.mounted) {
      return;
    }
    await _forwardSelectedMessages(context, chat, preferredMode: mode);
  }

  Future<void> _forwardSelectedMessages(
    BuildContext context,
    ChatProvider chat, {
    ChatForwardMode? preferredMode,
  }) async {
    final selected = List<Message>.of(chat.selectedMessages);
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.chatUIL10n.chatNoMessagesToForward)),
      );
      return;
    }
    if (preferredMode == ChatForwardMode.combined &&
        ChatProvider.exceedsCombinedForwardMessageLimit(selected.length)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.chatUIL10n.chatCombinedForwardSelectionLimit(
              ChatProvider.combinedForwardMessageLimit,
            ),
          ),
        ),
      );
      return;
    }
    if (preferredMode == ChatForwardMode.combined &&
        selected.any(ChatProvider.isReferenceForwardMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.chatUIL10n.chatReferenceMessageCombinedForwardUnsupported,
          ),
        ),
      );
      return;
    }
    final injectedChannelProvider = widget.forwardChannelProviderBuilder;
    final ownsChannelProvider = injectedChannelProvider == null;
    final channelProvider =
        injectedChannelProvider?.call(context) ??
        ChannelProvider(engineProvider: context.read<EngineProvider>());
    if (injectedChannelProvider == null) {
      await channelProvider.reload();
    }
    if (!context.mounted) {
      if (ownsChannelProvider) {
        channelProvider.dispose();
      }
      return;
    }
    var forwardedToCurrentChannel = false;
    final forwarded = await pushNexconnChatUINamedRouteOr<bool>(
      context,
      NexconnChatUIRoutes.forward,
      arguments: NexconnForwardSelectRouteArguments(
        provider: channelProvider,
        messages: selected,
        initialMode: preferredMode,
        onChannelSelected: (targetChannel, mode) async {
          try {
            final result = await chat.forwardMessages(
              targetChannel,
              selected,
              mode: mode,
            );
            if (!context.mounted) {
              return false;
            }
            if (!result.hasForwarded) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.chatUIL10n.chatNoMessagesToForward),
                ),
              );
              return false;
            }
            forwardedToCurrentChannel = _isSameChannelIdentifier(
              targetChannel.channelIdentifier,
              chat.channel.channelIdentifier,
            );
            if (preferredMode == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    mode == ChatForwardMode.combined
                        ? context.chatUIL10n.chatForwardedCombined(
                            selected.length,
                          )
                        : context.chatUIL10n.chatForwarded(
                            result.forwardedCount,
                          ),
                  ),
                ),
              );
            }
            return true;
          } catch (error) {
            if (!context.mounted) {
              return false;
            }
            final message = error is NCError
                ? error.message ?? context.chatUIL10n.chatForwardFailed
                : error.toString();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
            return false;
          }
        },
      ),
      fallbackRoute: () => MaterialPageRoute<bool>(
        builder: (_) => ForwardSelectPage(
          provider: channelProvider,
          messages: selected,
          initialMode: preferredMode,
          onChannelSelected: (targetChannel, mode) async {
            try {
              final result = await chat.forwardMessages(
                targetChannel,
                selected,
                mode: mode,
              );
              if (!context.mounted) {
                return false;
              }
              if (!result.hasForwarded) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.chatUIL10n.chatNoMessagesToForward),
                  ),
                );
                return false;
              }
              forwardedToCurrentChannel = _isSameChannelIdentifier(
                targetChannel.channelIdentifier,
                chat.channel.channelIdentifier,
              );
              if (preferredMode == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      mode == ChatForwardMode.combined
                          ? context.chatUIL10n.chatForwardedCombined(
                              selected.length,
                            )
                          : context.chatUIL10n.chatForwarded(
                              result.forwardedCount,
                            ),
                    ),
                  ),
                );
              }
              return true;
            } catch (error) {
              if (!context.mounted) {
                return false;
              }
              final message = error is NCError
                  ? error.message ?? context.chatUIL10n.chatForwardFailed
                  : error.toString();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
              return false;
            }
          },
        ),
      ),
    );
    if (ownsChannelProvider) {
      channelProvider.dispose();
    }
    if (forwarded != null) {
      chat.setMultiSelectMode(false);
      if (forwardedToCurrentChannel) {
        _scheduleScrollCurrentChatToBottom(chat);
      }
    }
  }

  void _scheduleScrollCurrentChatToBottom(ChatProvider chat) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messageListController = context.read<MessageListController?>();
      if (messageListController != null) {
        unawaited(messageListController.scrollToBottom());
        return;
      }
      unawaited(_jumpCurrentChatToBottom(chat, 4));
    });
  }

  Future<void> _jumpCurrentChatToBottom(
    ChatProvider chat,
    int retriesLeft,
  ) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    if (!chat.scrollController.hasClients) {
      if (retriesLeft > 0) {
        await _jumpCurrentChatToBottom(chat, retriesLeft - 1);
      }
      return;
    }
    final position = chat.scrollController.position.maxScrollExtent;
    chat.scrollController.jumpTo(position);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !chat.scrollController.hasClients) {
      return;
    }
    final maxExtent = chat.scrollController.position.maxScrollExtent;
    if ((maxExtent - chat.scrollController.offset).abs() <= 1) {
      return;
    }
    chat.scrollController.jumpTo(maxExtent);
    if (retriesLeft > 0) {
      await _jumpCurrentChatToBottom(chat, retriesLeft - 1);
    }
  }

  bool _isSameChannelIdentifier(ChannelIdentifier a, ChannelIdentifier b) {
    return a.channelType == b.channelType &&
        a.channelId == b.channelId &&
        _normalizedSubChannelId(a.subChannelId) ==
            _normalizedSubChannelId(b.subChannelId);
  }

  String? _normalizedSubChannelId(String? subChannelId) {
    return subChannelId == null || subChannelId.isEmpty ? null : subChannelId;
  }
}

class _ForwardModeSheetItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ForwardModeSheetItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectActionButton extends StatelessWidget {
  final String iconName;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _MultiSelectActionButton({
    required this.iconName,
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final resolvedIconColor = enabled
        ? null
        : theme.secondaryTextColor.withValues(alpha: .7);
    final resolvedTextColor = enabled
        ? theme.primaryTextColor
        : theme.secondaryTextColor.withValues(alpha: .85);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChatUIAsset.image(
              iconName,
              width: kInputMultiSelectButtonHeight,
              height: kInputMultiSelectButtonHeight,
              color: resolvedIconColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: kInputMultiSelectButtonFontSize,
                color: resolvedTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
