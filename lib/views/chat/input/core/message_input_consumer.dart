part of '../message_input_widget.dart';

extension _MessageInputMessageInputConsumer on _MessageInputWidgetState {
  Widget _buildInputConsumer() {
    return Consumer<MessageInputProvider>(
      builder: (context, input, _) {
        _syncReferenceComposerFocus(input);
        final theme = NexconnThemeProvider.resolveTokens(context);
        final multiSelectState = context
            .select<ChatProvider, ({bool enabled, int selectedCount})>(
              (chat) => (
                enabled: chat.multiSelectMode,
                selectedCount: chat.selectedMessages.length,
              ),
            );
        final chat = context.read<ChatProvider>();
        if (multiSelectState.enabled) {
          return _buildMultiSelectBar(context, chat, theme);
        }
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        return SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.config.backgroundColor ?? theme.panelColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (input.referenceMessage != null)
                  _buildReferencePreview(input.referenceMessage!, input, theme),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.config.isControlEnabled(
                      MessageInputBarControl.voice,
                    ))
                      _buildToolbarButton(input, MessageInputBarControl.voice),
                    Expanded(child: _buildInputArea(context, input, chat)),
                    ...widget.config.enabledToolbarControls
                        .where(
                          (control) =>
                              control != MessageInputBarControl.voice &&
                              !(isAndroid &&
                                  control == MessageInputBarControl.extension),
                        )
                        .map((control) => _buildToolbarButton(input, control)),
                    if (isAndroid)
                      _buildAndroidTrailingAction(context, input, chat),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildActivePanel(context, input),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
