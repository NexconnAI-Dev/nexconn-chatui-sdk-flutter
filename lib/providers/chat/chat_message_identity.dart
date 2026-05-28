part of '../chat_provider.dart';

extension _ChatProviderMessageIdentity on ChatProvider {
  bool _isLegacyPlaceholderMessage(Message message) =>
      message.runtimeType.toString() == '_RecalledPlaceholderMessage';

  bool _sameChannel(Message message) {
    if (_isLegacyPlaceholderMessage(message)) {
      return false;
    }
    final messageChannelType = message.channelType;
    final messageChannelId = message.channelId;
    if (messageChannelType == null ||
        messageChannelId == null ||
        messageChannelId.isEmpty) {
      return false;
    }
    return _matchesChannelIdentifier(
      ChannelIdentifier(
        channelType: messageChannelType,
        channelId: messageChannelId,
        subChannelId: _subChannelIdOf(message),
      ),
    );
  }

  bool _matchesChannelIdentifier(ChannelIdentifier identifier) {
    return identifier.channelType == channel.channelType &&
        identifier.channelId == channel.channelId &&
        _normalizedSubChannelId(identifier.subChannelId) ==
            _normalizedSubChannelId(channel.channelIdentifier.subChannelId);
  }

  bool _isRecallMessage(Message message) {
    if (_isLegacyPlaceholderMessage(message)) {
      return true;
    }
    try {
      return message.messageType == MessageType.recall;
    } on NoSuchMethodError {
      return false;
    }
  }

  MessageDirection? _directionOf(Message message) {
    try {
      return message.direction;
    } on NoSuchMethodError {
      return null;
    }
  }

  SentStatus? _sentStatusOf(Message message) {
    try {
      return message.sentStatus;
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

  Message? _resolveRecalledMessage(
    Message? recalledMessage, {
    Message? original,
  }) {
    if (recalledMessage != null && _isRecallMessage(recalledMessage)) {
      return recalledMessage;
    }
    return null;
  }

  String _keyOf(Message message) {
    if (_isLegacyPlaceholderMessage(message)) {
      return 'legacy-placeholder:${identityHashCode(message)}';
    }
    try {
      return message.messageId ??
          message.clientId?.toString() ??
          '${message.channelId}:${message.sentTime}:${message.senderUserId}';
    } on NoSuchMethodError {
      return 'unknown:${identityHashCode(message)}';
    }
  }

  Set<String> _identityKeysOf(Message message) {
    if (_isLegacyPlaceholderMessage(message)) {
      return const <String>{};
    }
    try {
      final messageId = message.messageId;
      final clientId = _clientIdOf(message);
      final mediaLocalKey = _mediaLocalIdentityKeyOf(message);
      final keys = <String>{
        if (messageId != null && messageId.isNotEmpty) 'uid:$messageId',
        if (clientId != null) 'client:$clientId',
        if (mediaLocalKey != null) mediaLocalKey,
      };
      if (keys.isEmpty) {
        final fallbackKey = _fallbackIdentityKeyOf(message);
        if (fallbackKey != null) {
          keys.add(fallbackKey);
        }
      }
      return keys;
    } on NoSuchMethodError {
      return const <String>{};
    }
  }

  int? _clientIdOf(Message message) {
    try {
      return message.clientId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _subChannelIdOf(Message message) {
    try {
      return message.subChannelId;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _normalizedSubChannelId(String? subChannelId) {
    return subChannelId == null || subChannelId.isEmpty ? null : subChannelId;
  }

  bool _sharesIdentity(Message message, Set<String> identityKeys) {
    final existingKeys = _identityKeysOf(message);
    return existingKeys.any(identityKeys.contains);
  }

  String? _mediaLocalIdentityKeyOf(Message message) {
    if (message is! MediaMessage) {
      return null;
    }
    final channelType = message.channelType;
    final channelId = message.channelId;
    final messageType = message.messageType;
    final localPath = _mediaLocalPathOf(message);
    if (channelType == null ||
        channelId == null ||
        channelId.isEmpty ||
        messageType == null ||
        localPath == null ||
        localPath.isEmpty) {
      return null;
    }
    return 'media-local:${channelType.name}:$channelId:'
        '${_normalizedSubChannelId(_subChannelIdOf(message))}:'
        '${messageType.name}:$localPath';
  }

  String? _mediaLocalPathOf(MediaMessage message) {
    try {
      return message.localPath;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _mediaRemotePathOf(MediaMessage message) {
    try {
      return message.remotePath;
    } on NoSuchMethodError {
      return null;
    }
  }

  String? _fallbackIdentityKeyOf(Message message) {
    final channelType = message.channelType;
    final channelId = message.channelId;
    final sentTime = message.sentTime;
    final senderUserId = message.senderUserId;
    final messageType = message.messageType;
    if (channelType == null ||
        channelId == null ||
        channelId.isEmpty ||
        sentTime == null ||
        senderUserId == null ||
        senderUserId.isEmpty ||
        messageType == null) {
      return null;
    }
    return 'fallback:${channelType.name}:$channelId:'
        '${_normalizedSubChannelId(_subChannelIdOf(message))}:'
        '$sentTime:$senderUserId:${messageType.name}';
  }
}
