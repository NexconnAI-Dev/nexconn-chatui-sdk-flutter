part of '../message_input_widget.dart';

/// Inline edit bar and full-screen editor aligned with the IMKit message
/// edit design: quote preview header, prefilled text field with an expand
/// button, and an [emoji | cancel | confirm] action row.
extension _MessageInputEditBar on _MessageInputWidgetState {
  static const double _editFieldMaxHeight = 112;
  static const double _editActionButtonExtent = 36;

  Widget _buildEditInputBar(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
    NexconnThemeTokens theme,
  ) {
    final editingReference = _editingReferenceMessage(chat, input);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (editingReference != null)
          _buildEditingReferencePreview(editingReference, input, theme),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: _buildEditTextField(context, input, theme, expanded: false),
        ),
        _buildEditActionRow(context, input, chat, theme),
      ],
    );
  }

  Widget _buildEditTextField(
    BuildContext context,
    MessageInputProvider input,
    NexconnThemeTokens theme, {
    required bool expanded,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: kInputFieldMinHeight,
        maxHeight: expanded
            ? double.infinity
            : _editFieldMaxHeight + kInputFieldContentPaddingV * 2,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: kInputFieldContentPaddingV,
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: expanded
              ? _fullScreenTextScrollController
              : _textScrollController,
          key: expanded
              ? const ValueKey('message-edit-fullscreen-field')
              : const ValueKey('message-edit-inline-field'),
          minLines: expanded ? null : 1,
          maxLines: expanded ? null : 5,
          expands: expanded,
          maxLength: 5000,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          scrollPhysics: const BouncingScrollPhysics(),
          cursorHeight: kInputFieldFontHeight,
          style: const TextStyle(
            fontSize: kInputFieldFontSize,
            height: kInputFieldFontHeight / kInputFieldFontSize,
          ).copyWith(color: theme.primaryTextColor),
          onTap: () => input.setMode(MessageInputMode.text),
          onChanged: (value) => _handleDraftChanged(context, input, value),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.surfaceMutedColor,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: kInputFieldContentPaddingV,
              horizontal: kInputFieldContentPaddingH,
            ),
            hintStyle: const TextStyle(
              fontSize: kInputFieldFontSize,
            ).copyWith(color: theme.secondaryTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kInputFieldBorderRadius),
              borderSide: BorderSide.none,
            ),
            // 全屏态的收起按钮位于页面右上角，输入框内不再重复放置。
            suffixIcon: expanded
                ? null
                : _buildEditExpandButton(context, input, expanded),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 36,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditExpandButton(
    BuildContext context,
    MessageInputProvider input,
    bool expanded,
  ) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return IconButton(
      key: ValueKey(expanded ? 'message-edit-collapse' : 'message-edit-expand'),
      visualDensity: VisualDensity.compact,
      tooltip: context.chatUIL10n.messageEditExpandTooltip,
      icon: Icon(
        expanded ? Icons.close_fullscreen : Icons.open_in_full,
        size: 18,
        color: theme.secondaryTextColor,
      ),
      onPressed: () {
        if (expanded) {
          // 通过 provider 状态收起，由状态同步负责移除全屏层。
          input.setEditExpanded(false);
          return;
        }
        input.setEditExpanded(true);
      },
    );
  }

  Widget _buildEditActionRow(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
    NexconnThemeTokens theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          if (widget.config.enableEmojiPanel &&
              widget.config.enabledToolbarControls.contains(
                MessageInputBarControl.emoji,
              ))
            _buildEditEmojiButton(context, input, theme),
          const Spacer(),
          _buildEditCancelButton(context, input, theme),
          const SizedBox(width: 10),
          _buildEditConfirmButton(context, input, chat, theme),
        ],
      ),
    );
  }

  Widget _buildEditEmojiButton(
    BuildContext context,
    MessageInputProvider input,
    NexconnThemeTokens theme,
  ) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: context.chatUIL10n.messageInputEmojiTooltip,
      icon: ChatUIAsset.image(
        'NexconnLightIcon/Emoji.png',
        width: kInputFieldIconSize,
        height: kInputFieldIconSize,
        color: theme.primaryTextColor,
      ),
      onPressed: () => _toggleInputMode(input, MessageInputMode.emoji),
    );
  }

  Widget _buildEditCancelButton(
    BuildContext context,
    MessageInputProvider input,
    NexconnThemeTokens theme,
  ) {
    return GestureDetector(
      key: const ValueKey('message-edit-cancel'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _hideFullScreenEditOverlay();
        unawaited(_cancelEditing(context, input));
      },
      child: Container(
        width: 64,
        height: _editActionButtonExtent,
        decoration: BoxDecoration(
          color: theme.surfaceMutedColor,
          borderRadius: BorderRadius.circular(kInputFieldBorderRadius),
        ),
        alignment: Alignment.center,
        child: ChatUIAsset.image(
          'NexconnLightIcon/Close.png',
          width: 18,
          height: 18,
          color: theme.primaryTextColor,
        ),
      ),
    );
  }

  Widget _buildEditConfirmButton(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
    NexconnThemeTokens theme,
  ) {
    final editable = _isActiveEditAvailable(input, chat) && input.hasDraft;
    return GestureDetector(
      key: const ValueKey('message-edit-confirm'),
      behavior: HitTestBehavior.opaque,
      onTap: editable
          ? () {
              _hideFullScreenEditOverlay();
              unawaited(_sendText(context, input, chat));
            }
          : () {
              if (!_isActiveEditAvailable(input, chat)) {
                _showEditingUnavailable(context);
              }
            },
      child: Container(
        width: 64,
        height: _editActionButtonExtent,
        decoration: BoxDecoration(
          color: editable
              ? theme.primaryColor
              : theme.primaryColor.withValues(alpha: .38),
          borderRadius: BorderRadius.circular(kInputFieldBorderRadius),
        ),
        alignment: Alignment.center,
        child: ChatUIAsset.image(
          'NexconnLightIcon/Done.png',
          width: 20,
          height: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Full-screen editor content mounted in the root overlay; the inline bar
  /// hides itself while this layer is visible so only one text field stays
  /// attached to the shared controller.
  Widget _buildFullScreenEditContent(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
    NexconnThemeTokens theme,
    Animation<double> animation,
  ) {
    final editingReference = _editingReferenceMessage(chat, input);
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: Material(
        color: theme.panelColor,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _buildEditExpandButton(context, input, true),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: _buildEditTextField(
                      context,
                      input,
                      theme,
                      expanded: true,
                    ),
                  ),
                ),
                if (editingReference != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildEditingReferencePreview(
                        editingReference,
                        input,
                        theme,
                      ),
                    ),
                  ),
                _buildEditActionRow(context, input, chat, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncFullScreenEditOverlay(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
  ) {
    final shouldShow = input.isEditing && input.editExpanded;
    if (shouldShow && _fullScreenEditEntry == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && input.isEditing && input.editExpanded) {
          _showFullScreenEditOverlay(context, input, chat);
        }
      });
      return;
    }
    if (!shouldShow && _fullScreenEditEntry != null) {
      _hideFullScreenEditOverlay();
    }
  }

  void _showFullScreenEditOverlay(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
  ) {
    if (_fullScreenEditEntry != null || !mounted) {
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final entry = OverlayEntry(
      builder: (overlayContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ChangeNotifierProvider<MessageInputProvider>.value(value: input),
          Provider<MessageListController?>.value(
            value: context.read<MessageListController?>(),
          ),
        ],
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.4, end: 1).animate(controller),
          child: _buildFullScreenEditContent(
            overlayContext,
            input,
            chat,
            NexconnThemeProvider.resolveTokens(overlayContext),
            controller,
          ),
        ),
      ),
    );
    _fullScreenEditAnimation = controller;
    _fullScreenEditEntry = entry;
    overlay.insert(entry);
    controller.forward();
  }

  void _hideFullScreenEditOverlay() {
    final entry = _fullScreenEditEntry;
    final animation = _fullScreenEditAnimation;
    if (entry == null) {
      return;
    }
    _fullScreenEditEntry = null;
    if (animation == null) {
      entry.remove();
      _handleFullScreenEditOverlayRemoved();
      return;
    }
    _fullScreenEditAnimation = null;
    animation.reverse().whenComplete(() {
      if (entry.mounted) {
        entry.remove();
      }
      animation.dispose();
      // 全屏层完全移除后再恢复底部内联编辑条，避免两个 TextField 同时
      // 挂在同一个控制器上。
      _handleFullScreenEditOverlayRemoved();
    });
  }
}
