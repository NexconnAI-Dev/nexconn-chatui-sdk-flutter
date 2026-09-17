part of '../message_input_widget.dart';

extension _MessageInputEmojiPanelControls on _MessageInputWidgetState {
  Widget _buildEmojiDeleteButton(
    BuildContext context,
    MessageInputProvider input,
    MessageInputEmojiPanelConfig config,
  ) {
    void onTap() => _deleteBackward(context, input);
    final builder = config.deleteButtonBuilder;
    if (builder != null) {
      return builder(context, onTap);
    }
    return Tooltip(
      message: context.chatUIL10n.messageInputDeleteEmojiTooltip,
      child: InkWell(
        onTap: onTap,
        child: Center(child: config.deleteIcon),
      ),
    );
  }

  Widget _buildFloatingEmojiDeleteButton(
    BuildContext context,
    MessageInputProvider input,
    MessageInputEmojiPanelConfig config,
  ) {
    void onTap() => _deleteBackward(context, input);
    return Positioned(
      left: 12,
      bottom: 8,
      child: Tooltip(
        message: context.chatUIL10n.messageInputDeleteEmojiTooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox.square(
            dimension: 36,
            child: Center(child: config.deleteIcon),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiSendButton(
    BuildContext context,
    MessageInputProvider input,
    MessageInputEmojiPanelConfig config,
  ) {
    final chat = context.read<ChatProvider>();
    final isEnabled = _canSubmitText(input, chat);
    final onTap = isEnabled ? () => _sendText(context, input, chat) : () {};
    final builder = config.sendButtonBuilder;
    if (builder != null) {
      return Positioned(
        right: 0,
        bottom: 0,
        child: IgnorePointer(
          ignoring: !isEnabled,
          child: Opacity(
            opacity: isEnabled ? 1 : 0.45,
            child: builder(context, onTap),
          ),
        ),
      );
    }
    final theme = NexconnThemeProvider.resolveTokens(context);
    final sendConfig = config.sendButtonConfig;
    final enabledBackgroundColor =
        sendConfig.backgroundColor ?? theme.primaryColor;
    final disabledBackgroundColor =
        sendConfig.backgroundColor?.withValues(alpha: 0.45) ??
        theme.dividerColor;
    final disabledTextColor = theme.secondaryTextColor;
    return Positioned(
      right: sendConfig.margin.right,
      bottom: sendConfig.margin.bottom,
      child: SizedBox(
        width: sendConfig.width,
        height: sendConfig.height,
        child: TextButton(
          onPressed: isEnabled ? onTap : null,
          style: TextButton.styleFrom(
            backgroundColor: enabledBackgroundColor,
            disabledBackgroundColor: disabledBackgroundColor,
            foregroundColor: sendConfig.textStyle.color,
            disabledForegroundColor: disabledTextColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(sendConfig.borderRadius),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            sendConfig.text ?? context.chatUIL10n.messageInputEmojiSendButton,
            style: isEnabled
                ? sendConfig.textStyle
                : sendConfig.textStyle.copyWith(color: disabledTextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator({
    required int count,
    required int currentIndex,
    required MessageInputPanelIndicatorConfig config,
  }) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        return Container(
          width: config.size,
          height: config.size,
          margin: EdgeInsets.symmetric(horizontal: config.spacing),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index
                ? config.activeColor ?? theme.secondaryTextColor
                : config.inactiveColor ?? theme.dividerColor,
          ),
        );
      }),
    );
  }
}
