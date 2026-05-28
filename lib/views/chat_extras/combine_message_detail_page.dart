import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rongcloud_im_wrapper_plugin/rongcloud_im_wrapper_plugin.dart'
    show RCIMIWConversationType;

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../models/chat_profile_info.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/engine_provider.dart';
import '../../routes/nexconn_chat_ui_routes.dart';
import '../../ui_config/chat/page/chat_page_config.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/chatui_image_util.dart';
import '../../utils/constants.dart';
import '../../utils/message_content_util.dart';
import '../../utils/voice_message_layout.dart';
import 'file_preview_page.dart';
import 'photo_preview_page.dart';
import 'short_video_preview_page.dart';

/// Displays the entries inside a combined-forward message.
class CombineMessageDetailPage extends StatefulWidget {
  static const Key failureStateKey = ValueKey('combine-message-failure-state');
  static const Key loadingStateKey = ValueKey('combine-message-loading-state');
  static const Key copyMenuKey = ValueKey('combine-message-copy-menu');
  static const Key mediaPreviewKey = ValueKey('combine-message-media-preview');
  static const Key filePreviewKey = ValueKey('combine-message-file-preview');
  static const Key voicePreviewKey = ValueKey('combine-message-voice-preview');
  static const Key nestedPreviewKey = ValueKey(
    'combine-message-nested-preview',
  );

  final CombineMessage message;
  final ChatPageConfig config;

  const CombineMessageDetailPage({
    super.key,
    required this.message,
    required this.config,
  });

  @override
  State<CombineMessageDetailPage> createState() =>
      _CombineMessageDetailPageState();
}

class _CombineMessageDetailPageState extends State<CombineMessageDetailPage> {
  late CombineMessage _message = widget.message;
  List<CombineMessageInfo>? _localMessageInfos;
  String? _loadedLocalPath;
  String? _layerVoiceMessageKey;
  NexconnAudioPlayerProvider? _audioPlayerProvider;
  bool _isDownloading = false;
  bool _downloadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadLocalCombinePayloadIfAvailable(_message);
    _downloadMessageIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _audioPlayerProvider = context.read<NexconnAudioPlayerProvider>();
    } on ProviderNotFoundException {
      _audioPlayerProvider = null;
    }
  }

  @override
  void didUpdateWidget(covariant CombineMessageDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.message, widget.message)) {
      _message = widget.message;
      _localMessageInfos = null;
      _loadedLocalPath = null;
      _layerVoiceMessageKey = null;
      _downloadFailed = false;
      _loadLocalCombinePayloadIfAvailable(_message);
      _downloadMessageIfNeeded();
    }
  }

  @override
  void dispose() {
    _stopLayerVoicePlayback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.chatUIL10n;
    final sourceChannelType = combineMessageSourceChannelType(
      _message,
      fallbackChannelType: _fallbackSourceChannelType(context),
    );
    final fallbackTitle = combineMessageTitle(
      _message.nameList,
      localizations: l10n,
      sourceChannelType: sourceChannelType,
    );
    final entries = _isDownloading || _downloadFailed
        ? const <_CombineEntry>[]
        : _parseEntries(_message);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F6FA),
        foregroundColor: const Color(0xFF050B16),
        leading: IconButton(
          icon: ChatUIAsset.image(
            'NexconnLightIcon/Left-arrow.png',
            width: 22,
            height: 22,
            color: const Color(0xFF050B16),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          fallbackTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF050B16),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isDownloading
          ? const Center(
              key: CombineMessageDetailPage.loadingStateKey,
              child: CircularProgressIndicator(),
            )
          : entries.isEmpty
          ? _FailureState(text: l10n.combineMessageLoadFailed)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(32, 18, 32, 32),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(left: 48, top: 16, bottom: 16),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: Color(0xFFE6E6E6),
                ),
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final previousEntry = index == 0 ? null : entries[index - 1];
                final showAvatar =
                    previousEntry == null ||
                    !_hasSameDisplaySender(previousEntry, entry);
                return _CombineEntryRow(
                  entry: entry,
                  showAvatar: showAvatar,
                  titleNames: _message.nameList ?? const <String>[],
                  sourceChannelType: sourceChannelType ?? ChannelType.direct,
                  profileProvider: widget.config.profileProvider,
                  config: widget.config,
                  onVoicePlaybackStarted: _trackLayerVoicePlayback,
                );
              },
            ),
    );
  }

  void _trackLayerVoicePlayback(String messageKey) {
    _layerVoiceMessageKey = messageKey;
  }

  void _stopLayerVoicePlayback() {
    final layerVoiceMessageKey = _layerVoiceMessageKey;
    if (layerVoiceMessageKey == null) {
      return;
    }
    final player = _audioPlayerProvider;
    final currentKey = player?.currentPlayingMessageId;
    if (currentKey == null || currentKey != layerVoiceMessageKey) {
      return;
    }
    unawaited(player!.stopVoiceMessage(notify: false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        player.stopVoiceMessage(notify: true, invalidatePendingRequest: false),
      );
    });
  }

  Future<void> _downloadMessageIfNeeded() async {
    if (!_needsDownload(_message)) {
      return;
    }
    ChatProvider? provider;
    try {
      provider = context.read<ChatProvider>();
    } on ProviderNotFoundException {
      provider = null;
    }
    if (provider == null) {
      setState(() {
        _downloadFailed = true;
      });
      return;
    }
    setState(() {
      _isDownloading = true;
      _downloadFailed = false;
    });
    var downloadedMessage = _message;
    try {
      await provider.downloadMediaMessage(
        _message,
        onDownloaded: (downloaded) {
          if (downloaded is CombineMessage) {
            downloadedMessage = downloaded;
          }
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _message = downloadedMessage;
        _isDownloading = false;
      });
      _loadLocalCombinePayloadIfAvailable(downloadedMessage);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isDownloading = false;
        _downloadFailed = true;
      });
    }
  }

  bool _needsDownload(CombineMessage message) {
    final jsonMsgKey = message.jsonMsgKey?.trim();
    if (jsonMsgKey == null || jsonMsgKey.isEmpty) {
      return false;
    }
    final localPath = message.localPath?.trim();
    return localPath == null || localPath.isEmpty;
  }

  void _loadLocalCombinePayloadIfAvailable(CombineMessage message) {
    final localPath = message.localPath?.trim();
    if (localPath == null || localPath.isEmpty) {
      return;
    }
    if (_loadedLocalPath == localPath) {
      return;
    }
    _loadedLocalPath = localPath;
    unawaited(_loadLocalCombinePayload(localPath));
  }

  Future<void> _loadLocalCombinePayload(String localPath) async {
    try {
      final file = _fileFromLocalPath(localPath);
      if (!await file.exists()) {
        return;
      }
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final infos = _parseLocalCombineInfos(content);
      if (infos.isNotEmpty && mounted) {
        setState(() {
          _localMessageInfos = infos;
        });
      }
    } catch (_) {}
  }

  List<CombineMessageInfo> _parseLocalCombineInfos(String content) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return const <CombineMessageInfo>[];
    }
    if (decoded is! List) {
      return const <CombineMessageInfo>[];
    }
    final infos = <CombineMessageInfo>[];
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      final objectName = _nonEmpty(map['objectName']);
      final content = map['content'];
      if (objectName == null || content is! Map) {
        continue;
      }
      infos.add(
        CombineMessageInfo(
          fromUserId: _nonEmpty(map['fromUserId']),
          channelId: _nonEmpty(map['targetId']) ?? _nonEmpty(map['channelId']),
          timestamp: _intValue(map['timestamp']),
          objectName: objectName,
          content: content.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
    return infos;
  }

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  File _fileFromLocalPath(String localPath) {
    final uri = Uri.tryParse(localPath);
    if (uri != null && uri.scheme == 'file') {
      return File.fromUri(uri);
    }
    return File(localPath);
  }

  ChannelType? _fallbackSourceChannelType(BuildContext context) {
    try {
      return context.read<ChatProvider>().channel.channelType;
    } on ProviderNotFoundException {
      return null;
    }
  }

  List<_CombineEntry> _parseEntries(CombineMessage message) {
    final messageInfos = message.msgList;
    final infos = (messageInfos == null || messageInfos.isEmpty)
        ? _localMessageInfos
        : messageInfos;
    if (infos == null || infos.isEmpty) {
      return _summaryFallbackEntries(message);
    }
    final entries = <_CombineEntry>[];
    for (var index = 0; index < infos.length; index++) {
      final info = infos[index];
      final content = info.content;
      if (content is! Map || content.isEmpty) {
        continue;
      }
      final entry = _CombineEntry.fromInfo(
        info,
        content.map((key, value) => MapEntry(key.toString(), value)),
        fallbackName: _fallbackName(index),
      );
      if (entry != null) {
        entries.add(entry);
      }
    }
    return entries;
  }

  List<_CombineEntry> _summaryFallbackEntries(CombineMessage message) {
    final summaries = message.summaryList ?? const <String>[];
    if (summaries.isEmpty) {
      return const <_CombineEntry>[];
    }
    final names = message.nameList ?? const <String>[];
    final entries = <_CombineEntry>[];
    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index].trim();
      if (summary.isEmpty) {
        continue;
      }
      entries.add(
        _CombineEntry(
          fromUserId: null,
          channelId: message.channelId,
          timestamp: null,
          objectName: 'RC:TxtMsg',
          content: <String, dynamic>{'text': summary, 'content': summary},
          fallbackName: index < names.length ? names[index] : _fallbackName(0),
        ),
      );
    }
    return entries;
  }

  bool _hasSameDisplaySender(_CombineEntry a, _CombineEntry b) {
    final aKey = _senderGroupingKey(a);
    final bKey = _senderGroupingKey(b);
    if (aKey == null || bKey == null) {
      return false;
    }
    return aKey == bKey;
  }

  String? _senderGroupingKey(_CombineEntry entry) {
    final userInfo = entry.content['userInfo'];
    final userInfoMap = userInfo is Map
        ? userInfo.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    return _nonEmpty(entry.fromUserId) ??
        _nonEmpty(userInfoMap['userId']) ??
        _nonEmpty(entry.fallbackName);
  }

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _fallbackName(int index) {
    final names = _message.nameList;
    if (names == null || names.isEmpty) {
      return null;
    }
    if (index < names.length) {
      return names[index];
    }
    return names.first;
  }
}

final Map<String, Future<ChatProfileInfo?>> _combineProfileFutureCache =
    <String, Future<ChatProfileInfo?>>{};
final Map<String, ChatProfileInfo?> _combineProfileValueCache =
    <String, ChatProfileInfo?>{};

class _CombineEntry {
  final String? fromUserId;
  final String? channelId;
  final int? timestamp;
  final String objectName;
  final Map<String, dynamic> content;
  final String? fallbackName;

  const _CombineEntry({
    required this.fromUserId,
    required this.channelId,
    required this.timestamp,
    required this.objectName,
    required this.content,
    this.fallbackName,
  });

  static _CombineEntry? fromInfo(
    CombineMessageInfo info,
    Map<String, dynamic> content, {
    String? fallbackName,
  }) {
    final objectName = info.objectName?.trim();
    if (objectName == null || objectName.isEmpty) {
      return null;
    }
    return _CombineEntry(
      fromUserId: info.fromUserId,
      channelId: info.channelId,
      timestamp: info.timestamp,
      objectName: objectName,
      content: content,
      fallbackName: fallbackName,
    );
  }
}

String? _existingLocalPathFromValue(String? path) {
  if (path == null || path.isEmpty || _isHttpUrl(path)) {
    return null;
  }
  final uri = Uri.tryParse(path);
  final file = uri != null && uri.scheme == 'file'
      ? File.fromUri(uri)
      : File(path);
  return file.existsSync() ? path : null;
}

String? _firstNetworkPath(Iterable<String?> paths) {
  for (final path in paths) {
    if (path != null && path.isNotEmpty && _isHttpUrl(path)) {
      return path;
    }
  }
  return null;
}

bool _isHttpUrl(String path) {
  return path.startsWith(RegExp(r'https?://', caseSensitive: false));
}

class _CombineEntryRow extends StatelessWidget {
  final _CombineEntry entry;
  final bool showAvatar;
  final List<String> titleNames;
  final ChannelType sourceChannelType;
  final ChatProfileProvider? profileProvider;
  final ChatPageConfig config;
  final ValueChanged<String>? onVoicePlaybackStarted;

  const _CombineEntryRow({
    required this.entry,
    required this.showAvatar,
    required this.titleNames,
    required this.sourceChannelType,
    required this.profileProvider,
    required this.config,
    this.onVoicePlaybackStarted,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackProfile = _fallbackProfile();
    final provider = profileProvider;
    if (provider == null) {
      return _buildWithProfile(context, fallbackProfile);
    }
    final profileChannel = BaseChannel(
      sourceChannelType,
      entry.channelId ?? '',
    );
    final infoMessage = _CombineInfoMessage(entry);
    final profileCacheKey = _profileCacheKey(profileChannel, infoMessage);
    final cachedInitialProfile =
        _combineProfileValueCache[profileCacheKey] ?? fallbackProfile;
    final cachedFuture = _combineProfileFutureCache.putIfAbsent(
      profileCacheKey,
      () =>
          Future<ChatProfileInfo?>.sync(
            () => provider(profileChannel, message: infoMessage),
          ).then((profile) {
            _combineProfileValueCache[profileCacheKey] = profile;
            return profile;
          }),
    );
    return FutureBuilder<ChatProfileInfo?>(
      future: cachedFuture,
      initialData: cachedInitialProfile,
      builder: (context, snapshot) =>
          _buildWithProfile(context, snapshot.data ?? fallbackProfile),
    );
  }

  Widget _buildWithProfile(BuildContext context, ChatProfileInfo profile) {
    final isOutgoing = _isOutgoingEntry(context);
    final content = Expanded(
      child: Column(
        crossAxisAlignment: isOutgoing
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isOutgoing
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isOutgoing)
                Expanded(
                  child: Text(
                    profile.name ?? profile.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8C95A3),
                      fontSize: 14,
                    ),
                  ),
                ),
              Text(
                _formatTime(context, entry.timestamp),
                style: const TextStyle(color: Color(0xFF8C95A3), fontSize: 14),
              ),
              if (isOutgoing) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    profile.name ?? profile.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFF8C95A3),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: isOutgoing
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.62,
              ),
              child: _content(context, isOutgoing: isOutgoing),
            ),
          ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showCopyMenu(context, details.globalPosition),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOutgoing) content,
          if (isOutgoing) const SizedBox(width: 16),
          SizedBox(
            width: 32,
            height: 32,
            child: showAvatar ? _avatar(profile) : const SizedBox.shrink(),
          ),
          if (!isOutgoing) const SizedBox(width: 16),
          if (!isOutgoing) content,
        ],
      ),
    );
  }

  bool _isOutgoingEntry(BuildContext context) {
    try {
      final provider = Provider.of<ChatProvider?>(context, listen: false);
      final currentUserId = provider?.engineProvider.currentUserId.trim() ?? '';
      final senderUserId = entry.fromUserId?.trim() ?? '';
      return currentUserId.isNotEmpty && senderUserId == currentUserId;
    } on ProviderNotFoundException {
      return false;
    }
  }

  Widget _avatar(ChatProfileInfo profile) {
    final url = profile.portraitUri;
    final fallback = ClipOval(
      child: ChatUIAsset.image(
        'avatar_default_single.png',
        width: 32,
        height: 32,
        fit: BoxFit.cover,
      ),
    );
    if (url == null || !url.startsWith(RegExp(r'https?://'))) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _content(BuildContext context, {required bool isOutgoing}) {
    return switch (entry.objectName) {
      'RC:TxtMsg' || 'RC:ReferenceMsg' => _textContent(isOutgoing: isOutgoing),
      'RC:ImgMsg' || 'RC:GIFMsg' => _imageContent(context),
      'RC:SightMsg' => _videoContent(context),
      'RC:FileMsg' => _fileContent(context),
      'RC:VcMsg' || 'RC:HQVCMsg' => _voiceContent(isOutgoing: isOutgoing),
      'RC:CombineV2Msg' => _combineContent(context),
      _ => Text(
        context.chatUIL10n.searchUnsupportedMessagePreview,
        style: const TextStyle(color: Color(0xFF8C95A3), fontSize: 14),
      ),
    };
  }

  Widget _textContent({required bool isOutgoing}) {
    final text = _stringValue('content') ?? _stringValue('text') ?? '';
    return Text(
      text,
      textAlign: isOutgoing ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
        color: Color(0xFF050B16),
        fontSize: 16,
        height: 24 / 16,
      ),
    );
  }

  Widget _combineContent(BuildContext context) {
    final nested = _combineMessage();
    final l10n = context.chatUIL10n;
    final summaries = (nested.summaryList ?? const <String>[])
        .where((summary) => summary.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    return GestureDetector(
      key: CombineMessageDetailPage.nestedPreviewKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNestedCombine(context, nested),
      child: ConstrainedBox(
        constraints: const BoxConstraints.tightFor(width: 222),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE1E4E8), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      combineMessageTitle(
                        nested.nameList,
                        localizations: l10n,
                        sourceChannelType: combineMessageSourceChannelType(
                          nested,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final summary in summaries)
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8C95A3),
                          fontSize: 13,
                          height: 17 / 13,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(
                height: 0.5,
                thickness: 0.5,
                color: Color(0xFFE6E6E6),
              ),
              SizedBox(
                height: 30,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      l10n.combineMessageChatHistoryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8C95A3),
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileContent(BuildContext context) {
    final name =
        _stringValue('name') ??
        _fileNameFromPath(_stringValue('fileUrl')) ??
        context.chatUIL10n.fileUntitled;
    final size = _intValue('size');
    return GestureDetector(
      key: CombineMessageDetailPage.filePreviewKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => pushNexconnChatUINamedRouteOr<void>(
        context,
        NexconnChatUIRoutes.filePreview,
        arguments: NexconnFilePreviewRouteArguments(
          fileMessage: _fileMessage(),
        ),
        fallbackRoute: () => MaterialPageRoute<void>(
          builder: (_) => FilePreviewPage(fileMessage: _fileMessage()),
        ),
      ),
      child: SizedBox(
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE1E4E8), width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                ChatUIAsset.image(
                  'NexconnLightIcon/File.png',
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF050B16),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _fileSizeText(context, size),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8C95A3),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _voiceContent({required bool isOutgoing}) {
    final duration = _intValue('duration') ?? 0;
    final voice = _voiceMessage();
    final hasLocalFile = _hasPlayableVoiceFile(voice.localPath);
    return Builder(
      builder: (context) {
        const durationTextStyle = TextStyle(
          color: Color(0xFF050B16),
          fontSize: kBubbleVoiceDurationFontSize,
        );
        final durationWidth = voiceMessageDurationWidth(
          context,
          duration,
          durationTextStyle,
        );
        const fixedBubbleWidth =
            14 + 20 + 10 + kBubbleVoiceDurationPadding + 14;
        final bubbleWidth = math.min(
          fixedBubbleWidth + durationWidth,
          MediaQuery.sizeOf(context).width * 0.62,
        );
        final clampedDurationWidth = math.max(
          0.0,
          bubbleWidth - fixedBubbleWidth,
        );
        final player = _maybeAudioPlayerProvider(context, listen: true);
        final isDownloading =
            player != null && player.isVoiceMessageDownloading(voice);
        final isPlaying =
            player?.currentPlayingMessageId == _messageKey(voice) &&
            player?.state == NexconnAudioPlayerState.playing;
        return GestureDetector(
          key: CombineMessageDetailPage.voicePreviewKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleVoiceTap(context, voice),
          child: SizedBox(
            width: bubbleWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDownloading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value:
                              (player.voiceMessageDownloadProgress(voice) ?? 0)
                                  .clamp(0, 100) /
                              100,
                          strokeWidth: 2,
                        ),
                      )
                    else if (hasLocalFile ||
                        _hasPlayableRemoteVoice(voice.remotePath))
                      ChatUIAsset.image(
                        isPlaying
                            ? 'voice_playing_receive.gif'
                            : 'voice_message_icon_receive.png',
                        height: 20,
                      )
                    else
                      const Icon(
                        Icons.play_disabled_rounded,
                        size: 20,
                        color: Color(0xFF8C95A3),
                      ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: clampedDurationWidth + kBubbleVoiceDurationPadding,
                      child: Text(
                        voiceMessageDurationText(duration),
                        maxLines: 1,
                        textAlign: isOutgoing
                            ? TextAlign.right
                            : TextAlign.left,
                        style: durationTextStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _imageContent(BuildContext context) {
    final media = _imageMessage();
    final provider = _maybeChatProvider(context);
    final path = media?.localPath ?? media?.remotePath;
    final thumbnail =
        _decodeBase64(_stringValue('thumbnailBase64String')) ??
        _decodeBase64(_stringValue('thumbnailBase64')) ??
        _decodeBase64(_stringValue('thumb')) ??
        _decodeBase64(_stringValue('thumbnail')) ??
        _decodeBase64(_stringValue('content'));
    Widget child;
    if (thumbnail != null) {
      child = Image.memory(thumbnail, fit: BoxFit.cover);
    } else if (path != null && path.isNotEmpty) {
      child = _pathImage(path);
    } else {
      child = _mediaPlaceholder();
    }
    return GestureDetector(
      key: CombineMessageDetailPage.mediaPreviewKey,
      behavior: HitTestBehavior.opaque,
      onTap: media == null
          ? null
          : () => pushNexconnChatUINamedRouteOr<void>(
              context,
              NexconnChatUIRoutes.photoPreview,
              arguments: NexconnPhotoPreviewRouteArguments(
                images: [media],
                provider: provider,
              ),
              fallbackRoute: () => MaterialPageRoute<void>(
                builder: (_) =>
                    PhotoPreviewPage(images: [media], provider: provider),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(width: 160, height: 120, child: child),
      ),
    );
  }

  Widget _videoContent(BuildContext context) {
    final provider = _maybeChatProvider(context);
    final thumbnail =
        _decodeBase64(_stringValue('thumbnailBase64String')) ??
        _decodeBase64(_stringValue('thumbnailBase64')) ??
        _decodeBase64(_stringValue('thumb')) ??
        _decodeBase64(_stringValue('thumbnail')) ??
        _decodeBase64(_stringValue('content'));
    final child = thumbnail == null
        ? _mediaPlaceholder()
        : Image.memory(thumbnail, fit: BoxFit.cover);
    final video = _videoMessage();
    return GestureDetector(
      key: CombineMessageDetailPage.mediaPreviewKey,
      behavior: HitTestBehavior.opaque,
      onTap: video == null
          ? null
          : () => pushNexconnChatUINamedRouteOr<void>(
              context,
              NexconnChatUIRoutes.shortVideoPreview,
              arguments: NexconnShortVideoPreviewRouteArguments(
                videos: [video],
                provider: provider,
              ),
              fallbackRoute: () => MaterialPageRoute<void>(
                builder: (_) =>
                    ShortVideoPreviewPage(videos: [video], provider: provider),
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 160,
          height: 120,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
              Center(
                child: ChatUIAsset.image(
                  'sight_message_play.png',
                  width: 36,
                  height: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pathImage(String path) {
    Widget errorBuilder(_, __, ___) => _mediaPlaceholder();
    if (path.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: errorBuilder);
    }
    final uri = Uri.tryParse(path);
    return Image.file(
      uri != null && uri.scheme == 'file' ? File.fromUri(uri) : File(path),
      fit: BoxFit.cover,
      errorBuilder: errorBuilder,
    );
  }

  Widget _mediaPlaceholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFE3E7EE)),
      child: Center(
        child: ChatUIAsset.image(
          'NexconnLightIcon/Thumbnail-failed.png',
          width: 32,
          height: 32,
          color: const Color(0xFF8C95A3),
        ),
      ),
    );
  }

  Future<void> _showCopyMenu(BuildContext context, Offset position) async {
    final menu = config.longPressMenuConfig;
    final copyText = _copyText();
    if (!menu.enabled ||
        !menu.showCopyButton ||
        copyText == null ||
        copyText.isEmpty) {
      return;
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      menuPadding: EdgeInsets.zero,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 160),
      color: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x33000000),
      items: [
        const PopupMenuItem<String>(
          enabled: false,
          height: 4,
          padding: EdgeInsets.zero,
          child: SizedBox.shrink(),
        ),
        PopupMenuItem<String>(
          key: CombineMessageDetailPage.copyMenuKey,
          value: 'copy',
          height: 34,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            margin: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ChatUIAsset.image(
                  'NexconnLightIcon/Copy.png',
                  width: kMessageMenuIconSize,
                  height: kMessageMenuIconSize,
                  color: kMessageMenuTextColor,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    menu.copyText ?? context.chatUIL10n.chatLongPressCopy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: kMessageMenuTextColor,
                      fontSize: kMessageMenuFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuItem<String>(
          enabled: false,
          height: 4,
          padding: EdgeInsets.zero,
          child: SizedBox.shrink(),
        ),
      ],
    );
    if (!context.mounted || action != 'copy') {
      return;
    }
    final infoMessage = _CombineInfoMessage(entry);
    if (menu.onCopy != null) {
      await menu.onCopy!(
        context,
        BaseChannel(sourceChannelType, entry.channelId ?? ''),
        infoMessage,
        copyText,
      );
    } else {
      await Clipboard.setData(ClipboardData(text: copyText));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.chatUIL10n.chatMessageCopied)),
      );
    }
  }

  String? _copyText() {
    return switch (entry.objectName) {
      'RC:TxtMsg' ||
      'RC:ReferenceMsg' => _stringValue('content') ?? _stringValue('text'),
      _ => null,
    };
  }

  MediaMessage? _imageMessage() {
    final localPath = _existingLocalPathFromValue(
      _stringValue('local') ?? _stringValue('localPath'),
    );
    final remotePath = _firstNetworkPath([
      _stringValue('remote'),
      _stringValue('remoteUrl'),
      _stringValue('imageUri'),
      _stringValue('remotePath'),
      _stringValue('fileUrl'),
    ]);
    final hasThumbnail =
        _stringValue('thumbnailBase64String')?.isNotEmpty == true ||
        _stringValue('thumbnailBase64')?.isNotEmpty == true ||
        _stringValue('thumb')?.isNotEmpty == true ||
        _stringValue('thumbnail')?.isNotEmpty == true ||
        _stringValue('content')?.isNotEmpty == true;
    if ((localPath == null || localPath.isEmpty) &&
        (remotePath == null || remotePath.isEmpty) &&
        !hasThumbnail) {
      return null;
    }
    if (entry.objectName == 'RC:GIFMsg') {
      return _CombineGifMessage(entry);
    }
    return _CombineImageMessage(entry);
  }

  ShortVideoMessage? _videoMessage() {
    final localPath = _existingLocalPathFromValue(
      _stringValue('local') ?? _stringValue('localPath'),
    );
    final remotePath = _firstNetworkPath([
      _stringValue('remote'),
      _stringValue('sightUrl'),
      _stringValue('remoteUrl'),
      _stringValue('remotePath'),
      _stringValue('fileUrl'),
    ]);
    if ((localPath == null || localPath.isEmpty) &&
        (remotePath == null || remotePath.isEmpty)) {
      return null;
    }
    return _CombineShortVideoMessage(entry);
  }

  FileMessage _fileMessage() => _CombineFileMessage(entry);

  HDVoiceMessage _voiceMessage() => _CombineVoiceMessage(entry);

  CombineMessage _combineMessage() =>
      _CombineNestedMessage(entry, sourceChannelTypeValue: sourceChannelType);

  void _openNestedCombine(BuildContext context, CombineMessage nested) {
    final provider = _maybeChatProvider(context);
    if (provider == null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              CombineMessageDetailPage(message: nested, config: config),
        ),
      );
      return;
    }
    pushNexconnChatUINamedRouteOr<void>(
      context,
      NexconnChatUIRoutes.combineMessageDetail,
      arguments: NexconnCombineMessageDetailRouteArguments(
        message: nested,
        config: config,
        provider: provider,
        audioPlayerProvider: _maybeAudioPlayerProvider(context),
      ),
      fallbackRoute: () => MaterialPageRoute<void>(
        builder: (_) =>
            CombineMessageDetailPage(message: nested, config: config),
      ),
    );
  }

  NexconnAudioPlayerProvider? _maybeAudioPlayerProvider(
    BuildContext context, {
    bool listen = false,
  }) {
    try {
      return Provider.of<NexconnAudioPlayerProvider>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _handleVoiceTap(BuildContext context, HDVoiceMessage voice) {
    final player = _maybeAudioPlayerProvider(context);
    if (player == null) {
      return;
    }
    onVoicePlaybackStarted?.call(_messageKey(voice));
    player.playVoiceMessage(voice, context).ignore();
  }

  String _messageKey(Message message) {
    return message.messageId ??
        message.clientId?.toString() ??
        '${message.channelId}:${message.sentTime}:${message.senderUserId}';
  }

  ChatProfileInfo _fallbackProfile() {
    final userInfo = entry.content['userInfo'];
    final userInfoMap = userInfo is Map
        ? userInfo.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final id = entry.fromUserId ?? userInfoMap['userId']?.toString() ?? '';
    final name =
        _nonEmpty(userInfoMap['alias']) ??
        _nonEmpty(userInfoMap['name']) ??
        _nonEmpty(entry.fallbackName) ??
        id;
    return ChatProfileInfo(
      id: id,
      name: name,
      portraitUri: _nonEmpty(userInfoMap['avatarUrl']),
    );
  }

  String _profileCacheKey(BaseChannel channel, Message message) {
    final senderId = message.senderUserId?.trim();
    final userInfoId = _messageUserInfo(message)?.userId?.trim();
    final resolvedUserId = senderId?.isNotEmpty == true
        ? senderId!
        : userInfoId?.isNotEmpty == true
        ? userInfoId!
        : 'unknown';
    final subChannelId = channel.channelIdentifier.subChannelId;
    return [
      channel.channelType.name,
      channel.channelId,
      if (subChannelId != null && subChannelId.isNotEmpty) subChannelId,
      resolvedUserId,
    ].join('#');
  }

  UserInfo? _messageUserInfo(Message message) {
    try {
      return message.userInfo;
    } catch (_) {
      return null;
    }
  }

  String _formatTime(BuildContext context, int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '';
    }
    final l10n = context.chatUIL10n;
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = _serverNow(context) ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    final time = _formatClockTime(date);
    if (diff == 0) {
      return time;
    }
    if (diff == 1) {
      return l10n.combineMessageTimeYesterday(time);
    }
    if (diff > 1 && diff < 7) {
      return l10n.combineMessageTimeWeekday(
        _localizedWeekday(l10n, date.weekday),
        time,
      );
    }
    final dateText = date.year == now.year
        ? '${date.month}/${date.day}'
        : '${date.year}/${date.month}/${date.day}';
    return l10n.combineMessageTimeDate(dateText, time);
  }

  String _formatClockTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _localizedWeekday(NexconnChatUILocalizations l10n, int weekday) {
    return switch (weekday) {
      DateTime.monday => l10n.commonWeekdayMonday,
      DateTime.tuesday => l10n.commonWeekdayTuesday,
      DateTime.wednesday => l10n.commonWeekdayWednesday,
      DateTime.thursday => l10n.commonWeekdayThursday,
      DateTime.friday => l10n.commonWeekdayFriday,
      DateTime.saturday => l10n.commonWeekdaySaturday,
      DateTime.sunday => l10n.commonWeekdaySunday,
      _ => '',
    };
  }

  String _fileSizeText(BuildContext context, int? size) {
    if (size == null || size < 0) {
      return context.chatUIL10n.fileSizeBytes(0);
    }
    if (size < 1024) {
      return context.chatUIL10n.fileSizeBytes(size);
    }
    final kb = size / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }

  String? _stringValue(String key) => _nonEmpty(entry.content[key]);

  int? _intValue(String key) {
    final value = entry.content[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _fileNameFromPath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(path);
    final segments = uri?.pathSegments;
    if (segments != null && segments.isNotEmpty) {
      return segments.last;
    }
    return path.split('/').last;
  }

  Uint8List? _decodeBase64(String? value) {
    return ChatUIImageUtil.getDecodedBase64(value);
  }

  ChatProvider? _maybeChatProvider(BuildContext context) {
    try {
      return Provider.of<ChatProvider>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  DateTime? _serverNow(BuildContext context) {
    try {
      return Provider.of<EngineProvider>(context, listen: true).serverNow;
    } on ProviderNotFoundException {
      return null;
    }
  }
}

bool _hasPlayableVoiceFile(String? rawPath) {
  if (rawPath == null || rawPath.isEmpty) {
    return false;
  }
  final path = rawPath.startsWith('file://') ? rawPath.substring(7) : rawPath;
  return File(path).existsSync();
}

bool _hasPlayableRemoteVoice(String? rawPath) {
  if (rawPath == null || rawPath.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(rawPath);
  if (uri == null || !uri.hasScheme) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https' || scheme == 'file';
}

class _FailureState extends StatelessWidget {
  final String text;

  const _FailureState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -45),
        child: Column(
          key: CombineMessageDetailPage.failureStateKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatUIAsset.image(
              'NexconnLightIcon/File.png',
              width: 56,
              height: 56,
              color: const Color(0xFF050B16),
            ),
            const SizedBox(height: 24),
            Text(
              text,
              style: const TextStyle(color: Color(0xFF050B16), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombineInfoMessage implements Message {
  final _CombineEntry entry;

  const _CombineInfoMessage(this.entry);

  @override
  String? get senderUserId => entry.fromUserId;

  @override
  String? get channelId => entry.channelId;

  @override
  int? get sentTime => entry.timestamp;

  @override
  MessageType? get messageType => MessageType.combineV2;

  @override
  Map<String, dynamic> toJson({bool filterEmpty = true}) => {
    'senderUserId': senderUserId,
    'channelId': channelId,
    'sentTime': sentTime,
    'messageType': messageType?.name,
    'content': entry.content,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CombineNestedMessage implements CombineMessage {
  final _CombineEntry entry;
  final ChannelType sourceChannelTypeValue;

  const _CombineNestedMessage(
    this.entry, {
    required this.sourceChannelTypeValue,
  });

  @override
  String? get senderUserId => entry.fromUserId;

  @override
  String? get channelId => entry.channelId;

  @override
  ChannelType? get channelType => sourceChannelTypeValue;

  @override
  ChannelIdentifier? get channelIdentifier => ChannelIdentifier(
    channelType: sourceChannelTypeValue,
    channelId: entry.channelId ?? '',
  );

  @override
  int? get sentTime => entry.timestamp;

  @override
  String? get messageId =>
      'combine:nested:${entry.channelId}:${entry.timestamp}:${entry.fromUserId}';

  @override
  int? get clientId => messageId.hashCode;

  @override
  MessageDirection? get direction => MessageDirection.receive;

  @override
  SentStatus? get sentStatus => SentStatus.sent;

  @override
  MessageType? get messageType => MessageType.combineV2;

  @override
  UserInfo? get userInfo => null;

  @override
  RCIMIWConversationType? get combineConversationType =>
      _conversationTypeFromValue(entry.content['combineConversationType']);

  @override
  ChannelType? get sourceChannelType =>
      _channelTypeFromConversationType(combineConversationType) ??
      sourceChannelTypeValue;

  @override
  List<String>? get summaryList => _stringList('summaryList');

  @override
  List<String>? get nameList => _stringList('nameList');

  @override
  int? get msgNum => _intValue('msgNum') ?? msgList?.length;

  @override
  List<CombineMessageInfo>? get msgList {
    final rawList = entry.content['msgList'];
    if (rawList is! List) {
      return const <CombineMessageInfo>[];
    }
    final infos = <CombineMessageInfo>[];
    for (final raw in rawList) {
      if (raw is! Map) {
        continue;
      }
      final item = raw.map((key, value) => MapEntry(key.toString(), value));
      final objectName = _nonEmpty(item['objectName']);
      final rawContent = item['content'];
      if (objectName == null || rawContent is! Map) {
        continue;
      }
      infos.add(
        CombineMessageInfo(
          fromUserId: _nonEmpty(item['fromUserId']),
          channelId:
              _nonEmpty(item['targetId']) ?? _nonEmpty(item['channelId']),
          timestamp: _intFrom(item['timestamp']),
          objectName: objectName,
          content: rawContent.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        ),
      );
    }
    return infos;
  }

  @override
  String? get jsonMsgKey => _nonEmpty(entry.content['jsonMsgKey']);

  @override
  String? get localPath {
    final text =
        _nonEmpty(entry.content['local']) ??
        _nonEmpty(entry.content['localPath']);
    if (text == null || text.isEmpty || _isHttpUrl(text)) {
      return null;
    }
    return text;
  }

  @override
  String? get remotePath =>
      _nonEmpty(entry.content['remote']) ??
      _nonEmpty(entry.content['remoteUrl']) ??
      _nonEmpty(entry.content['remotePath']) ??
      _nonEmpty(entry.content['fileUrl']);

  @override
  Future<int> downloadMedia({DownloadMediaMessageHandler? handler}) async {
    handler?.onComplete(25104, null);
    return 25104;
  }

  @override
  Map<String, dynamic> toJson({bool filterEmpty = true}) => {
    'senderUserId': senderUserId,
    'channelId': channelId,
    'sentTime': sentTime,
    'messageType': messageType?.name,
    ...entry.content,
  };

  List<String>? _stringList(String key) {
    final raw = entry.content[key];
    if (raw is! List) {
      return null;
    }
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  int? _intValue(String key) => _intFrom(entry.content[key]);

  int? _intFrom(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  RCIMIWConversationType? _conversationTypeFromValue(Object? value) {
    if (value is RCIMIWConversationType) {
      return value;
    }
    final index = _intFrom(value);
    return switch (index) {
      1 => RCIMIWConversationType.private,
      2 => RCIMIWConversationType.group,
      3 => RCIMIWConversationType.chatroom,
      4 => RCIMIWConversationType.system,
      5 => RCIMIWConversationType.ultraGroup,
      _ => null,
    };
  }

  ChannelType? _channelTypeFromConversationType(RCIMIWConversationType? type) {
    return switch (type) {
      RCIMIWConversationType.private => ChannelType.direct,
      RCIMIWConversationType.group => ChannelType.group,
      RCIMIWConversationType.chatroom => ChannelType.open,
      RCIMIWConversationType.system => ChannelType.system,
      RCIMIWConversationType.ultraGroup => ChannelType.community,
      _ => null,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

mixin _CombineMessageAdapter implements Message {
  _CombineEntry get entry;

  String? _stringValue(String key) {
    final text = entry.content[key]?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _intValue(String key) {
    final value = entry.content[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  String? _existingLocalPath(String key) {
    return _existingLocalPathFromValue(_stringValue(key));
  }

  String? _existingLocalPathFromKeys(List<String> keys) {
    for (final key in keys) {
      final path = _existingLocalPath(key);
      if (path != null && path.isNotEmpty) {
        return path;
      }
    }
    return null;
  }

  @override
  String? get senderUserId => entry.fromUserId;

  @override
  String? get channelId => entry.channelId;

  @override
  ChannelType? get channelType => ChannelType.direct;

  @override
  ChannelIdentifier? get channelIdentifier => ChannelIdentifier(
    channelType: ChannelType.direct,
    channelId: entry.channelId ?? '',
  );

  @override
  int? get sentTime => entry.timestamp;

  @override
  String? get messageId =>
      'combine:${entry.objectName}:${entry.channelId}:${entry.timestamp}:${entry.fromUserId}';

  @override
  int? get clientId => messageId.hashCode;

  @override
  MessageDirection? get direction => MessageDirection.receive;

  @override
  SentStatus? get sentStatus => SentStatus.sent;

  @override
  UserInfo? get userInfo => null;

  @override
  Map<String, dynamic> toJson({bool filterEmpty = true}) => {
    'senderUserId': senderUserId,
    'channelId': channelId,
    'sentTime': sentTime,
    'messageType': messageType?.name,
    ...entry.content,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

mixin _CombineDetachedMediaDownload on _CombineMessageAdapter
    implements MediaMessage {
  String? _downloadedLocalPath;
  CancelToken? _cancelToken;

  List<String> get _localPathKeys => const ['local', 'localPath'];

  String get _downloadFilePrefix;

  @override
  String? get localPath =>
      _downloadedLocalPath ?? _existingLocalPathFromKeys(_localPathKeys);

  @override
  set localPath(String? value) {
    _downloadedLocalPath = value;
  }

  @override
  Future<int> downloadMedia({DownloadMediaMessageHandler? handler}) async {
    final remote = remotePath?.trim();
    if (remote == null || remote.isEmpty || !_isHttpUrl(remote)) {
      handler?.onComplete(25104, null);
      return 25104;
    }
    final targetPath = _downloadTargetPath(remote);
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    unawaited(
      Dio()
          .download(
            remote,
            targetPath,
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) {
              if (total <= 0) {
                return;
              }
              final progress = ((received / total) * 100).clamp(0, 100).round();
              handler?.onProgress?.call(this, progress);
            },
          )
          .then((_) {
            if (cancelToken.isCancelled) {
              return;
            }
            localPath = targetPath;
            handler?.onComplete(0, this);
          })
          .catchError((Object error) {
            if (error is DioException && CancelToken.isCancel(error)) {
              handler?.onCanceled?.call(this);
              return;
            }
            handler?.onComplete(25104, null);
          })
          .whenComplete(() {
            if (identical(_cancelToken, cancelToken)) {
              _cancelToken = null;
            }
          }),
    );
    return 0;
  }

  @override
  Future<int> cancelDownloadingMedia(
    OperationHandler<MediaMessage> handler,
  ) async {
    final cancelToken = _cancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      handler(this, null);
      return 0;
    }
    cancelToken.cancel('Combine media download canceled');
    handler(this, null);
    return 0;
  }

  String _downloadTargetPath(String remote) {
    final extension = _pathExtension(remote) ?? _defaultDownloadExtension;
    return '${Directory.systemTemp.path}/$_downloadFilePrefix'
        '_${DateTime.now().microsecondsSinceEpoch}.$extension';
  }

  String get _defaultDownloadExtension => 'media';

  String? _pathExtension(String value) {
    final uri = Uri.tryParse(value);
    final path = uri?.hasScheme == true && uri?.path.isNotEmpty == true
        ? uri!.path
        : value;
    final fileName = path.split('/').last;
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) {
      return null;
    }
    return fileName.substring(index + 1).toLowerCase();
  }
}

class _CombineImageMessage
    with _CombineMessageAdapter, _CombineDetachedMediaDownload
    implements ImageMessage {
  @override
  final _CombineEntry entry;

  _CombineImageMessage(this.entry);

  @override
  MessageType? get messageType => MessageType.image;

  @override
  String get _downloadFilePrefix => 'nexconn_combine_image';

  @override
  String get _defaultDownloadExtension => 'jpg';

  @override
  String? get remotePath => _firstNetworkPath([
    _stringValue('remote'),
    _stringValue('remoteUrl'),
    _stringValue('imageUri'),
    _stringValue('remotePath'),
    _stringValue('fileUrl'),
  ]);

  @override
  String? get thumbnailBase64String =>
      _stringValue('thumbnailBase64String') ??
      _stringValue('thumbnailBase64') ??
      _stringValue('thumb') ??
      _stringValue('thumbnail') ??
      _stringValue('content');

  @override
  int? get thumWidth => _intValue('width') ?? _intValue('thumWidth');

  @override
  int? get thumHeight => _intValue('height') ?? _intValue('thumHeight');
}

class _CombineGifMessage
    with _CombineMessageAdapter, _CombineDetachedMediaDownload
    implements GIFMessage {
  @override
  final _CombineEntry entry;

  _CombineGifMessage(this.entry);

  @override
  MessageType? get messageType => MessageType.gif;

  @override
  String get _downloadFilePrefix => 'nexconn_combine_gif';

  @override
  String get _defaultDownloadExtension => 'gif';

  @override
  String? get remotePath => _firstNetworkPath([
    _stringValue('remote'),
    _stringValue('remoteUrl'),
    _stringValue('imageUri'),
    _stringValue('remotePath'),
    _stringValue('fileUrl'),
  ]);

  @override
  int? get dataSize =>
      _intValue('gifDataSize') ?? _intValue('dataSize') ?? _intValue('size');

  @override
  int? get width => _intValue('width');

  @override
  int? get height => _intValue('height');
}

class _CombineShortVideoMessage
    with _CombineMessageAdapter, _CombineDetachedMediaDownload
    implements ShortVideoMessage {
  @override
  final _CombineEntry entry;

  _CombineShortVideoMessage(this.entry);

  @override
  MessageType? get messageType => MessageType.sight;

  @override
  String get _downloadFilePrefix => 'nexconn_combine_short_video';

  @override
  String get _defaultDownloadExtension => 'mp4';

  @override
  String? get remotePath => _firstNetworkPath([
    _stringValue('remote'),
    _stringValue('sightUrl'),
    _stringValue('remoteUrl'),
    _stringValue('remotePath'),
    _stringValue('fileUrl'),
  ]);

  @override
  int? get duration => _intValue('duration');

  @override
  int? get size => _intValue('size');

  @override
  String? get name => _stringValue('name');

  @override
  String? get thumbnailBase64String =>
      _stringValue('thumbnailBase64String') ??
      _stringValue('thumbnailBase64') ??
      _stringValue('thumb') ??
      _stringValue('thumbnail') ??
      _stringValue('content');
}

class _CombineFileMessage with _CombineMessageAdapter implements FileMessage {
  @override
  final _CombineEntry entry;

  _CombineFileMessage(this.entry);

  String? _downloadedLocalPath;

  @override
  MessageType? get messageType => MessageType.file;

  @override
  String? get localPath =>
      _downloadedLocalPath ??
      _existingLocalPathFromKeys(['local', 'localPath']);

  @override
  set localPath(String? value) {
    _downloadedLocalPath = value;
  }

  @override
  String? get remotePath => _firstNetworkPath([
    _stringValue('remote'),
    _stringValue('fileUrl'),
    _stringValue('remoteUrl'),
    _stringValue('remotePath'),
  ]);

  @override
  String? get name => _stringValue('name') ?? _fileNameFromPath(remotePath);

  @override
  String? get fileType => _stringValue('type') ?? _stringValue('fileType');

  @override
  int? get size => _intValue('size');

  @override
  Future<int> downloadMedia({DownloadMediaMessageHandler? handler}) async {
    handler?.onComplete(25104, null);
    return 25104;
  }

  String? _fileNameFromPath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(path);
    final segments = uri?.pathSegments;
    if (segments != null && segments.isNotEmpty) {
      return segments.last;
    }
    return path.split('/').last;
  }
}

class _CombineVoiceMessage
    with _CombineMessageAdapter, _CombineDetachedMediaDownload
    implements HDVoiceMessage {
  @override
  final _CombineEntry entry;

  _CombineVoiceMessage(this.entry);

  @override
  MessageType? get messageType => MessageType.voice;

  @override
  String get _downloadFilePrefix => 'nexconn_combine_voice';

  @override
  String? get remotePath => _firstNetworkPath([
    _stringValue('remote'),
    _stringValue('remoteUrl'),
    _stringValue('remotePath'),
    _stringValue('wavUri'),
    _stringValue('fileUrl'),
  ]);

  @override
  int? get duration => _intValue('duration');
}
