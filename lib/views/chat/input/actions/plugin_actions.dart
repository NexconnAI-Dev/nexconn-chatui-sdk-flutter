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
    final editingMessage = input.editingMessage;
    if (editingMessage != null && !_isActiveEditAvailable(input, chat)) {
      _showEditingUnavailable(context);
      return;
    }
    _cancelPendingDraftSave(flush: editingMessage != null);
    _draftWriteGeneration++;
    _typingTimer?.cancel();
    if (editingMessage == null) {
      _controller.clear();
      input.clearDraft();
    }
    _syncingFocusForInputMode = true;
    try {
      await context.read<MessageListController?>()?.prepareForOutgoingAppend();
    } finally {
      _syncingFocusForInputMode = false;
    }
    if (!mounted) {
      return;
    }
    var editStarted = false;
    final error = editingMessage != null
        ? await chat.editMessage(
            message: editingMessage,
            replacementText: text,
            mentionUserIds: mentionUserIds,
            onStarted: () {
              editStarted = true;
              if (!mounted) return;
              if (!_matchesEditSubmissionSnapshot(
                input,
                editingMessage,
                text,
                mentionUserIds,
              )) {
                return;
              }
              _controller.clear();
              input.clearEditing(restoreDraft: false);
              unawaited(chat.clearEditedMessageDraft());
              unawaited(_clearPersistedDraft(chat));
            },
          )
        : await (() async {
            await chat.sendText(
              text,
              referenceMessage: referenceMessage,
              mentionUserIds: mentionUserIds.isEmpty ? null : mentionUserIds,
            );
            return NCError(code: 0);
          })();
    if (!mounted) {
      return;
    }
    if (error.code != 0) {
      if (editingMessage != null && !editStarted) {
        if (!input.isEditing) {
          input.startEditing(
            editingMessage,
            content: text,
            mentionUserIds: mentionUserIds,
          );
        } else if (input.draft != text) {
          input.updateDraft(text);
        }
        _scheduleDraftSave(text);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? context.chatUIL10n.messageEditFailed),
        ),
      );
      return;
    }
    if (editingMessage != null) return;
    input.clearReferenceMessage();
    await _clearPersistedDraft();
  }

  void _showEditingUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.chatUIL10n.messageEditUnavailable)),
    );
  }

  Future<void> _cancelEditing(
    BuildContext context,
    MessageInputProvider input,
  ) async {
    _cancelPendingDraftSave(flush: false);
    _draftWriteGeneration++;
    final chat = context.read<ChatProvider>();
    input.clearEditing();
    await chat.clearEditedMessageDraft();
  }

  bool _matchesEditSubmissionSnapshot(
    MessageInputProvider input,
    Message editingMessage,
    String text,
    List<String> mentionUserIds,
  ) {
    if (!identical(input.editingMessage, editingMessage) ||
        input.draft != text) {
      return false;
    }
    final currentMentionUserIds = input.mentionUserIds;
    if (currentMentionUserIds.length != mentionUserIds.length) return false;
    for (var index = 0; index < mentionUserIds.length; index++) {
      if (currentMentionUserIds[index] != mentionUserIds[index]) return false;
    }
    return true;
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
      input.clearReferenceMessage();
      await _clearPersistedDraft();
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
