part of '../message_bubble.dart';

extension _MessageBubbleReferenceHelpers on _MessageBubbleBase {
  String _senderName(ChatProfileInfo? profile) {
    final resolvedName = profile?.name?.trim();
    if (resolvedName != null && resolvedName.isNotEmpty) {
      return resolvedName;
    }
    try {
      return message.userInfo?.alias ??
          message.userInfo?.name ??
          message.senderUserId ??
          '';
    } catch (_) {
      return message.senderUserId ?? '';
    }
  }

  String _referenceSenderName(Message? message, {ChatProfileInfo? profile}) {
    final resolvedName = profile?.name?.trim();
    if (resolvedName != null && resolvedName.isNotEmpty) {
      return resolvedName;
    }
    if (message == null) {
      return '';
    }
    try {
      final userInfo = message.userInfo;
      return userInfo?.alias ?? userInfo?.name ?? message.senderUserId ?? '';
    } catch (_) {
      return message.senderUserId ?? '';
    }
  }

  Widget _referenceTitleText(
    BuildContext context,
    Message? referenceMsg,
    String referenceContent,
    MessageStyleConfig style,
    bool sent,
    ChatProfileInfo? profile,
  ) {
    final referenceSenderName = _referenceSenderName(
      referenceMsg,
      profile: profile,
    );
    return Text(
      '| ${context.chatUIL10n.messageInputReplyTo(referenceSenderName, referenceContent)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: sent ? style.textColor : const Color(0xFF8C919C),
        fontSize: kBubbleRefTextFontSize,
      ),
    );
  }

  BaseChannel _referenceProfileChannel(Message message) {
    try {
      final type = message.channelType;
      final id = message.channelId;
      if (type != null && id != null && id.isNotEmpty) {
        return BaseChannel(type, id);
      }
    } catch (_) {
      // Fall back to the surrounding channel or message channel.
    }
    return channel ?? _messageChannel() ?? BaseChannel(ChannelType.direct, '');
  }

  ChatProfileInfo? _profileFromReferenceMessage(Message message) {
    try {
      final userInfo = message.userInfo;
      if (userInfo == null) {
        return null;
      }
      return ChatProfileInfo(
        id: userInfo.userId ?? message.senderUserId ?? '',
        name: userInfo.alias ?? userInfo.name,
        portraitUri: userInfo.avatarUrl,
        extra: userInfo.extra,
      );
    } catch (_) {
      return null;
    }
  }
}
