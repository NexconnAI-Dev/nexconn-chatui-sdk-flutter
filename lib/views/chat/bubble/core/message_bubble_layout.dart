part of '../message_bubble.dart';

extension _MessageBubbleLayout on _MessageBubbleBase {
  Widget _buildWithProfile(BuildContext context, ChatProfileInfo? profile) {
    final customBuilder = _customBubbleBuilder;
    if (this is _InformationNotificationMessageBubble &&
        customBuilder == null) {
      final style = config.bubbleConfig.receivedStyle;
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: resolvedVerticalPadding(extraOuterVerticalPadding),
        ),
        child: buildMessageContent(context, style),
      );
    }
    if (this is _GroupNotificationMessageBubble && customBuilder == null) {
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: resolvedVerticalPadding(extraOuterVerticalPadding),
        ),
        child: _groupNotificationTip(context),
      );
    }
    if (this is _RecallMessageBubble && customBuilder == null) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: resolvedVerticalPadding(verticalPadding),
        ),
        child: Center(
          child: Text(
            messageSummary(message, localizations: context.chatUIL10n),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF8C919C)),
          ),
        ),
      );
    }
    final sent = message.direction == MessageDirection.send;
    final style = sent
        ? config.bubbleConfig.sentStyle
        : config.bubbleConfig.receivedStyle;
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onLongPressStart: onLongPressStart,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTime) _timeSeparator(context),
          if (multiSelectMode)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: kBubbleMultiSelectIconPaddingLeft,
                    right: kBubbleMultiSelectIconPaddingRight,
                  ),
                  child: _multiSelectIcon(),
                ),
                Expanded(
                  child: _messageRow(
                    context,
                    profile,
                    customBuilder,
                    sent,
                    style,
                  ),
                ),
              ],
            )
          else
            _messageRow(context, profile, customBuilder, sent, style),
        ],
      ),
    );
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final callback = onSwipe;
    if (callback == null) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    if (velocity == 0) {
      return;
    }
    callback(
      velocity < 0
          ? ChatMessageSwipeDirection.left
          : ChatMessageSwipeDirection.right,
    );
  }

  Widget _messageRow(
    BuildContext context,
    ChatProfileInfo? profile,
    ChatMessageBubbleBuilder? customBuilder,
    bool sent,
    MessageStyleConfig style,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: resolvedVerticalPadding(verticalPadding),
      ),
      child: Row(
        mainAxisAlignment: sent
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!sent && config.messageListConfig.showAvatar)
            Padding(
              padding: const EdgeInsets.only(right: kBubbleAvatarPadding),
              child: _avatar(context, profile),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: sent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (config.messageListConfig.showSenderName)
                  SizedBox(
                    height: kBubbleNameFontSize + 6,
                    child: Align(
                      alignment: sent
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        _senderName(profile),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[600],
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                _bubbleContentRow(context, style, customBuilder, sent),
                if (_messageEditStatusAppend(context) case final status?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: status,
                  ),
              ],
            ),
          ),
          if (sent && config.messageListConfig.showAvatar)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kBubbleAvatarPadding,
              ),
              child: _avatar(context, profile),
            ),
        ],
      ),
    );
  }

  bool _usesPlainMediaPreview(ChatMessageBubbleBuilder? customBuilder) {
    if (customBuilder != null) {
      return false;
    }
    return usesPlainMediaPreview;
  }

  Widget _bubbleContentRow(
    BuildContext context,
    MessageStyleConfig style,
    ChatMessageBubbleBuilder? customBuilder,
    bool sent,
  ) {
    final voiceDownloadIndicator = _voiceBubbleDownloadIndicator(context);
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _bubbleMaxWidth(context)),
      child: _usesPlainMediaPreview(customBuilder) || withoutBubble
          ? _content(context, style, customBuilder)
          : DecoratedBox(
              decoration: BoxDecoration(
                color: style.backgroundColor,
                borderRadius: BorderRadius.circular(
                  config.bubbleConfig.borderRadius,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _content(context, style, customBuilder),
              ),
            ),
    );
    final statusIndicator = _sendStatusIndicator(context, sent);
    if (statusIndicator == null) {
      if (voiceDownloadIndicator == null) {
        return bubble;
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: sent
            ? [
                voiceDownloadIndicator,
                const SizedBox(width: 6),
                Flexible(child: bubble),
              ]
            : [
                Flexible(child: bubble),
                const SizedBox(width: 6),
                voiceDownloadIndicator,
              ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      // 与气泡底边平行对齐（对齐 IMKit 已读状态 V5 布局）。
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (sent) ...[
          statusIndicator,
          if (voiceDownloadIndicator != null) ...[
            voiceDownloadIndicator,
            const SizedBox(width: 6),
          ],
          Flexible(child: bubble),
        ] else ...[
          Flexible(child: bubble),
          if (voiceDownloadIndicator != null) ...[
            const SizedBox(width: 6),
            voiceDownloadIndicator,
          ],
          statusIndicator,
        ],
      ],
    );
  }
}
