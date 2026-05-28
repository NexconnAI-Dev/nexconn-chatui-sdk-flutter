part of '../message_input_widget.dart';

extension _MessageInputInputArea on _MessageInputWidgetState {
  Widget _buildInputArea(
    BuildContext context,
    MessageInputProvider input,
    ChatProvider chat,
  ) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    if (input.mode == MessageInputMode.voice) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: kInputFieldMinHeight,
          maxHeight: kInputFieldMinHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: kInputFieldContentPaddingV,
          ),
          child: _buildVoiceInputButton(context, input, theme),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: kInputFieldMinHeight,
        maxHeight: kInputFieldMaxHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: kInputFieldContentPaddingV,
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _textScrollController,
          minLines: 1,
          maxLines: widget.config.maxLines,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.send,
          onEditingComplete: () {},
          scrollPhysics: const BouncingScrollPhysics(),
          cursorHeight: kInputFieldFontHeight,
          style: const TextStyle(
            fontSize: kInputFieldFontSize,
            height: kInputFieldFontHeight / kInputFieldFontSize,
          ).copyWith(color: theme.primaryTextColor),
          onTap: () => input.setMode(MessageInputMode.text),
          onChanged: (value) => _handleDraftChanged(context, input, value),
          onSubmitted: (_) {
            if (input.hasDraft) {
              _sendText(context, input, chat);
            } else {
              _showEmptyTextWarning(context, input);
            }
          },
          decoration:
              widget.config.decoration ??
              InputDecoration(
                hintText:
                    widget.config.hintText ??
                    context.chatUIL10n.messageInputHint,
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
              ),
        ),
      ),
    );
  }

  Widget _buildVoiceInputButton(
    BuildContext context,
    MessageInputProvider input,
    NexconnThemeTokens theme,
  ) {
    final isRecording = input.isVoiceRecording;
    final text =
        widget.config.voiceInputActionText ??
        context.chatUIL10n.messageInputVoiceAction;
    return Listener(
      onPointerDown: (_) => _handleVoicePointerDown(context, input),
      onPointerMove: (event) => _handleVoicePointerMove(context, input, event),
      onPointerCancel: (_) {
        input.clearVoiceRecordingState();
        if (widget.config.voiceDraftResolver == null) {
          unawaited(_cancelActiveVoiceRecording());
        }
      },
      onPointerUp: (_) => _handleVoicePointerUp(context, input),
      child: Container(
        height: kInputFieldMinHeight - 2 * kInputFieldContentPaddingV,
        decoration: BoxDecoration(
          color: isRecording
              ? theme.primaryColor.withValues(alpha: .78)
              : theme.primaryColor,
          borderRadius: BorderRadius.circular(kInputFieldBorderRadius),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChatUIAsset.image(
              'NexconnLightIcon/Audio.png',
              width: kInputFieldVoiceIconSize,
              height: kInputFieldVoiceIconSize,
              color: Colors.white,
            ),
            const SizedBox(width: kInputFieldVoiceSpace),
            Text(
              input.isVoiceCanceling
                  ? context.chatUIL10n.messageInputVoiceReleaseToCancel
                  : text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: kInputFieldVoiceFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
