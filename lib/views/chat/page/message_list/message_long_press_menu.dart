part of '../message_list_widget.dart';

extension _MessageListLongPressMenu on _MessageListWidgetState {
  static const double _kMessageMenuMinWidth = 160;
  static const double _kMessageMenuMaxWidth = 280;
  static const double _kMessageMenuHorizontalPadding = 16;
  static const double _kMessageMenuIconSpacing = 12;

  Future<void> _handleMessageLongPress(
    BuildContext context,
    ChatProvider provider,
    Message message,
    Offset globalPosition,
  ) async {
    widget.onMessageLongPress?.call(message);
    final menu = widget.config.longPressMenuConfig;
    if (!menu.enabled) {
      return;
    }
    final canCopy = _canCopyMessage(message);
    final canEdit = _canEditMessage(provider, message);
    final canDeleteForAll = _canDeleteForAllMessage(provider, message);
    final isSystemChannel = _isSystemChannelMessage(message);
    if (!menu.showCopyButton &&
        !menu.showEditButton &&
        !menu.showDeleteButton &&
        !menu.showDeleteForAllButton &&
        !menu.showReferenceButton &&
        !menu.showMoreButton) {
      return;
    }
    final menuLabels = <String>[];
    final items = <PopupMenuEntry<_ChatMessageMenuAction>>[
      const PopupMenuItem<_ChatMessageMenuAction>(
        enabled: false,
        height: 4,
        padding: EdgeInsets.zero,
        child: SizedBox.shrink(),
      ),
      if (menu.showCopyButton && canCopy)
        _messageMenuItem(
          value: _ChatMessageMenuAction.copy,
          iconName: 'NexconnLightIcon/Copy.png',
          label: _trackMenuLabel(
            menuLabels,
            menu.copyText ?? context.chatUIL10n.chatLongPressCopy,
          ),
        ),
      if (!isSystemChannel && menu.showEditButton && canEdit)
        _messageMenuItem(
          value: _ChatMessageMenuAction.edit,
          iconName: 'NexconnLightIcon/Edit.png',
          label: _trackMenuLabel(
            menuLabels,
            menu.editText ?? context.chatUIL10n.chatLongPressEdit,
          ),
        ),
      if (menu.showDeleteButton && !canDeleteForAll)
        _messageMenuItem(
          value: _ChatMessageMenuAction.delete,
          iconName: 'NexconnLightIcon/Delete.png',
          label: _trackMenuLabel(
            menuLabels,
            menu.deleteText ?? context.chatUIL10n.chatLongPressDeleteForMe,
          ),
        ),
      if (!isSystemChannel && menu.showDeleteForAllButton && canDeleteForAll)
        _messageMenuItem(
          value: _ChatMessageMenuAction.deleteForAll,
          iconName: 'NexconnLightIcon/Delete.png',
          label: _trackMenuLabel(
            menuLabels,
            menu.deleteForAllText ??
                context.chatUIL10n.chatLongPressDeleteForAll,
          ),
        ),
      if (!isSystemChannel &&
          menu.showReferenceButton &&
          _canReferenceMessage(message))
        _messageMenuItem(
          value: _ChatMessageMenuAction.reference,
          iconName: 'NexconnLightIcon/Reply.png',
          label: _trackMenuLabel(
            menuLabels,
            menu.referenceText ?? context.chatUIL10n.chatLongPressReference,
          ),
        ),
      if (!isSystemChannel && menu.showMoreButton)
        _messageMenuItem(
          value: _ChatMessageMenuAction.more,
          iconName: 'NexconnLightIcon/Multi-select.png',
          label: _trackMenuLabel(
            menuLabels,
            menu.moreText ?? context.chatUIL10n.chatLongPressMore,
          ),
        ),
      const PopupMenuItem<_ChatMessageMenuAction>(
        enabled: false,
        height: 4,
        padding: EdgeInsets.zero,
        child: SizedBox.shrink(),
      ),
    ];
    if (items.length <= 2) {
      return;
    }
    final menuWidth = _resolveMessageMenuWidth(context, menuLabels);
    final menuHeight = _estimateMenuHeight(items.length);
    final action = showMenu<_ChatMessageMenuAction>(
      context: context,
      position: _menuPosition(
        context,
        globalPosition,
        menuWidth: menuWidth,
        menuHeight: menuHeight,
      ),
      // 弹出消息菜单时保留输入框焦点，避免键盘被 PopupRoute 收起。
      requestFocus: false,
      menuPadding: EdgeInsets.zero,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      constraints: BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x33000000),
      items: items,
    );
    final selectedAction = await action;
    if (!context.mounted || selectedAction == null) {
      return;
    }
    switch (selectedAction) {
      case _ChatMessageMenuAction.copy:
        await _copyMessage(context, provider, message);
      case _ChatMessageMenuAction.edit:
        await _editMessage(context, provider, message);
      case _ChatMessageMenuAction.delete:
        await _deleteMessage(context, provider, message);
      case _ChatMessageMenuAction.deleteForAll:
        await _deleteMessageForAll(context, provider, message);
      case _ChatMessageMenuAction.reference:
        await _referenceMessage(context, provider, message);
      case _ChatMessageMenuAction.more:
        provider.setMultiSelectMode(true);
        final changed = provider.toggleMessageSelected(message);
        if (!changed) {
          _showSelectionLimitTip(context);
        }
    }
  }

  bool _canEditMessage(ChatProvider provider, Message message) {
    return provider.canEditMessageFor(message);
  }

  Future<void> _editMessage(
    BuildContext context,
    ChatProvider provider,
    Message message,
  ) async {
    final input = context.read<MessageInputProvider?>();
    if (input == null) return;
    final current = input.editingMessage;
    if (current != null && current.messageId != message.messageId) {
      final shouldSwitch =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.chatUIL10n.messageEditSwitchTitle),
              content: Text(context.chatUIL10n.messageEditSwitchMessage),
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
      if (!shouldSwitch || !context.mounted) return;
    }
    input.startEditing(message);
  }

  String _trackMenuLabel(List<String> labels, String label) {
    labels.add(label);
    return label;
  }

  double _resolveMessageMenuWidth(BuildContext context, List<String> labels) {
    final textPainter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var maxTextWidth = 0.0;
    for (final label in labels) {
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: kMessageMenuTextColor,
          fontSize: kMessageMenuFontSize,
        ),
      );
      textPainter.layout();
      if (textPainter.width > maxTextWidth) {
        maxTextWidth = textPainter.width;
      }
    }
    final desiredWidth =
        (_kMessageMenuHorizontalPadding * 2) +
        kMessageMenuIconSize +
        _kMessageMenuIconSpacing +
        maxTextWidth;
    final availableWidth = MediaQuery.sizeOf(context).width - 24;
    final maxAllowedWidth = availableWidth < _kMessageMenuMaxWidth
        ? availableWidth
        : _kMessageMenuMaxWidth;
    return desiredWidth
        .clamp(_kMessageMenuMinWidth, maxAllowedWidth)
        .toDouble();
  }

  double _estimateMenuHeight(int itemCount) {
    if (itemCount <= 2) {
      return 40;
    }
    final actionCount = itemCount - 2;
    return 8 + (actionCount * 44);
  }

  PopupMenuItem<_ChatMessageMenuAction> _messageMenuItem({
    required _ChatMessageMenuAction value,
    required String iconName,
    required String label,
  }) {
    return PopupMenuItem<_ChatMessageMenuAction>(
      value: value,
      height: 34,
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ChatUIAsset.image(
              iconName,
              width: kMessageMenuIconSize,
              height: kMessageMenuIconSize,
              color: kMessageMenuTextColor,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: kMessageMenuTextColor,
                  fontSize: kMessageMenuFontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
