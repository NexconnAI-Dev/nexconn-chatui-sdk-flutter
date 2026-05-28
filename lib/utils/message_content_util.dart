import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:rongcloud_im_wrapper_plugin/rongcloud_im_wrapper_plugin.dart'
    show RCIMIWConversationType;

import '../l10n/nexconn_chat_ui_localizations.dart';
import '../l10n/nexconn_chat_ui_localizations_en.dart';

String get deletedForEveryoneMessageText =>
    NexconnChatUILocalizationsEn().messageDeletedForEveryone;

String deletedMessageText({NexconnChatUILocalizations? localizations}) {
  final l10n = localizations ?? NexconnChatUILocalizationsEn();
  return l10n.localeName.startsWith('zh') ? '消息已删除' : 'Message deleted';
}

String messageSummary(
  Message? message, {
  NexconnChatUILocalizations? localizations,
}) {
  final l10n = localizations ?? NexconnChatUILocalizationsEn();
  if (message == null) {
    return l10n.chatMessageListEmpty;
  }
  if (message is TextMessage) {
    return message.text ?? '';
  }
  if (message is ReferenceMessage) {
    return message.text ?? l10n.messageSummaryReply;
  }
  if (message is ImageMessage) {
    return l10n.messageSummaryImage;
  }
  if (message is GIFMessage) {
    return l10n.messageSummaryGif;
  }
  if (message is HDVoiceMessage) {
    return l10n.messageSummaryVoice;
  }
  if (message is ShortVideoMessage) {
    return l10n.messageSummaryVideo;
  }
  if (message is FileMessage) {
    final name = message.name?.trim();
    return name == null || name.isEmpty
        ? l10n.messageSummaryFile
        : '${l10n.messageSummaryFile} $name';
  }
  if (message is LocationMessage) {
    return l10n.messageSummaryLocation;
  }
  if (message is CombineMessage) {
    return l10n.messageSummaryCombinedForward;
  }
  if (message is GroupNotificationMessage) {
    return l10n.messageSummaryGroupNotification;
  }
  if (message is CustomMessage) {
    final summary = _customGroupNotificationSummary(message, l10n);
    if (summary != null) {
      return summary;
    }
  }
  if (message.messageType == MessageType.recall) {
    return l10n.messageDeletedForEveryone;
  }
  return '[${message.messageType?.name ?? l10n.messageSummaryUnknown}]';
}

String channelListMessageSummary(
  Message? message, {
  NexconnChatUILocalizations? localizations,
  ChannelType? channelType,
  String? currentUserId,
}) {
  final l10n = localizations ?? NexconnChatUILocalizationsEn();
  if (message == null) {
    if (channelType == ChannelType.system) {
      return '';
    }
    return l10n.chatMessageListEmpty;
  }

  String summary;
  if (message is GIFMessage) {
    summary = l10n.messageSummaryImage;
  } else if (message is CombineMessage) {
    summary = '[${l10n.combineMessageChatHistoryLabel}]';
  } else {
    summary = messageSummary(message, localizations: l10n);
  }
  summary = summary
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  final isGroupChannel = channelType == ChannelType.group;
  final isReceivedMessage =
      _messageDirectionOf(message) != MessageDirection.send;
  final senderId = _senderUserIdOf(message)?.trim();
  final isCurrentUser =
      currentUserId != null &&
      currentUserId.isNotEmpty &&
      senderId != null &&
      senderId.isNotEmpty &&
      senderId == currentUserId;
  if (!isGroupChannel || !isReceivedMessage || isCurrentUser) {
    return summary;
  }

  final senderName =
      _messageUserInfoOf(message)?.alias?.trim() ??
      _messageUserInfoOf(message)?.name?.trim() ??
      senderId;
  if (senderName == null || senderName.isEmpty) {
    return summary;
  }

  final separator = l10n.localeName.startsWith('zh') ? '：' : ': ';
  return '$senderName$separator$summary';
}

MessageDirection? _messageDirectionOf(Message message) {
  try {
    return message.direction;
  } on NoSuchMethodError {
    return null;
  }
}

String? _senderUserIdOf(Message message) {
  try {
    return message.senderUserId;
  } on NoSuchMethodError {
    return null;
  }
}

UserInfo? _messageUserInfoOf(Message message) {
  try {
    return message.userInfo;
  } on NoSuchMethodError {
    return null;
  }
}

const String _combineMessageGroupChatHistoryTitle = 'Group Chat History';

String combineMessageTitle(
  List<String>? names, {
  NexconnChatUILocalizations? localizations,
  ChannelType? sourceChannelType,
}) {
  final l10n = localizations ?? NexconnChatUILocalizationsEn();
  if (sourceChannelType == ChannelType.group) {
    return _combineMessageGroupChatHistoryTitle;
  }
  final cleanNames = _cleanNames(names);
  if (cleanNames.isEmpty) {
    return l10n.combineMessageTitle(l10n.combineMessageChatHistoryLabel);
  }
  final connector = l10n.localeName.startsWith('zh') ? '和' : ' and ';
  final displayNames = cleanNames.length == 1
      ? cleanNames.first
      : cleanNames.length == 2
      ? '${cleanNames.first}$connector${cleanNames[1]}'
      : cleanNames.first;
  return l10n.combineMessageTitle(displayNames);
}

ChannelType? combineMessageSourceChannelType(
  CombineMessage message, {
  ChannelType? fallbackChannelType,
}) {
  final embeddedSourceChannelType = _combineMessageInfoSourceChannelType(
    message.msgList,
  );
  if (embeddedSourceChannelType == ChannelType.group) {
    return embeddedSourceChannelType;
  }
  final rawSourceChannelType = _safeCombineMessageRawSourceChannelType(message);
  if (rawSourceChannelType == ChannelType.group) {
    return rawSourceChannelType;
  }
  final sourceChannelType = _safeCombineMessageSourceChannelType(message);
  if (sourceChannelType == ChannelType.group) {
    return sourceChannelType;
  }
  if (fallbackChannelType == ChannelType.group) {
    return fallbackChannelType;
  }
  return sourceChannelType ??
      rawSourceChannelType ??
      embeddedSourceChannelType ??
      fallbackChannelType;
}

ChannelType? _safeCombineMessageSourceChannelType(CombineMessage message) {
  try {
    return message.sourceChannelType;
  } on RangeError {
    return null;
  } on NoSuchMethodError {
    return null;
  }
}

ChannelType? _safeCombineMessageRawSourceChannelType(CombineMessage message) {
  try {
    return _channelTypeFromValue((message as dynamic).combineConversationType);
  } on RangeError {
    return null;
  } on NoSuchMethodError {
    return null;
  }
}

ChannelType? _combineMessageInfoSourceChannelType(
  List<CombineMessageInfo>? infos,
) {
  ChannelType? fallback;
  for (final info in infos ?? const <CombineMessageInfo>[]) {
    final content = info.content;
    if (content is! Map) {
      continue;
    }
    final type = _channelTypeFromValue(
      content['conversationType'] ?? content['sourceChannelType'],
    );
    if (type == ChannelType.group) {
      return type;
    }
    fallback ??= type;
  }
  return fallback;
}

ChannelType? _channelTypeFromValue(Object? value) {
  if (value is ChannelType) {
    return value;
  }
  if (value is RCIMIWConversationType) {
    return switch (value) {
      RCIMIWConversationType.private => ChannelType.direct,
      RCIMIWConversationType.group => ChannelType.group,
      RCIMIWConversationType.chatroom => ChannelType.open,
      RCIMIWConversationType.system => ChannelType.system,
      RCIMIWConversationType.ultraGroup => ChannelType.community,
      _ => null,
    };
  }
  if (value is int) {
    return switch (value) {
      1 => ChannelType.direct,
      2 => ChannelType.group,
      3 => ChannelType.group,
      4 => ChannelType.system,
      5 => ChannelType.community,
      _ => null,
    };
  }
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) {
    return null;
  }
  final intValue = int.tryParse(text);
  if (intValue != null) {
    return _channelTypeFromValue(intValue);
  }
  return switch (text) {
    'direct' || 'private' => ChannelType.direct,
    'group' => ChannelType.group,
    'open' || 'chatroom' => ChannelType.open,
    'community' || 'ultragroup' || 'ultra_group' => ChannelType.community,
    'system' => ChannelType.system,
    _ => null,
  };
}

List<String> _cleanNames(List<String>? names) {
  final seen = <String>{};
  final result = <String>[];
  for (final name in names ?? const <String>[]) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) {
      continue;
    }
    seen.add(trimmed);
    result.add(trimmed);
  }
  return result;
}

String? _customGroupNotificationSummary(
  CustomMessage message,
  NexconnChatUILocalizations l10n,
) {
  final fields = message.fields;
  if (fields == null) {
    return null;
  }
  final operation = fields['operation']?.toString();
  final data = fields['data'];
  if (operation == null || data is! Map) {
    return null;
  }

  final operatorName =
      data['operatorNickname']?.toString().trim().isNotEmpty == true
      ? data['operatorNickname'].toString().trim()
      : fields['operatorUserId']?.toString().trim() ?? '';
  final targetNames = _customGroupTargetNames(data);
  final isZh = l10n.localeName.startsWith('zh');

  return switch (operation) {
    'Add' =>
      targetNames.isEmpty
          ? (isZh
                ? '$operatorName 邀请成员加入了群组'
                : '$operatorName invited members to the group')
          : (isZh
                ? '$operatorName 邀请 $targetNames 加入了群组'
                : '$operatorName invited $targetNames to the group'),
    'Create' =>
      isZh ? '$operatorName 创建了群组' : '$operatorName created the group',
    'Kicked' =>
      targetNames.isEmpty
          ? (isZh
                ? '$operatorName 将成员移出了群组'
                : '$operatorName removed members from the group')
          : (isZh
                ? '$operatorName 将 $targetNames 移出了群组'
                : '$operatorName removed $targetNames from the group'),
    _ => null,
  };
}

String _customGroupTargetNames(Map<dynamic, dynamic> data) {
  final names = data['targetUserDisplayNames'];
  if (names is! List) {
    return '';
  }
  final values = names
      .map((name) => name?.toString().trim() ?? '')
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  return values.join(' ');
}

String referenceMessageContent(
  Message? message, {
  NexconnChatUILocalizations? localizations,
  bool isDeleted = false,
}) {
  final l10n = localizations ?? NexconnChatUILocalizationsEn();
  if (message == null) {
    return '';
  }
  if (isDeleted) {
    return deletedMessageText(localizations: l10n);
  }
  if (message is TextMessage) {
    return message.text ?? '';
  }
  if (message is ReferenceMessage) {
    return message.text ?? '';
  }
  if (message is ImageMessage) {
    return l10n.messageSummaryImage;
  }
  if (message is GIFMessage) {
    return l10n.messageSummaryGif;
  }
  if (message is HDVoiceMessage) {
    final duration = message.duration;
    return duration == null
        ? l10n.messageSummaryVoice
        : '${l10n.messageSummaryVoice} $duration \'\'';
  }
  if (message is ShortVideoMessage) {
    return l10n.messageSummaryVideo;
  }
  if (message is FileMessage) {
    final name = message.name;
    return name == null || name.isEmpty
        ? l10n.messageSummaryFile
        : '${l10n.messageSummaryFile} $name';
  }
  if (message is LocationMessage) {
    return l10n.messageSummaryLocation;
  }
  return messageSummary(message, localizations: l10n);
}
