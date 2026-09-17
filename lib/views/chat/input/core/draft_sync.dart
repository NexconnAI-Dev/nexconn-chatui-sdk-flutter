part of '../message_input_widget.dart';

const String _editedDraftContentPrefix = 'nexconn-chatui-edit-draft:v1:';

class _DecodedEditedDraftContent {
  final String content;
  final List<String>? mentionUserIds;

  const _DecodedEditedDraftContent({
    required this.content,
    required this.mentionUserIds,
  });
}

extension _MessageInputDraftSync on _MessageInputWidgetState {
  void _handleDraftChanged(
    BuildContext context,
    MessageInputProvider input,
    String value,
  ) {
    final previousDraft = input.draft;
    input.updateDraft(value);
    _scheduleDraftSave(value);
    _scheduleTypingStatus(value);
    unawaited(_maybePickMentionCandidate(context, input, previousDraft, value));
  }

  void _scheduleDraftSave(String value) {
    _draftSaveTimer?.cancel();
    final generation = ++_draftWriteGeneration;
    final chat = context.read<ChatProvider>();
    final editingMessageId = _inputProvider.editingMessage?.messageId;
    final mentionUserIds = editingMessageId?.isNotEmpty == true
        ? List<String>.unmodifiable(_inputProvider.mentionUserIds)
        : null;
    _pendingDraftChatProvider = chat;
    _pendingDraftEditingMessageId = editingMessageId;
    _pendingDraftValue = value;
    _pendingDraftMentionUserIds = mentionUserIds;
    _pendingDraftGeneration = generation;
    _draftSaveTimer = Timer(_MessageInputWidgetState._draftSaveDelay, () {
      if (_pendingDraftGeneration != generation) return;
      _clearPendingDraftSnapshot();
      unawaited(
        _persistDraftSnapshot(
          chat,
          editingMessageId,
          value,
          mentionUserIds,
          generation,
        ),
      );
    });
  }

  void _scheduleTypingStatus(String value) {
    _typingTimer?.cancel();
    if (!_shouldSendTypingStatus) {
      return;
    }
    if (value.trim().isEmpty) {
      return;
    }
    _typingTimer = Timer(_MessageInputWidgetState._typingSendDelay, () {
      if (!mounted) {
        return;
      }
      unawaited(_sendTypingStatus());
    });
  }

  Future<void> _sendTypingStatus() async {
    if (!_shouldSendTypingStatus) {
      return;
    }
    final channel = widget.channel;
    if (channel is DirectChannel) {
      await channel.sendTypingStatus('text');
    }
  }

  Future<void> _persistDraftSnapshot(
    ChatProvider chat,
    String? editingMessageId,
    String value,
    List<String>? mentionUserIds,
    int generation, {
    bool enforceGeneration = true,
  }) async {
    if (enforceGeneration && generation != _draftWriteGeneration) return;
    if (editingMessageId != null && editingMessageId.isNotEmpty) {
      if (value.trim().isEmpty) {
        await chat.clearEditedMessageDraft();
      } else {
        await chat.saveEditedMessageDraft(
          editingMessageId,
          _encodeEditedDraftContent(value, mentionUserIds ?? const <String>[]),
        );
      }
      return;
    }
    if (value.trim().isEmpty) {
      await _clearPersistedDraft(chat);
      return;
    }
    await chat.saveDraft(value);
  }

  void _cancelPendingDraftSave({required bool flush}) {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    final chat = _pendingDraftChatProvider;
    final editingMessageId = _pendingDraftEditingMessageId;
    final value = _pendingDraftValue;
    final mentionUserIds = _pendingDraftMentionUserIds;
    final generation = _pendingDraftGeneration;
    _clearPendingDraftSnapshot();
    if (!flush || chat == null || value == null || generation == null) return;
    unawaited(
      _persistDraftSnapshot(
        chat,
        editingMessageId,
        value,
        mentionUserIds,
        generation,
        enforceGeneration: false,
      ),
    );
  }

  void _clearPendingDraftSnapshot() {
    _pendingDraftChatProvider = null;
    _pendingDraftEditingMessageId = null;
    _pendingDraftValue = null;
    _pendingDraftMentionUserIds = null;
    _pendingDraftGeneration = null;
  }

  void _handleEditingSessionChanged(MessageInputProvider input) {
    final revision = input.editingRevision;
    if (_observedEditingRevision == revision) return;
    final previousMessageId = _observedEditingMessageId;
    final currentMessageId = input.editingMessage?.messageId;
    final hadObservedState = _observedEditingRevision >= 0;
    _observedEditingRevision = revision;
    _observedEditingMessageId = currentMessageId;
    _syncEditingAvailability(input, revision);
    if (!hadObservedState && currentMessageId == null) return;

    _cancelPendingDraftSave(flush: true);
    final generation = ++_draftWriteGeneration;
    final chat = context.read<ChatProvider>();
    if (currentMessageId != null && currentMessageId.isNotEmpty) {
      if (previousMessageId == null) {
        unawaited(
          _persistNormalDraftSnapshot(chat, input.draftBeforeEditing ?? ''),
        );
      }
      unawaited(
        _persistDraftSnapshot(
          chat,
          currentMessageId,
          input.draft,
          List<String>.unmodifiable(input.mentionUserIds),
          generation,
          enforceGeneration: false,
        ),
      );
      return;
    }
    if (previousMessageId != null) {
      unawaited(_persistNormalDraftSnapshot(chat, input.draft));
    }
  }

  Future<void> _persistNormalDraftSnapshot(
    ChatProvider chat,
    String value,
  ) async {
    if (value.trim().isEmpty) {
      await chat.clearDraft();
    } else {
      await chat.saveDraft(value);
    }
  }

  Future<void> _restoreEditedMessageDraft() async {
    if (!mounted) return;
    final chat = context.read<ChatProvider>();
    final input = _inputProvider;
    final channelKey = _channelInputModeKey(widget.channel);
    final generation = _draftWriteGeneration;
    final editingRevision = input.editingRevision;
    final initialDraft = input.draft;
    final initialMode = input.mode;
    final initialReference = input.referenceMessage;
    if (!await chat.engineProvider.waitForMessageEditSettings() ||
        !_canApplyEditedDraftRestore(
          chat: chat,
          channelKey: channelKey,
          generation: generation,
          editingRevision: editingRevision,
          initialDraft: initialDraft,
          initialMode: initialMode,
          initialReference: initialReference,
        )) {
      return;
    }
    final draft = await chat.getEditedMessageDraft();
    if (!_canApplyEditedDraftRestore(
          chat: chat,
          channelKey: channelKey,
          generation: generation,
          editingRevision: editingRevision,
          initialDraft: initialDraft,
          initialMode: initialMode,
          initialReference: initialReference,
        ) ||
        draft == null ||
        draft.messageId == null ||
        draft.content == null) {
      return;
    }
    final persistedDraft = draft;
    final decodedContent = _decodeEditedDraftContent(persistedDraft.content!);
    final resolution = await chat.resolveEditedDraftMessage(
      persistedDraft.messageId!,
    );
    if (!_canApplyEditedDraftRestore(
      chat: chat,
      channelKey: channelKey,
      generation: generation,
      editingRevision: editingRevision,
      initialDraft: initialDraft,
      initialMode: initialMode,
      initialReference: initialReference,
    )) {
      return;
    }
    if (resolution.shouldClearDraft) {
      // The SDK confirmed that this draft points at a missing, recalled,
      // expired, or otherwise non-editable message. A failed lookup leaves
      // the draft intact so it can be retried after reconnecting.
      await chat.clearEditedMessageDraft();
      return;
    }
    final message = resolution.message;
    if (message == null || !chat.canEditMessageFor(message)) return;
    input.startEditing(
      message,
      content: decodedContent.content,
      mentionUserIds: decodedContent.mentionUserIds,
    );
  }

  String _encodeEditedDraftContent(
    String content,
    List<String> mentionUserIds,
  ) {
    return '$_editedDraftContentPrefix${jsonEncode(<String, Object>{'content': content, 'mentionUserIds': mentionUserIds})}';
  }

  _DecodedEditedDraftContent _decodeEditedDraftContent(String persisted) {
    if (!persisted.startsWith(_editedDraftContentPrefix)) {
      return _DecodedEditedDraftContent(
        content: persisted,
        mentionUserIds: null,
      );
    }
    try {
      final decoded = jsonDecode(
        persisted.substring(_editedDraftContentPrefix.length),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Edited draft payload is not an object');
      }
      final content = decoded['content'];
      final rawMentionUserIds = decoded['mentionUserIds'];
      if (content is! String ||
          rawMentionUserIds is! List ||
          rawMentionUserIds.any((value) => value is! String)) {
        throw const FormatException('Edited draft payload is malformed');
      }
      return _DecodedEditedDraftContent(
        content: content,
        mentionUserIds: List<String>.unmodifiable(
          rawMentionUserIds.cast<String>(),
        ),
      );
    } on FormatException {
      return _DecodedEditedDraftContent(
        content: persisted,
        mentionUserIds: null,
      );
    }
  }

  bool _canApplyEditedDraftRestore({
    required ChatProvider chat,
    required String channelKey,
    required int generation,
    required int editingRevision,
    required String initialDraft,
    required MessageInputMode initialMode,
    required Message? initialReference,
  }) {
    if (!mounted ||
        _channelInputModeKey(widget.channel) != channelKey ||
        _draftWriteGeneration != generation) {
      return false;
    }
    ChatProvider currentChat;
    try {
      currentChat = context.read<ChatProvider>();
    } catch (_) {
      return false;
    }
    final input = _inputProvider;
    return identical(currentChat, chat) &&
        input.editingRevision == editingRevision &&
        !input.isEditing &&
        input.draft == initialDraft &&
        input.mode == initialMode &&
        identical(input.referenceMessage, initialReference);
  }

  Future<void> _clearPersistedDraft([ChatProvider? chat]) async {
    if (!mounted && chat == null) {
      return;
    }
    await (chat ?? context.read<ChatProvider>()).clearDraft();
  }

  bool get _shouldSendTypingStatus =>
      widget.channel.channelType == ChannelType.direct;

  void _syncInitialDraft({bool clearReference = false}) {
    if (_didSyncInitialDraft) {
      return;
    }
    _didSyncInitialDraft = true;
    final input = _inputProvider;
    // A shared provider may already contain an active edit session when the
    // input widget is mounted (for example, alongside a lazily built list).
    // The channel's ordinary draft must not overwrite that in-progress edit.
    if (!clearReference && input.isEditing) {
      final draft = input.draft;
      if (_controller.text != draft) {
        _controller.value = TextEditingValue(
          text: draft,
          selection: TextSelection.collapsed(offset: draft.length),
        );
      }
      return;
    }
    final draft = widget.channel.draft ?? '';
    final cachedReference =
        _channelReferenceDrafts[_channelReferenceDraftKey(widget.channel)];
    if (_ownedInputProvider != null) {
      final restoredMode = _restoredInputModeForChannel(draft);
      if (clearReference) {
        _inputProvider.resetForChannelSilently(
          draft: draft,
          mode: restoredMode,
        );
      } else {
        _inputProvider.updateDraftSilently(draft);
        _inputProvider.setModeSilently(restoredMode);
      }
    } else if (clearReference) {
      _inputProvider.resetForChannelSilently(draft: draft);
    } else {
      _inputProvider.updateDraftSilently(draft);
    }
    if (draft.trim().isNotEmpty &&
        _inputProvider.referenceMessage == null &&
        cachedReference != null) {
      _inputProvider.setReferenceMessageSilently(cachedReference);
    }
    if (_controller.text == draft) {
      return;
    }
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    if (draft.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _inputProvider.setMode(MessageInputMode.text);
      });
    }
  }

  MessageInputMode _restoredInputModeForChannel(String draft) {
    if (draft.trim().isNotEmpty) {
      return MessageInputMode.text;
    }
    final cachedMode = _MessageInputWidgetState
        ._channelInputModes[_channelInputModeKey(widget.channel)];
    if (cachedMode != null && _isModeAvailable(cachedMode, widget.config)) {
      return cachedMode;
    }
    return MessageInputMode.initial;
  }

  MessageInputProvider get _inputProvider {
    return _providedInputProvider() ?? _ownedInputProvider!;
  }

  MessageInputProvider? _providedInputProvider() {
    return Provider.of<MessageInputProvider?>(context, listen: false);
  }

  BaseChannel _referenceProfileChannel(Message message) {
    try {
      final type = message.channelType;
      final id = message.channelId;
      if (type != null && id != null && id.isNotEmpty) {
        return BaseChannel(type, id);
      }
    } catch (_) {
      // Fall back to the current input channel.
    }
    return widget.channel;
  }

  ChatProfileInfo? _profileFromReferenceMessage(Message message) {
    try {
      final userInfo = message.userInfo;
      if (userInfo == null) {
        return null;
      }
      return ChatProfileInfo(
        id: userInfo.userId ?? _senderUserIdOf(message) ?? '',
        name: userInfo.alias ?? userInfo.name,
        portraitUri: userInfo.avatarUrl,
        extra: userInfo.extra,
      );
    } catch (_) {
      return null;
    }
  }

  String _referenceSenderName(Message message, ChatProfileInfo? profile) {
    final resolvedName = profile?.name?.trim();
    if (resolvedName != null && resolvedName.isNotEmpty) {
      return resolvedName;
    }
    try {
      final userInfo = message.userInfo;
      return userInfo?.alias ??
          userInfo?.name ??
          _senderUserIdOf(message) ??
          '';
    } catch (_) {
      return _senderUserIdOf(message) ?? '';
    }
  }

  String? _senderUserIdOf(Message message) {
    try {
      return message.senderUserId;
    } on NoSuchMethodError {
      return null;
    }
  }

  bool _isDifferentChannel(BaseChannel previous, BaseChannel next) {
    return previous.channelType != next.channelType ||
        previous.channelId != next.channelId ||
        previous.channelIdentifier.subChannelId !=
            next.channelIdentifier.subChannelId;
  }

  bool _isModeAvailable(MessageInputMode mode, MessageInputConfig config) {
    return switch (mode) {
      MessageInputMode.initial => true,
      MessageInputMode.text => true,
      MessageInputMode.voice =>
        config.enableVoiceInput &&
            config.enabledToolbarControls.contains(
              MessageInputBarControl.voice,
            ),
      MessageInputMode.emoji =>
        config.enableEmojiPanel &&
            config.enabledToolbarControls.contains(
              MessageInputBarControl.emoji,
            ),
      MessageInputMode.extension =>
        config.enableExtensionPanel &&
            config.enabledToolbarControls.contains(
              MessageInputBarControl.extension,
            ),
    };
  }

  MessageInputMode _modeForControl(MessageInputBarControl control) {
    return switch (control) {
      MessageInputBarControl.voice => MessageInputMode.voice,
      MessageInputBarControl.emoji => MessageInputMode.emoji,
      MessageInputBarControl.extension => MessageInputMode.extension,
    };
  }
}
