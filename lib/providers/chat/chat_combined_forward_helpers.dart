part of '../chat_provider.dart';

extension _ChatProviderCombinedForwardHelpers on ChatProvider {
  List<_CombinedForwardItem> _combinedForwardItems(Message message) {
    final item = _combinedForwardItem(message);
    return item == null ? const <_CombinedForwardItem>[] : [item];
  }

  String? _combineObjectName(Message message) {
    if (message is TextMessage) return 'RC:TxtMsg';
    if (message is ImageMessage) return 'RC:ImgMsg';
    if (message is GIFMessage) return 'RC:GIFMsg';
    if (message is ShortVideoMessage) return 'RC:SightMsg';
    if (message is FileMessage) return 'RC:FileMsg';
    if (message is HDVoiceMessage) return 'RC:HQVCMsg';
    if (message is ReferenceMessage) return 'RC:ReferenceMsg';
    if (message is CombineMessage) return 'RC:CombineV2Msg';
    return null;
  }

  Map<String, dynamic>? _combineContent(Message message) {
    return _rawWrapperMessageJson(message);
  }

  Map<String, dynamic>? _rawWrapperMessageJson(Message message) {
    try {
      final raw = message.raw;
      final json = raw.toJson();
      return _normalizeJsonMap(json);
    } on NoSuchMethodError {
      return null;
    }
  }

  Map<String, dynamic>? _normalizeJsonMap(Map<dynamic, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      final value = _normalizeJsonValue(entry.value);
      if (value == null) {
        continue;
      }
      result[entry.key.toString()] = value;
    }
    return result.isEmpty ? null : result;
  }

  dynamic _normalizeJsonValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map) {
      return _normalizeJsonMap(value.cast<dynamic, dynamic>());
    }
    if (value is List) {
      return value
          .map(_normalizeJsonValue)
          .where((item) => item != null)
          .toList();
    }
    return value;
  }

  List<CombineMessageInfo> _sanitizeCombineMessageInfos(
    Iterable<CombineMessageInfo> infos,
  ) {
    final sanitized = <CombineMessageInfo>[];
    for (final info in infos) {
      final objectName = info.objectName?.trim();
      final content = info.content;
      if (objectName == null ||
          objectName.isEmpty ||
          content is! Map ||
          content.isEmpty) {
        continue;
      }
      sanitized.add(
        CombineMessageInfo(
          fromUserId: info.fromUserId,
          channelId: info.channelId,
          timestamp: info.timestamp,
          objectName: objectName,
          content: content.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
    return sanitized;
  }

  String _combinedForwardSummary(Message message) {
    if (message is TextMessage) {
      return message.text?.trim() ?? '';
    }
    if (message is ReferenceMessage) {
      final text = message.text?.trim();
      return text?.isNotEmpty == true ? text! : '[Reply]';
    }
    if (message is ImageMessage || message is GIFMessage) {
      return '[Image]';
    }
    if (message is ShortVideoMessage) {
      return '[Video]';
    }
    if (message is FileMessage) {
      return '[File]';
    }
    if (message is HDVoiceMessage) {
      final duration = message.duration;
      return duration == null ? '[Voice]' : "[Voice] $duration''";
    }
    if (message is CombineMessage) {
      return '[Combined Forward]';
    }
    return '';
  }

  String _senderDisplayName(Message message) {
    return message.userInfo?.alias ??
        message.userInfo?.name ??
        message.senderUserId ??
        '';
  }
}
