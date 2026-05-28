part of '../message_input_widget.dart';

extension _MessageInputInputTextEditing on _MessageInputWidgetState {
  static const Duration _keyboardShowScrollDelay = Duration(milliseconds: 500);
  static const Duration _keyboardHideScrollDelay = Duration(milliseconds: 200);

  void _handleInputTextChanged() {
    _recordComposerResizeKeepBottomIntent();
    if (_pendingInputTextScroll) {
      return;
    }
    _pendingInputTextScroll = true;
    _inputTextScrollTimer?.cancel();
    _inputTextScrollTimer = Timer(const Duration(milliseconds: 80), () {
      _inputTextScrollTimer = null;
      if (!mounted) {
        _pendingInputTextScroll = false;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingInputTextScroll = false;
        if (!mounted || !_textScrollController.hasClients) {
          return;
        }
        final position = _textScrollController.position;
        if (!position.hasContentDimensions) {
          return;
        }
        final maxScroll = position.maxScrollExtent;
        if (maxScroll <= 0 || position.pixels == maxScroll) {
          return;
        }
        _textScrollController.jumpTo(maxScroll);
      });
    });
  }

  void _syncReferenceComposerFocus(MessageInputProvider input) {
    final referenceMessage = input.referenceMessage;
    if (referenceMessage == null) {
      _lastAutoFocusedReferenceKey = null;
      return;
    }
    final referenceMessageId = _messageIdOf(referenceMessage);
    final referenceKey = referenceMessageId?.isNotEmpty == true
        ? referenceMessageId!
        : '${_channelIdOf(referenceMessage)}-${_sentTimeOf(referenceMessage)}-${identityHashCode(referenceMessage)}';
    if (_lastAutoFocusedReferenceKey == referenceKey) {
      return;
    }
    _lastAutoFocusedReferenceKey = referenceKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (input.mode != MessageInputMode.text) {
        input.setMode(MessageInputMode.text);
      }
    });
  }

  String? _messageIdOf(Message message) {
    try {
      return message.messageId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _channelIdOf(Message message) {
    try {
      return message.channelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  int? _sentTimeOf(Message message) {
    try {
      return message.sentTime;
    } on NoSuchMethodError {
      return null;
    }
  }

  void _toggleInputMode(MessageInputProvider input, MessageInputMode mode) {
    final shouldKeepBottom = _shouldKeepBottomForInputTransition();
    final isOpening = input.mode != mode;
    final targetMode = isOpening ? mode : MessageInputMode.text;
    if (isOpening) {
      if (mode == MessageInputMode.voice && input.referenceMessage != null) {
        input.clearReferenceMessage();
      }
      input.setMode(mode);
    } else {
      input.setMode(MessageInputMode.text);
    }
    if (shouldKeepBottom) {
      _keyboardKeepBottomIntent = true;
      _scheduleChatBottomStabilization(
        delay: _modeShowsKeyboard(targetMode)
            ? _keyboardShowScrollDelay
            : _keyboardHideScrollDelay,
        expectFocus: _modeShowsKeyboard(targetMode),
      );
    }
  }

  void _handleComposerFocusChanged() {
    if (!mounted) {
      return;
    }
    final input = _inputProvider;
    if (!_syncingFocusForInputMode) {
      if (_focusNode.hasFocus) {
        if (input.mode != MessageInputMode.text) {
          input.setMode(MessageInputMode.text);
        }
      } else if (input.mode == MessageInputMode.text) {
        input.setMode(MessageInputMode.initial);
      }
    }
    final shouldKeepBottom = _shouldKeepBottomForInputTransition();
    if (_focusNode.hasFocus) {
      if (shouldKeepBottom) {
        _keyboardKeepBottomIntent = true;
        _scheduleChatBottomStabilization(
          delay: _keyboardShowScrollDelay,
          expectFocus: true,
        );
      }
      return;
    }
    _keyboardKeepBottomIntent = false;
    _keyboardMetricsBottomStabilizeTimer?.cancel();
    if (shouldKeepBottom) {
      _scheduleChatBottomStabilization(
        delay: _keyboardHideScrollDelay,
        expectFocus: false,
      );
    }
  }

  bool _modeShowsKeyboard(MessageInputMode mode) {
    return mode == MessageInputMode.text;
  }

  bool _isChatNearBottom() {
    final controller = context.read<MessageListController?>();
    if (controller != null) {
      return controller.isNearBottom();
    }
    final chat = context.read<ChatProvider>();
    final scrollController = chat.scrollController;
    if (!scrollController.hasClients) {
      return false;
    }
    final position = scrollController.position;
    return position.pixels >= position.maxScrollExtent - 80;
  }

  bool _shouldKeepBottomForInputTransition() {
    final controller = context.read<MessageListController?>();
    if (controller != null) {
      return controller.shouldKeepBottomForInputTransition();
    }
    return _isChatNearBottom();
  }

  void _scheduleChatBottomStabilization({
    required Duration delay,
    required bool expectFocus,
  }) {
    _chatBottomStabilizeTimer?.cancel();
    _chatBottomStabilizeTimer = Timer(delay, () {
      _chatBottomStabilizeTimer = null;
      if (!mounted || _focusNode.hasFocus != expectFocus) {
        return;
      }
      final messageListController = context.read<MessageListController?>();
      if (messageListController != null) {
        unawaited(
          expectFocus
              ? messageListController.keepBottomVisible()
              : messageListController.scrollToBottom(),
        );
        if (!expectFocus) {
          _keyboardKeepBottomIntent = false;
        }
        return;
      }
      final controller = context.read<ChatProvider>().scrollController;
      if (!controller.hasClients) {
        return;
      }
      final position = controller.position;
      final target = position.maxScrollExtent;
      if ((target - position.pixels).abs() > 1) {
        controller.jumpTo(target);
      }
      if (!expectFocus) {
        _keyboardKeepBottomIntent = false;
      }
    });
  }

  void _scheduleKeyboardMetricsKeepBottom() {
    if (_pendingKeyboardMetricsKeepBottom) {
      return;
    }
    _pendingKeyboardMetricsKeepBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingKeyboardMetricsKeepBottom = false;
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      _keepChatBottomVisible();
      _scheduleKeyboardMetricsBottomStabilization(
        delay: const Duration(milliseconds: 120),
      );
    });
  }

  void _scheduleKeyboardMetricsBottomStabilization({required Duration delay}) {
    _keyboardMetricsBottomStabilizeTimer?.cancel();
    _keyboardMetricsBottomStabilizeTimer = Timer(delay, () {
      _keyboardMetricsBottomStabilizeTimer = null;
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      if (!_keyboardKeepBottomIntent &&
          !_shouldKeepBottomForInputTransition()) {
        return;
      }
      _keepChatBottomVisible();
    });
  }

  void _recordComposerResizeKeepBottomIntent() {
    _pendingKeepBottomOnComposerResize =
        _focusNode.hasFocus && _shouldKeepBottomForInputTransition();
    if (!_pendingKeepBottomOnComposerResize ||
        _composerResizeKeepBottomResetScheduled) {
      return;
    }
    _composerResizeKeepBottomResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerResizeKeepBottomResetScheduled = false;
      if (!mounted) {
        return;
      }
      _pendingKeepBottomOnComposerResize = false;
    });
  }

  void _handleComposerSizeChanged() {
    if (!_pendingKeepBottomOnComposerResize) {
      return;
    }
    _pendingKeepBottomOnComposerResize = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) {
        return;
      }
      _keepChatBottomVisible();
    });
  }

  void _keepChatBottomVisible() {
    final messageListController = context.read<MessageListController?>();
    if (messageListController != null) {
      unawaited(messageListController.keepBottomVisible());
      return;
    }
    _scrollLegacyChatListToBottomIfNeeded();
  }

  void _scrollLegacyChatListToBottomIfNeeded() {
    final controller = context.read<ChatProvider>().scrollController;
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    final target = position.maxScrollExtent;
    if ((target - position.pixels).abs() > 1) {
      controller.jumpTo(target);
    }
  }

  void _insertText(
    BuildContext context,
    String value,
    MessageInputProvider input,
  ) {
    final oldValue = _controller.value;
    final text = oldValue.text;
    final selection = oldValue.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final updatedText = start == end && end == text.length
        ? '$text$value'
        : text.replaceRange(start, end, value);
    final offset = start + value.length;
    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: offset),
    );
    _handleDraftChanged(context, input, updatedText);
  }

  void _deleteBackward(BuildContext context, MessageInputProvider input) {
    final oldValue = _controller.value;
    final text = oldValue.text;
    if (text.isEmpty) {
      return;
    }
    final selection = oldValue.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    if (start != end) {
      final updatedText = text.replaceRange(start, end, '');
      _controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: start),
      );
      _handleDraftChanged(context, input, updatedText);
      return;
    }
    if (start <= 0) {
      return;
    }
    final deleteStart = text
        .substring(0, start)
        .characters
        .skipLast(1)
        .toString()
        .length;
    final updatedText = text.replaceRange(deleteStart, start, '');
    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: deleteStart),
    );
    _handleDraftChanged(context, input, updatedText);
  }
}
