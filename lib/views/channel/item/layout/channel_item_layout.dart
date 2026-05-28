part of '../channel_item.dart';

extension _ChannelItemLayout on ChannelItem {
  Widget _buildItem(
    BuildContext context,
    ChannelDisplayProfile? displayProfile,
  ) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final content = InkWell(
      onTap: () => onTap?.call(channel, index, context),
      onLongPress: () => onLongPress?.call(channel, index, context),
      child: Container(
        constraints: const BoxConstraints(minHeight: channelItemHeight),
        padding: channelItemPadding,
        decoration: BoxDecoration(
          color: highlighted
              ? config.longPressBackgroundColor ?? const Color(0xFFDBE0EF)
              : (channel.isPinned ?? false)
              ? config.pinnedBackgroundColor ?? const Color(0xFFEFF1F7)
              : config.backgroundColor ?? theme.panelColor,
        ),
        child: Row(
          children: [
            _avatar(context, displayProfile),
            const SizedBox(width: 16),
            Expanded(child: _content(context, displayProfile)),
            const SizedBox(width: 16),
            _trailing(context),
          ],
        ),
      ),
    );
    if (!config.swipeActionsConfig.enabled || onAction == null) {
      return content;
    }
    return _ChannelSwipeActionHost(
      channel: channel,
      config: config.swipeActionsConfig,
      onAction: (action) => onAction!(context, channel, action),
      child: content,
    );
  }

  Widget _content(BuildContext context, ChannelDisplayProfile? displayProfile) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child:
                  config.titleBuilder?.call(
                    context,
                    channel,
                    displayProfile,
                    config,
                  ) ??
                  Text(
                    _title(context, displayProfile),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        config.titleStyle ??
                        theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: convoTitleFontSize,
                          fontWeight: FontWeight.normal,
                        ),
                  ),
            ),
            if (config.showPinnedIndicator && (channel.isPinned ?? false))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ChatUIAsset.image(
                  'NexconnLightIcon/Pin.png',
                  width: 16,
                  height: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            if (config.showNotificationLevelIndicator)
              _notificationLevelIndicator(context),
          ],
        ),
        if (config.showLastMessage) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (config.showReadStatus ||
                  _shouldShowTransientReadStatus(context))
                _readStatusIndicator(context),
              Expanded(
                child:
                    config.lastMessageBuilder?.call(context, channel, config) ??
                    _buildLastMessage(context, theme),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLastMessage(BuildContext context, ThemeData theme) {
    final baseStyle =
        config.lastMessageStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF999999),
          fontSize: convoLastFontSize,
        );
    final showUnreadMentionPrefix = _shouldShowUnreadMentionPrefix;
    if (showUnreadMentionPrefix) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${context.chatUIL10n.channelUnreadMentionPrefix} ',
              style: baseStyle?.copyWith(color: const Color(0xFFFF3B30)),
            ),
            TextSpan(
              text: _lastMessageText(context, includeDraft: false),
              style: baseStyle,
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final draft = channel.draft?.trim();
    if (draft == null || draft.isEmpty) {
      return Text(
        _lastMessageText(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }
    final prefix = _draftPrefix(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: baseStyle?.copyWith(color: const Color(0xFFFF3B30)),
          ),
          TextSpan(text: draft, style: baseStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _trailing(BuildContext context) {
    final unreadCount = channel.unreadCount ?? 0;
    final unreadWidth = unreadCount > 99
        ? unreadBubbleWidth
        : unreadCount > 9
        ? unreadBubbleWidth * 0.7
        : unreadBubbleWidth / 2;
    final serverNow = _serverNow(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (config.showTime)
          config.timeBuilder?.call(context, channel, config) ??
              Text(
                TimeUtil.formatChannelTime(
                  channel.latestMessage?.sentTime ?? channel.operationTime,
                  now: serverNow,
                  l10n: context.chatUIL10n,
                ),
                style:
                    config.timeStyle ??
                    Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFCCCCCC),
                      fontSize: convoAuxiliaryFontSize,
                      fontWeight: FontWeight.normal,
                    ),
              ),
        if (config.showUnreadBadge && unreadCount > 0) ...[
          const SizedBox(height: 8),
          config.unreadBadgeBuilder?.call(
                context,
                channel,
                unreadCount,
                config,
              ) ??
              SizedBox(
                width: unreadWidth,
                height: 21,
                child: Container(
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _isNotificationMuted
                        ? const Color(0xFFC1C1C1)
                        : const Color(0xFFFF3B30),
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: convoUnreadFontSize,
                      fontWeight: convoUnreadFontWeight,
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  String _title(BuildContext context, ChannelDisplayProfile? displayProfile) {
    final displayName = displayProfile?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    switch (channel.channelType) {
      case ChannelType.direct:
        return channel.channelId;
      case ChannelType.group:
        return context.chatUIL10n.channelGroupTitle(channel.channelId);
      case ChannelType.open:
        return context.chatUIL10n.channelOpenTitle(channel.channelId);
      case ChannelType.community:
        return context.chatUIL10n.channelCommunityTitle(channel.channelId);
      case ChannelType.system:
        return context.chatUIL10n.channelSystemTitle;
    }
  }

  bool get _shouldShowUnreadMentionPrefix {
    final hasUnreadMention =
        (channel.mentionedCount ?? 0) > 0 ||
        (channel.mentionedMeCount ?? 0) > 0;
    return channel.channelType == ChannelType.group &&
        (channel.unreadCount ?? 0) > 0 &&
        hasUnreadMention;
  }

  String _lastMessageText(BuildContext context, {bool includeDraft = true}) {
    final draft = channel.draft?.trim();
    if (includeDraft && draft != null && draft.isNotEmpty) {
      return context.chatUIL10n.channelDraftPrefix(draft);
    }
    String? currentUserId;
    try {
      currentUserId = context.read<EngineProvider>().currentUserId;
    } on ProviderNotFoundException {
      currentUserId = null;
    }
    return channelListMessageSummary(
      channel.latestMessage,
      localizations: context.chatUIL10n,
      channelType: channel.channelType,
      currentUserId: currentUserId,
    );
  }

  ChannelDisplayProfile? _profileFromConfig() {
    return config.displayProfiles[_typedProfileKey] ??
        config.displayProfiles[channel.channelId];
  }

  String _draftPrefix(BuildContext context) {
    const sentinel = '\u0000';
    return context.chatUIL10n
        .channelDraftPrefix(sentinel)
        .replaceFirst(sentinel, '');
  }

  DateTime? _serverNow(BuildContext context) {
    try {
      return context.watch<EngineProvider>().serverNow;
    } on ProviderNotFoundException {
      return null;
    }
  }
}
