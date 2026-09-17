// ignore_for_file: use_build_context_synchronously

part of '../message_input_widget.dart';

extension _MessageInputMentionPickerExtension on _MessageInputWidgetState {
  Future<void> _maybePickMentionCandidate(
    BuildContext context,
    MessageInputProvider input,
    String previousDraft,
    String currentDraft,
  ) async {
    if (_isPickingMention || !_canPickMention) {
      return;
    }
    if (currentDraft.length <= previousDraft.length) {
      return;
    }
    final selection = _controller.selection;
    final cursor = selection.isValid
        ? selection.baseOffset
        : currentDraft.length;
    if (cursor <= 0 || cursor > currentDraft.length) {
      return;
    }
    if (currentDraft[cursor - 1] != '@') {
      return;
    }
    _isPickingMention = true;
    try {
      final candidate = await _pickMentionCandidate(context);
      if (!mounted || candidate == null) {
        return;
      }
      final currentContext = this.context;
      _insertMentionCandidate(currentContext, input, candidate);
    } finally {
      _isPickingMention = false;
    }
  }

  bool get _canPickMention {
    return widget.config.enableMention &&
        (widget.config.mentionPicker != null ||
            widget.config.mentionResolver != null) &&
        widget.channel.channelType == ChannelType.group;
  }

  Future<MessageInputMentionCandidate?> _pickMentionCandidate(
    BuildContext context,
  ) async {
    final picker = widget.config.mentionPicker;
    if (picker != null) {
      return picker(context, widget.channel);
    }
    final resolver = widget.config.mentionResolver;
    if (resolver == null) {
      return null;
    }
    final candidates = await resolver(context, widget.channel);
    if (!mounted) {
      return null;
    }
    final currentContext = this.context;
    return showModalBottomSheet<MessageInputMentionCandidate>(
      context: currentContext,
      builder: (context) {
        if (candidates.isEmpty) {
          return SafeArea(
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  widget.config.emptyMentionCandidatesText ??
                      context.chatUIL10n.messageInputEmptyMentionCandidates,
                ),
              ),
            ),
          );
        }
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final candidate = candidates[index];
              final content =
                  widget.config.mentionCandidateBuilder?.call(
                    context,
                    candidate,
                  ) ??
                  ListTile(
                    leading: _defaultMentionAvatar(candidate),
                    title: Text(candidate.displayName),
                  );
              return InkWell(
                onTap: () => Navigator.of(context).pop(candidate),
                child: content,
              );
            },
          ),
        );
      },
    );
  }

  void _insertMentionCandidate(
    BuildContext context,
    MessageInputProvider input,
    MessageInputMentionCandidate candidate,
  ) {
    final oldValue = _controller.value;
    final text = oldValue.text;
    final selection = oldValue.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final mentionText = '${candidate.displayName} ';
    final updatedText = text.replaceRange(start, end, mentionText);
    final offset = start + mentionText.length;
    _controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: offset),
    );
    input.addMention(candidate.userId, candidate.displayName);
    _handleDraftChanged(context, input, updatedText);
  }

  Widget _defaultMentionAvatar(MessageInputMentionCandidate candidate) {
    final label = candidate.displayName.trim();
    final initial = label.characters.firstOrNull?.toUpperCase() ?? '@';
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFE8F1FF),
      foregroundColor: const Color(0xFF147BFF),
      child: Text(
        initial,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
