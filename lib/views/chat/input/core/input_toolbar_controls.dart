part of '../message_input_widget.dart';

extension _MessageInputToolbarControls on _MessageInputWidgetState {
  Widget _buildToolbarButton(
    MessageInputProvider input,
    MessageInputBarControl control,
  ) {
    final mode = _modeForControl(control);
    final isSelected = input.mode == mode;
    final buttonConfig = widget.config.toolbarButtonConfigs[control];
    final assetName = switch (control) {
      MessageInputBarControl.voice =>
        isSelected
            ? 'NexconnLightIcon/Enter-the-keyboard.png'
            : 'NexconnLightIcon/Voice-message.png',
      MessageInputBarControl.emoji =>
        isSelected
            ? 'NexconnLightIcon/Enter-the-keyboard.png'
            : 'NexconnLightIcon/Emoji-1.png',
      MessageInputBarControl.extension => 'NexconnLightIcon/More.png',
    };
    final tooltip = switch (control) {
      MessageInputBarControl.voice =>
        isSelected
            ? context.chatUIL10n.messageInputSwitchToTextTooltip
            : context.chatUIL10n.messageInputVoiceTooltip,
      MessageInputBarControl.emoji =>
        isSelected
            ? context.chatUIL10n.messageInputHideEmojiPanelTooltip
            : context.chatUIL10n.messageInputEmojiPanelTooltip,
      MessageInputBarControl.extension =>
        isSelected
            ? context.chatUIL10n.messageInputHideExtensionPanelTooltip
            : context.chatUIL10n.messageInputExtensionPanelTooltip,
    };

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleInputMode(input, mode),
        child: Padding(
          padding: buttonConfig?.padding ?? _toolbarButtonPadding(control),
          child: _toolbarButtonIcon(
            assetName: assetName,
            selected: isSelected,
            config: buttonConfig,
          ),
        ),
      ),
    );
  }

  Widget _toolbarButtonIcon({
    required String assetName,
    required bool selected,
    required MessageInputButtonConfig? config,
  }) {
    final customIcon = selected
        ? config?.activeIcon ?? config?.icon
        : config?.icon;
    if (customIcon != null) {
      return SizedBox.square(
        dimension: config?.size ?? kInputFieldIconSize,
        child: customIcon,
      );
    }
    return ChatUIAsset.image(
      assetName,
      height: config?.size ?? kInputFieldIconSize,
      width: config?.size ?? kInputFieldIconSize,
      color: selected ? config?.activeColor ?? config?.color : config?.color,
    );
  }

  EdgeInsets _toolbarButtonPadding(MessageInputBarControl control) {
    return switch (control) {
      MessageInputBarControl.emoji => const EdgeInsets.fromLTRB(
        kInputFieldButtonSpace,
        0,
        0,
        kInputFieldIconPaddingBottom,
      ),
      _ => const EdgeInsets.fromLTRB(
        kInputFieldButtonSpace,
        0,
        kInputFieldButtonSpace,
        kInputFieldIconPaddingBottom,
      ),
    };
  }

  Widget _buildAndroidSendButton(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
  ) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final isEnabled = input.hasDraft;
    return TextFieldTapRegion(
      child: Tooltip(
        message: context.chatUIL10n.messageInputSendTooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled ? () => _sendText(context, input, chat) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              kInputFieldButtonSpace,
              0,
              kInputFieldButtonSpace,
              kInputFieldIconPaddingBottom,
            ),
            child: Icon(
              Icons.send,
              size: kInputFieldIconSize,
              color: isEnabled ? theme.primaryColor : theme.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidTrailingAction(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
  ) {
    if (input.hasDraft) {
      return _buildAndroidSendButton(context, input, chat);
    }
    if (!widget.config.enabledToolbarControls.contains(
          MessageInputBarControl.extension,
        ) ||
        !widget.config.hasExtensionPlugins) {
      return const SizedBox.shrink();
    }
    return _buildToolbarButton(input, MessageInputBarControl.extension);
  }
}
