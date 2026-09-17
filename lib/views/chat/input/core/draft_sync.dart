part of '../message_input_widget.dart';

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
    _draftSaveTimer = Timer(_MessageInputWidgetState._draftSaveDelay, () {
      unawaited(_persistDraft(value));
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

  Future<void> _persistDraft(String value) async {
    if (!mounted) {
      return;
    }
    final chat = context.read<ChatProvider>();
    if (value.trim().isEmpty) {
      await _clearPersistedDraft(chat);
      return;
    }
    await chat.saveDraft(value);
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
    final draft = widget.channel.draft ?? '';
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
