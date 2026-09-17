part of '../message_bubble.dart';

abstract class _TypedMessageBubble extends _MessageBubbleBase {
  _TypedMessageBubble(_MessageBubbleArgs args)
    : super(
        channel: args.channel,
        message: args.message,
        config: args.config,
        selected: args.selected,
        onTap: args.onTap,
        onDoubleTap: args.onDoubleTap,
        onLongPress: args.onLongPress,
        onLongPressStart: args.onLongPressStart,
        onSwipe: args.onSwipe,
        onAvatarTap: args.onAvatarTap,
        onAvatarLongPress: args.onAvatarLongPress,
        multiSelectMode: args.multiSelectMode,
        showTime: args.showTime,
        customMessageBubbleBuilders: args.customMessageBubbleBuilders,
      );
}

class _TextMessageBubble extends _TypedMessageBubble {
  _TextMessageBubble(super.args);

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    final edited = _isSuccessfullyEditedMessage(message);
    return _LinkifiedText(
      text: (message as TextMessage).text ?? '',
      style:
          style.textStyle ??
          TextStyle(color: style.textColor, fontSize: kBubbleTextFontSize),
      linkStyle: (style.textStyle ?? TextStyle(color: style.textColor))
          .copyWith(
            decoration: TextDecoration.underline,
            decorationColor: style.textColor,
          ),
      suffix: edited ? '（${context.chatUIL10n.messageEdited}）' : null,
      suffixStyle: _editedMarkerStyle(message),
      onLinkTap: (uri) => _handleLinkTap(context, uri),
      onPhoneTap: (phoneNumber) => _handlePhoneTap(context, phoneNumber),
    );
  }
}

class _ReferenceMessageBubble extends _TypedMessageBubble {
  _ReferenceMessageBubble(super.args);

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    final reference = message as ReferenceMessage;
    final referenceMsg = reference.referenceMsg;
    final referenceStatus = _safeReferenceStatus(reference);
    final unavailableFromProvider =
        Provider.of<ChatProvider?>(
          context,
        )?.isReferenceMessageUnavailable(referenceMsg) ??
        false;
    final referenceDeleted =
        referenceStatus == ReferenceMessageStatus.deleted ||
        (unavailableFromProvider &&
            referenceStatus != ReferenceMessageStatus.recalled);
    final referenceRecalled =
        referenceStatus == ReferenceMessageStatus.recalled;
    final referenceUnavailable = referenceDeleted || referenceRecalled;
    final sent = message.direction == MessageDirection.send;
    final referenceContent = referenceMessageContent(
      referenceMsg,
      localizations: context.chatUIL10n,
      isDeleted: referenceDeleted,
      isRecalled: referenceRecalled,
    );
    final showReferenceImage =
        !referenceUnavailable && referenceMsg is ImageMessage;
    final referenceTitleContent = showReferenceImage ? '' : referenceContent;
    final profileProvider = config.profileProvider;
    final referenceTitle = profileProvider != null && referenceMsg != null
        ? FutureBuilder<ChatProfileInfo?>(
            future: profileProvider(
              _referenceProfileChannel(referenceMsg),
              message: referenceMsg,
            ),
            initialData: _profileFromReferenceMessage(referenceMsg),
            builder: (context, snapshot) => _referenceTitleText(
              context,
              referenceMsg,
              referenceTitleContent,
              style,
              sent,
              snapshot.data,
            ),
          )
        : _referenceTitleText(
            context,
            referenceMsg,
            referenceTitleContent,
            style,
            sent,
            null,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (referenceUnavailable)
          Container(
            margin: const EdgeInsets.only(
              bottom: kBubbleRefTextPadding,
              right: kBubbleRefTextPadding,
            ),
            child: referenceTitle,
          )
        else if (referenceMsg != null)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ReferenceMessageTapNotification(referenceMsg).dispatch(context),
            child: Container(
              margin: const EdgeInsets.only(
                bottom: kBubbleRefTextPadding,
                right: kBubbleRefTextPadding,
              ),
              child: showReferenceImage
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        referenceTitle,
                        const SizedBox(height: 6),
                        _referencedImagePreview(context, referenceMsg, style),
                      ],
                    )
                  : referenceTitle,
            ),
          ),
        _LinkifiedText(
          text: reference.text ?? '',
          style: style.textStyle ?? TextStyle(color: style.textColor),
          linkStyle: (style.textStyle ?? TextStyle(color: style.textColor))
              .copyWith(
                decoration: TextDecoration.underline,
                decorationColor: style.textColor,
              ),
          suffix: _isSuccessfullyEditedMessage(message)
              ? '（${context.chatUIL10n.messageEdited}）'
              : null,
          suffixStyle: _editedMarkerStyle(message),
          onLinkTap: (uri) => _handleLinkTap(context, uri),
          onPhoneTap: (phoneNumber) => _handlePhoneTap(context, phoneNumber),
        ),
      ],
    );
  }
}

class _ImageMessageBubble extends _TypedMessageBubble {
  _ImageMessageBubble(super.args);

  @override
  bool get usesPlainMediaPreview => true;

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    final media = message as MediaMessage;
    final preview = _imageBubble(context, media, style);
    return Semantics(
      label: messageSummary(message, localizations: context.chatUIL10n),
      image: true,
      child: preview,
    );
  }
}

class _VoiceMessageBubble extends _TypedMessageBubble {
  _VoiceMessageBubble(super.args);

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    return _voiceBubble(context, message as HDVoiceMessage, style);
  }
}

class _ShortVideoMessageBubble extends _TypedMessageBubble {
  _ShortVideoMessageBubble(super.args);

  @override
  bool get usesPlainMediaPreview => true;

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    final video = message as ShortVideoMessage;
    return GestureDetector(
      key: MessageBubble.mediaPreviewContentKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleMediaPreviewTap(context, video),
      child: _videoBubble(context, video, style),
    );
  }
}

class _FileMessageBubble extends _TypedMessageBubble {
  _FileMessageBubble(super.args);

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    final file = message as FileMessage;
    return GestureDetector(
      key: MessageBubble.filePreviewContentKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleFilePreviewTap(context, file),
      child: _fileBubble(context, file, style),
    );
  }
}

class _CombineMessageBubble extends _TypedMessageBubble {
  _CombineMessageBubble(super.args);

  @override
  bool get usesPlainMediaPreview => true;

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    return _combineBubble(context, message as CombineMessage);
  }
}

class _LocationMessageBubble extends _TypedMessageBubble {
  _LocationMessageBubble(super.args);

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    final location = message as LocationMessage;
    return _mediaLabel(
      'NexconnLightIcon/Local.png',
      location.poiName?.isNotEmpty == true
          ? location.poiName!
          : '[Location] ${location.latitude ?? 0}, ${location.longitude ?? 0}',
      style,
    );
  }
}

class _GroupNotificationMessageBubble extends _TypedMessageBubble {
  _GroupNotificationMessageBubble(super.args);

  @override
  bool get withoutBubble => true;

  @override
  bool get withoutStatusLine => true;

  @override
  double get extraOuterVerticalPadding => kBubblePaddingVertical * 2;

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    return _groupNotificationTip(context);
  }
}

class _InformationNotificationMessageBubble extends _TypedMessageBubble {
  _InformationNotificationMessageBubble(super.args);

  @override
  bool get withoutBubble => true;

  @override
  bool get withoutStatusLine => true;

  @override
  double get extraOuterVerticalPadding => kBubblePaddingVertical;

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Text(
          (message as InformationNotificationMessage).message ??
              context.chatUIL10n.messageSummaryInformationNotification,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF8C919C)),
        ),
      ),
    );
  }
}

class _RecallMessageBubble extends _TypedMessageBubble {
  _RecallMessageBubble(super.args);

  @override
  bool get withoutBubble => true;

  @override
  bool get withoutStatusLine => true;

  @override
  double get verticalPadding => kBubblePaddingVertical * 2;

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    return Text(
      messageSummary(message, localizations: context.chatUIL10n),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: const Color(0xFF8C919C)),
    );
  }
}

class _UnknownMessageBubble extends _TypedMessageBubble {
  _UnknownMessageBubble(super.args);

  @override
  Widget buildMessageContent(BuildContext context, MessageStyleConfig style) {
    return Text(
      messageSummary(message, localizations: context.chatUIL10n),
      style: style.textStyle ?? TextStyle(color: style.textColor),
    );
  }
}
