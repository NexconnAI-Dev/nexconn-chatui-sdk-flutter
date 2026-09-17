// ignore_for_file: use_build_context_synchronously

part of '../message_input_widget.dart';

extension _MessageInputPluginActions on _MessageInputWidgetState {
  Future<void> _sendText(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
  ) async {
    final text = input.draft;
    final mentionUserIds = input.mentionUserIds;
    final referenceMessage = input.referenceMessage;
    _draftSaveTimer?.cancel();
    _typingTimer?.cancel();
    _controller.clear();
    input.clearDraft();
    _syncingFocusForInputMode = true;
    try {
      await context.read<MessageListController?>()?.prepareForOutgoingAppend();
    } finally {
      _syncingFocusForInputMode = false;
    }
    if (!mounted) {
      return;
    }
    await chat.sendText(
      text,
      referenceMessage: referenceMessage,
      mentionUserIds: mentionUserIds.isEmpty ? null : mentionUserIds,
    );
    if (!mounted) {
      return;
    }
    input.clearReferenceMessage();
    await _clearPersistedDraft();
  }

  Future<void> _handlePluginTap(
    BuildContext context,
    MessageInputProvider input,
    MessageInputExtensionPlugin plugin,
  ) async {
    input.setMode(MessageInputMode.initial);
    if (!await _requestPluginPermission(context, plugin)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final currentContext = this.context;
    if (plugin.onTap != null) {
      await plugin.onTap!.call(currentContext, plugin);
    } else if (_canSendMediaWithPlugin(plugin)) {
      final mediaDrafts = await _resolveMediaDrafts(currentContext, plugin);
      if (!mounted) {
        return;
      }
      if (mediaDrafts.isEmpty) {
        return;
      }
      final chat = currentContext.read<ChatProvider>();
      for (final media in mediaDrafts) {
        if (!mounted) {
          return;
        }
        final normalizedPath = media.path.trim();
        if (normalizedPath.isEmpty) {
          continue;
        }
        switch (plugin.type) {
          case MessageInputExtensionPluginType.file:
            await chat.sendFileMessage(normalizedPath);
            break;
          case MessageInputExtensionPluginType.video:
          case MessageInputExtensionPluginType.filming:
            await chat.sendShortVideoMessage(normalizedPath, media.duration);
            break;
          case MessageInputExtensionPluginType.photo:
          case MessageInputExtensionPluginType.camera:
            if (media.isGif) {
              await chat.sendGifMessage(normalizedPath);
            } else {
              await chat.sendImageMessage(normalizedPath);
            }
            break;
          case MessageInputExtensionPluginType.custom:
          case MessageInputExtensionPluginType.location:
            break;
        }
      }
    } else if (_canSendLocationWithPlugin(plugin)) {
      final location = await plugin.locationResolver?.call(
        currentContext,
        plugin,
      );
      if (!mounted || location == null) {
        return;
      }
      final chat = currentContext.read<ChatProvider>();
      await chat.sendLocationMessage(
        longitude: location.longitude,
        latitude: location.latitude,
        poiName: location.poiName,
        thumbnailPath: location.thumbnailPath,
      );
    }
    if (!mounted) {
      return;
    }
    input.setMode(MessageInputMode.text);
  }
}
