part of '../message_bubble.dart';

extension _MessageBubbleAccessories on _MessageBubbleBase {
  Widget _multiSelectIcon() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        key: MessageBubble.multiSelectHitTargetKey,
        width: 44,
        height: 44,
        child: Center(
          child: ChatUIAsset.image(
            selected ? 'multi_select.png' : 'multi_unselect.png',
            width: kBubbleMultiSelectIconSize,
            height: kBubbleMultiSelectIconSize,
          ),
        ),
      ),
    );
  }

  double _bubbleMaxWidth(BuildContext context) {
    final width =
        MediaQuery.of(context).size.width * messageBubbleMaxWidthFactor;
    if (!config.messageListConfig.showAvatar) {
      return width;
    }
    final avatarWidth = config.messageListConfig.showAvatar
        ? kBubbleAvatarSize + 2 * kBubbleAvatarPadding
        : 0;
    final selectionWidth = multiSelectMode ? 44 : 0;
    return width - avatarWidth - selectionWidth;
  }

  Widget _timeSeparator(BuildContext context) {
    final serverNow = _serverNow(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kBubbleTimeVerticalPadding),
      child: Center(
        child: Text(
          TimeUtil.chatViewFormatTime(
            message.sentTime,
            now: serverNow,
            l10n: context.chatUIL10n,
          ),
          style: TextStyle(
            color: NexconnThemeProvider.resolveTokens(
              context,
            ).secondaryTextColor,
            fontSize: kBubbleTimeFontSize,
          ),
        ),
      ),
    );
  }

  DateTime? _serverNow(BuildContext context) {
    try {
      return context.watch<EngineProvider>().serverNow;
    } on ProviderNotFoundException {
      return null;
    }
  }
}
