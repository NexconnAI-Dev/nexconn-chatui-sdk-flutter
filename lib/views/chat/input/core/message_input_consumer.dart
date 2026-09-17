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
          if (!_wasMultiSelectMode) {
            _restoreFocusAfterMultiSelect = _focusNode.hasFocus;
            _wasMultiSelectMode = true;
          }
          return _buildMultiSelectBar(context, chat, theme);
        }
        _wasMultiSelectMode = false;
        final editingReference = input.referenceMessage == null
            ? _editingReferenceMessage(chat, input)
            : null;
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        // 全屏编辑层挂载在根 Overlay 上，底部输入条整体让位，保证同一时刻
        // 只有一个 TextField 挂在共享的编辑控制器上。
        if (input.isEditing) {
          _syncFullScreenEditOverlay(context, input, chat);
        }
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
                if (input.isEditing &&
                    !input.editExpanded &&
                    _fullScreenEditEntry == null)
                  _buildEditInputBar(context, input, chat, theme)
                else if (!input.isEditing) ...[
                  if (input.referenceMessage != null)
                    _buildReferencePreview(
                      input.referenceMessage!,
                      input,
                      theme,
                    ),
                  if (editingReference != null)
                    _buildEditingReferencePreview(
                      editingReference,
                      input,
                      theme,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.config.isControlEnabled(
                        MessageInputBarControl.voice,
                      ))
                        _buildToolbarButton(
                          input,
                          MessageInputBarControl.voice,
                        ),
                      Expanded(child: _buildInputArea(context, input, chat)),
                      ...widget.config.enabledToolbarControls
                          .where(
                            (control) =>
                                control != MessageInputBarControl.voice &&
                                !(isAndroid &&
                                    control ==
                                        MessageInputBarControl.extension),
                          )
                          .map(
                            (control) => _buildToolbarButton(input, control),
                          ),
                      if (isAndroid)
                        _buildAndroidTrailingAction(context, input, chat),
                    ],
                  ),
                ],
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
