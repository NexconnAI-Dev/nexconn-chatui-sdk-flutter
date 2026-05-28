part of '../chat_provider.dart';

extension _ChatProviderForwardHelpers on ChatProvider {
  void _notifyForwardTargetMessageUpsert(Message message) {
    if (_sameChannel(message)) {
      _upsertMessage(message);
      return;
    }
    engineProvider.notifyChannelMessageUpserted(message);
  }

  Future<MessageParams?> _forwardMessageParams(Message message) async {
    if (message is CombineMessage) {
      return _forwardCombineMessageParams(message);
    }
    if (message is TextMessage) {
      final text = message.text?.trim();
      return text == null || text.isEmpty
          ? null
          : TextMessageParams(text: text, needReceipt: message.needReceipt);
    }
    if (message is ReferenceMessage) {
      final text = message.text?.trim();
      final referenceMessage = message.referenceMsg;
      if (text == null || text.isEmpty || referenceMessage == null) {
        return null;
      }
      return ReferenceMessageParams(
        referenceMessage: referenceMessage,
        text: text,
        needReceipt: message.needReceipt,
      );
    }
    if (message is ImageMessage) {
      final path = await _mediaForwardPath(message);
      return path == null
          ? null
          : ImageMessageParams(path: path, needReceipt: message.needReceipt);
    }
    if (message is GIFMessage) {
      final path = await _mediaForwardPath(message);
      return path == null
          ? null
          : GIFMessageParams(path: path, needReceipt: message.needReceipt);
    }
    if (message is HDVoiceMessage) {
      final path = await _mediaForwardPath(message);
      return path == null
          ? null
          : HDVoiceMessageParams(
              path: path,
              duration: message.duration ?? 0,
              needReceipt: message.needReceipt,
            );
    }
    if (message is ShortVideoMessage) {
      final path = await _mediaForwardPath(message);
      return path == null
          ? null
          : ShortVideoMessageParams(
              path: path,
              duration: message.duration ?? 0,
              needReceipt: message.needReceipt,
            );
    }
    if (message is FileMessage) {
      final path = await _mediaForwardPath(message);
      return path == null
          ? null
          : FileMessageParams(path: path, needReceipt: message.needReceipt);
    }
    return null;
  }

  MessageParams? _forwardCombineMessageParams(CombineMessage message) {
    final summaryList = message.summaryList;
    final nameList = message.nameList;
    final msgList = message.msgList;
    final jsonMsgKey = message.jsonMsgKey?.trim();
    final hasRemotePayloadKey = jsonMsgKey != null && jsonMsgKey.isNotEmpty;
    if (summaryList == null ||
        summaryList.isEmpty ||
        nameList == null ||
        nameList.isEmpty ||
        ((msgList == null || msgList.isEmpty) && !hasRemotePayloadKey)) {
      return null;
    }
    final normalizedMsgList = (msgList ?? const <CombineMessageInfo>[])
        .map((info) => _forwardCombineInfo(message, info))
        .whereType<CombineMessageInfo>()
        .toList(growable: false);
    if (normalizedMsgList.isEmpty && !hasRemotePayloadKey) {
      return null;
    }

    return CombineMessageParams(
      sourceChannelType: message.sourceChannelType ?? channel.channelType,
      summaryList: List<String>.of(summaryList),
      nameList: List<String>.of(nameList),
      msgList: normalizedMsgList,
      needReceipt: message.needReceipt,
      jsonMsgKey: jsonMsgKey,
    );
  }

  bool _shouldForwardCombineMessageAsRaw(CombineMessage message) {
    final msgList = message.msgList;
    final jsonMsgKey = message.jsonMsgKey?.trim();
    return (msgList == null || msgList.isEmpty) &&
        jsonMsgKey != null &&
        jsonMsgKey.isNotEmpty;
  }

  CombineMessageParams? _rawForwardCombineHookParams(CombineMessage message) {
    final summaryList = message.summaryList;
    final nameList = message.nameList;
    final jsonMsgKey = message.jsonMsgKey?.trim();
    if (summaryList == null ||
        summaryList.isEmpty ||
        nameList == null ||
        nameList.isEmpty ||
        jsonMsgKey == null ||
        jsonMsgKey.isEmpty) {
      return null;
    }
    return CombineMessageParams(
      sourceChannelType: message.sourceChannelType ?? channel.channelType,
      summaryList: List<String>.of(summaryList),
      nameList: List<String>.of(nameList),
      msgList: const <CombineMessageInfo>[],
      jsonMsgKey: jsonMsgKey,
      needReceipt: message.needReceipt,
    );
  }

  Future<void> _sendForwardRawCombineMessage(
    BaseChannel targetChannel,
    CombineMessage message,
    CombineMessageParams hookParams,
  ) async {
    final raw = message.raw;
    if (raw is! RCIMIWCombineV2Message) {
      throw NCError(code: -1, message: 'Invalid combine message payload');
    }

    final targetIdentifier = targetChannel.channelIdentifier;
    final forwardRaw = RCIMIWCombineV2Message.fromJson(raw.toJson())
      ..messageId = null
      ..messageUId = null
      ..targetId = targetIdentifier.channelId
      ..channelId = targetIdentifier.subChannelId
      ..conversationType = Converter.toRCConversationType(
        targetIdentifier.channelType,
      )
      ..senderUserId = engineProvider.currentUserId;

    if (!NCEngine.isInitialized) {
      await _sendForwardParams(targetChannel, hookParams);
      return;
    }

    final code = await NCEngine.engine.sendMediaMessage(
      forwardRaw,
      listener: RCIMIWSendMediaMessageListener(
        onMediaMessageSaved: (rawMessage) {
          final saved = _mediaMessageFromRaw(rawMessage);
          if (saved != null) {
            _markOutgoingStatusSending(saved);
            _notifyForwardTargetMessageUpsert(saved);
          }
        },
        onMediaMessageSending: (rawMessage, _) {
          final sending = _mediaMessageFromRaw(rawMessage);
          if (sending != null) {
            _markOutgoingStatusSending(sending);
            _notifyForwardTargetMessageUpsert(sending);
          }
        },
        onMediaMessageSent: (code, rawMessage) {
          final sent = _mediaMessageFromRaw(rawMessage);
          final error = _errorFromCode(code);
          if (sent != null) {
            _syncOutgoingStatusAfterResult(sent, error: error);
            _notifyForwardTargetMessageUpsert(sent);
          }
          _notifyAfterSendForChannel(targetChannel, hookParams, sent, error);
          _refreshCurrentMessagesAfterForwardRawSent(targetChannel, error);
        },
      ),
    );
    if (code != 0) {
      final error = NCError(code: code);
      _notifyAfterSendForChannel(targetChannel, hookParams, null, error);
      throw error;
    }
  }

  void _refreshCurrentMessagesAfterForwardRawSent(
    BaseChannel targetChannel,
    NCError? error,
  ) {
    if (error != null ||
        !_matchesChannelIdentifier(targetChannel.channelIdentifier)) {
      return;
    }
    unawaited(loadInitialMessages());
  }

  MediaMessage? _mediaMessageFromRaw(RCIMIWMediaMessage? raw) {
    if (raw == null) {
      return null;
    }
    final message = Message.fromRaw(raw);
    return message is MediaMessage ? message : null;
  }

  CombineMessageInfo? _forwardCombineInfo(
    CombineMessage message,
    CombineMessageInfo info,
  ) {
    final objectName = info.objectName?.trim();
    final content = _forwardCombineInfoContent(message, info);
    if (objectName == null || objectName.isEmpty || content == null) {
      return null;
    }
    return CombineMessageInfo(
      fromUserId: info.fromUserId,
      channelId: info.channelId,
      timestamp: info.timestamp,
      objectName: objectName,
      content: content,
    );
  }

  Map<String, dynamic>? _forwardCombineInfoContent(
    CombineMessage message,
    CombineMessageInfo info,
  ) {
    final objectName = info.objectName?.trim();
    final messageTypeIndex = _messageTypeIndexForObjectName(objectName);
    if (objectName == null || objectName.isEmpty || messageTypeIndex == null) {
      return null;
    }
    final rawContent = info.content;
    if (rawContent is! Map || rawContent.isEmpty) {
      return null;
    }
    final content = _normalizeJsonMap(rawContent.cast<dynamic, dynamic>());
    if (content == null || content.isEmpty) {
      return null;
    }
    final normalizedContent = _normalizeForwardCombineInfoContent(
      objectName,
      content,
    );
    if (normalizedContent == null || normalizedContent.isEmpty) {
      return null;
    }

    _putIfAbsent(
      normalizedContent,
      'conversationType',
      _conversationTypeIndex(message.sourceChannelType ?? channel.channelType),
    );
    _putIfAbsent(normalizedContent, 'messageType', messageTypeIndex);
    _putIfAbsent(
      normalizedContent,
      'targetId',
      info.channelId ?? message.channelId ?? channel.channelId,
    );
    _putIfAbsent(normalizedContent, 'channelId', null);
    _putIfAbsent(normalizedContent, 'senderUserId', info.fromUserId);
    _putIfAbsent(normalizedContent, 'sentTime', info.timestamp);
    return normalizedContent;
  }

  Map<String, dynamic>? _normalizeForwardCombineInfoContent(
    String objectName,
    Map<String, dynamic> content,
  ) {
    final normalized = Map<String, dynamic>.of(content);
    switch (objectName) {
      case 'RC:TxtMsg':
      case 'RC:ReferenceMsg':
        _putIfAbsent(normalized, 'text', _stringValue(normalized['content']));
        return normalized;
      case 'RC:ImgMsg':
        _putIfAbsent(normalized, 'local', _localAliasValue(normalized));
        _putIfAbsent(normalized, 'remote', _remoteAliasValue(normalized));
        _putIfAbsent(
          normalized,
          'thumbnailBase64String',
          _firstStringValue(normalized, const [
            'thumbnailBase64String',
            'thumbnailBase64',
            'content',
            'thumb',
            'thumbnail',
          ]),
        );
        _putIfAbsent(normalized, 'thumWidth', normalized['width']);
        _putIfAbsent(normalized, 'thumHeight', normalized['height']);
        return normalized;
      case 'RC:SightMsg':
        _putIfAbsent(normalized, 'local', _localAliasValue(normalized));
        _putIfAbsent(normalized, 'remote', _remoteAliasValue(normalized));
        _putIfAbsent(
          normalized,
          'thumbnailBase64String',
          _firstStringValue(normalized, const [
            'thumbnailBase64String',
            'content',
            'thumbnailBase64',
            'thumb',
            'thumbnail',
          ]),
        );
        return normalized;
      case 'RC:GIFMsg':
        _putIfAbsent(normalized, 'local', _localAliasValue(normalized));
        _putIfAbsent(normalized, 'remote', _remoteAliasValue(normalized));
        _putIfAbsent(normalized, 'dataSize', normalized['gifDataSize']);
        return normalized;
      case 'RC:FileMsg':
      case 'RC:HQVCMsg':
        _putIfAbsent(normalized, 'local', _localAliasValue(normalized));
        _putIfAbsent(normalized, 'remote', _remoteAliasValue(normalized));
        if (objectName == 'RC:FileMsg') {
          _putIfAbsent(normalized, 'fileType', normalized['type']);
        }
        return normalized;
      case 'RC:CombineV2Msg':
        return _normalizeForwardNestedCombineContent(normalized);
      default:
        return null;
    }
  }

  Map<String, dynamic> _normalizeForwardNestedCombineContent(
    Map<String, dynamic> content,
  ) {
    final msgList = content['msgList'];
    if (msgList is List) {
      final normalizedMsgList = <Map<String, dynamic>>[];
      for (final item in msgList) {
        if (item is! Map) {
          continue;
        }
        final info = _normalizeJsonMap(item.cast<dynamic, dynamic>());
        if (info == null || info.isEmpty) {
          continue;
        }
        final objectName = _stringValue(info['objectName'])?.trim();
        final rawContent = info['content'];
        if (objectName == null || objectName.isEmpty || rawContent is! Map) {
          continue;
        }
        final nestedContent = _normalizeJsonMap(
          rawContent.cast<dynamic, dynamic>(),
        );
        if (nestedContent == null || nestedContent.isEmpty) {
          continue;
        }
        final normalizedContent = _normalizeForwardCombineInfoContent(
          objectName,
          nestedContent,
        );
        if (normalizedContent == null || normalizedContent.isEmpty) {
          continue;
        }
        final messageTypeIndex = _messageTypeIndexForObjectName(objectName);
        _putIfAbsent(
          normalizedContent,
          'conversationType',
          content['combineConversationType'],
        );
        _putIfAbsent(normalizedContent, 'messageType', messageTypeIndex);
        _putIfAbsent(normalizedContent, 'targetId', info['targetId']);
        _putIfAbsent(normalizedContent, 'senderUserId', info['fromUserId']);
        _putIfAbsent(normalizedContent, 'sentTime', info['timestamp']);
        info['content'] = normalizedContent;
        normalizedMsgList.add(info);
      }
      content['msgList'] = normalizedMsgList;
      _putIfAbsent(content, 'msgNum', normalizedMsgList.length);
    }
    return content;
  }

  void _putIfAbsent(Map<String, dynamic> content, String key, dynamic value) {
    if (content.containsKey(key) || value == null) {
      return;
    }
    if (value is String && value.isEmpty) {
      return;
    }
    content[key] = value;
  }

  String? _remoteAliasValue(Map<String, dynamic> content) {
    return _firstStringValue(content, const [
      'remote',
      'remotePath',
      'sightUrl',
      'fileUrl',
      'imageUrl',
      'imageUri',
      'gifUrl',
      'voiceUrl',
      'url',
      'mediaUrl',
      'remoteUrl',
    ]);
  }

  String? _localAliasValue(Map<String, dynamic> content) {
    return _firstStringValue(content, const ['local', 'localPath']);
  }

  String? _firstStringValue(Map<String, dynamic> content, List<String> keys) {
    for (final key in keys) {
      final value = _stringValue(content[key]);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _stringValue(dynamic value) {
    return value is String ? value : null;
  }

  int _conversationTypeIndex(ChannelType type) {
    return switch (type) {
      ChannelType.direct => RCIMIWConversationType.private.index,
      ChannelType.group => RCIMIWConversationType.group.index,
      ChannelType.open => RCIMIWConversationType.chatroom.index,
      ChannelType.community => RCIMIWConversationType.ultraGroup.index,
      ChannelType.system => RCIMIWConversationType.system.index,
    };
  }

  int? _messageTypeIndexForObjectName(String? objectName) {
    return switch (objectName?.trim()) {
      'RC:TxtMsg' => RCIMIWMessageType.text.index,
      'RC:ImgMsg' => RCIMIWMessageType.image.index,
      'RC:GIFMsg' => RCIMIWMessageType.gif.index,
      'RC:SightMsg' => RCIMIWMessageType.sight.index,
      'RC:FileMsg' => RCIMIWMessageType.file.index,
      'RC:HQVCMsg' => RCIMIWMessageType.voice.index,
      'RC:ReferenceMsg' => RCIMIWMessageType.reference.index,
      'RC:CombineV2Msg' => RCIMIWMessageType.combineV2.index,
      _ => null,
    };
  }

  Future<String?> _mediaForwardPath(MediaMessage message) async {
    final localPath = _mediaLocalPathOf(message)?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = _fileFromPath(localPath);
      if (file != null && await file.exists()) {
        return file.path;
      }
      // Keep forwarding behavior permissive when callers only provide a local
      // path string; let the downstream SDK decide whether the media is usable.
      return localPath;
    }

    final remotePath = _mediaRemotePathOf(message)?.trim();
    if (remotePath == null || remotePath.isEmpty) {
      return null;
    }
    if (!_isNetworkPath(remotePath)) {
      final file = _fileFromPath(remotePath);
      if (file != null && await file.exists()) {
        return file.path;
      }
      return null;
    }

    return _downloadForwardMediaToTemp(remotePath, message.runtimeType);
  }

  File? _fileFromPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') {
      return File.fromUri(uri);
    }
    if (uri != null && uri.hasScheme && uri.scheme != 'file') {
      return null;
    }
    return File(path);
  }

  bool _isNetworkPath(String path) {
    return path.startsWith(RegExp(r'https?://', caseSensitive: false));
  }

  Future<String?> _downloadForwardMediaToTemp(
    String remotePath,
    Type messageType,
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final uri = Uri.tryParse(remotePath);
      final extension = _forwardMediaExtension(uri, messageType);
      final file = File(
        '${tempDir.path}/chatui_forward_${DateTime.now().microsecondsSinceEpoch}$extension',
      );
      await Dio().download(remotePath, file.path);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  String _forwardMediaExtension(Uri? uri, Type messageType) {
    final lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex > 0 && dotIndex < lastSegment.length - 1) {
      return lastSegment.substring(dotIndex);
    }
    if (messageType == GIFMessage) {
      return '.gif';
    }
    if (messageType == ImageMessage) {
      return '.jpg';
    }
    if (messageType == HDVoiceMessage) {
      return '.aac';
    }
    if (messageType == ShortVideoMessage) {
      return '.mp4';
    }
    return '.bin';
  }

  Future<void> _sendForwardParams(
    BaseChannel targetChannel,
    MessageParams params,
  ) async {
    final isMedia =
        params is ImageMessageParams ||
        params is GIFMessageParams ||
        params is HDVoiceMessageParams ||
        params is ShortVideoMessageParams ||
        params is FileMessageParams ||
        params is CombineMessageParams;
    final code = isMedia
        ? await targetChannel.sendMediaMessage(
            SendMediaMessageParams(messageParams: params),
            handler: SendMediaMessageHandler(
              onMediaMessageSaved: (message) {
                if (message != null) {
                  _markOutgoingStatusSending(message);
                  _notifyForwardTargetMessageUpsert(message);
                }
              },
              onMediaMessageSending: (message, _) {
                if (message != null) {
                  _markOutgoingStatusSending(message);
                  _notifyForwardTargetMessageUpsert(message);
                }
              },
              onMediaMessageSent: (code, message) {
                if (message != null) {
                  _syncOutgoingStatusAfterResult(
                    message,
                    error: _errorFromCode(code),
                  );
                  _notifyForwardTargetMessageUpsert(message);
                }
                _notifyAfterSendForChannel(
                  targetChannel,
                  params,
                  message,
                  _errorFromCode(code),
                );
              },
            ),
          )
        : await targetChannel.sendMessage(
            SendMessageParams(messageParams: params),
            callback: SendMessageCallback(
              onMessageSaved: (message) {
                if (message != null) {
                  _markOutgoingStatusSending(message);
                  _notifyForwardTargetMessageUpsert(message);
                }
              },
              onMessageSent: (code, message) {
                if (message != null) {
                  _syncOutgoingStatusAfterResult(
                    message,
                    error: _errorFromCode(code),
                  );
                  _notifyForwardTargetMessageUpsert(message);
                }
                _notifyAfterSendForChannel(
                  targetChannel,
                  params,
                  message,
                  _errorFromCode(code),
                );
              },
            ),
          );
    if (code != 0) {
      final error = NCError(code: code);
      _notifyAfterSendForChannel(targetChannel, params, null, error);
      throw error;
    }
  }
}
