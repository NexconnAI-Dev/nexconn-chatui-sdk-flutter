import 'dart:async';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../models/chat_profile_info.dart';
import '../../providers/chat_provider.dart';
import '../../providers/engine_provider.dart';
import '../../ui_config/chat/page/chat_page_config.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/chatui_image_util.dart';
import '../../utils/message_content_util.dart';
import '../../utils/time_util.dart';

/// Full-page read/unread member lists for one message's V5 read receipt,
/// aligned with the IMKit "message read status" detail page.
class ReadReceiptUsersPage extends StatefulWidget {
  static const Key pageKey = ValueKey('read-receipt-users-page');
  static const Key readTabKey = ValueKey('read-receipt-users-read-tab');
  static const Key unreadTabKey = ValueKey('read-receipt-users-unread-tab');

  final ChatProvider provider;
  final Message message;
  final MessageListConfig config;
  final ChatProfileProvider? profileProvider;
  final ChatReadReceiptMemberBuilder? memberBuilder;

  const ReadReceiptUsersPage({
    super.key,
    required this.provider,
    required this.message,
    required this.config,
    this.profileProvider,
    this.memberBuilder,
  });

  /// Pushes the detail page; group-only by convention (callers gate this).
  static Future<void> push(
    BuildContext context, {
    required ChatProvider provider,
    required Message message,
    required MessageListConfig config,
    ChatProfileProvider? profileProvider,
    ChatReadReceiptMemberBuilder? memberBuilder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReadReceiptUsersPage(
          provider: provider,
          message: message,
          config: config,
          profileProvider: profileProvider,
          memberBuilder: memberBuilder,
        ),
      ),
    );
  }

  @override
  State<ReadReceiptUsersPage> createState() => _ReadReceiptUsersPageState();
}

class _ReadReceiptUsersPageState extends State<ReadReceiptUsersPage> {
  late final _ReceiptUsersPageState _readState;
  late final _ReceiptUsersPageState _unreadState;
  late final ChatProvider _sessionProvider;
  late final EngineProvider _engineProvider;
  late final String _sessionUserId;
  late final _ReadReceiptCapabilitySnapshot _sessionCapability;
  late final _ReadReceiptSessionIdentity? _sessionIdentity;
  final Map<String, Future<ChatProfileInfo?>> _profileFutures =
      <String, Future<ChatProfileInfo?>>{};
  bool _legacyLoading = false;
  bool _invalidSession = false;
  Object? _legacyError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final summary = widget.provider.readReceiptDataFor(widget.message);
    _readState = _ReceiptUsersPageState(
      status: MessageReadReceiptStatus.read,
      totalCount: summary?.readCount ?? 0,
    );
    _unreadState = _ReceiptUsersPageState(
      status: MessageReadReceiptStatus.unread,
      totalCount: summary?.unreadCount ?? 0,
    );
    _sessionProvider = widget.provider;
    _engineProvider = widget.provider.engineProvider;
    _sessionUserId = _engineProvider.currentUserId;
    _sessionCapability = _ReadReceiptCapabilitySnapshot.capture(
      widget.provider,
    );
    _sessionIdentity = _ReadReceiptSessionIdentity.capture(
      widget.provider,
      widget.message,
    );
    _engineProvider.addListener(_handleSessionChanged);
    _engineProvider.readReceiptVersionNotifier.addListener(
      _handleSessionChanged,
    );
    if (_isSessionCurrent) {
      unawaited(_initialize());
    } else {
      _invalidateSession();
    }
  }

  @override
  void didUpdateWidget(covariant ReadReceiptUsersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleSessionChanged();
  }

  bool get _isSessionCurrent {
    final identity = _sessionIdentity;
    return !_invalidSession &&
        identical(widget.provider, _sessionProvider) &&
        identical(widget.provider.engineProvider, _engineProvider) &&
        _engineProvider.currentUserId == _sessionUserId &&
        _ReadReceiptCapabilitySnapshot.capture(widget.provider) ==
            _sessionCapability &&
        identity != null &&
        identity.matches(widget.provider, widget.message);
  }

  void _handleSessionChanged() {
    if (!_isSessionCurrent) {
      _invalidateSession();
    }
  }

  void _invalidateSession() {
    if (_invalidSession) return;
    _invalidSession = true;
    _generation++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      unawaited(Navigator.of(context).maybePop());
    });
  }

  Future<void> _initialize() async {
    if (!_isSessionCurrent) return;
    final generation = _generation;
    if (widget.config.readReceiptUsersLoader != null) {
      await _loadLegacy();
      return;
    }
    try {
      final pageSize = widget.config.readReceiptUsersPageSize;
      final readSource = widget.provider.createReadReceiptUsersPageSource(
        widget.message,
        MessageReadReceiptStatus.read,
        pageSize: pageSize,
      );
      final unreadSource = widget.provider.createReadReceiptUsersPageSource(
        widget.message,
        MessageReadReceiptStatus.unread,
        pageSize: pageSize,
      );
      if (readSource == null || unreadSource == null) {
        await _loadLegacy();
        return;
      }
      if (!_isSessionCurrent || generation != _generation) return;
      _readState.source = readSource;
      _unreadState.source = unreadSource;
      await Future.wait<void>([
        _loadNextPage(_readState),
        _loadNextPage(_unreadState),
      ]);
    } catch (error) {
      if (!mounted || !_isSessionCurrent || generation != _generation) return;
      setState(() => _legacyError = error);
    }
  }

  Future<void> _loadLegacy() async {
    if (!_isSessionCurrent) return;
    final generation = _generation;
    if (mounted) {
      setState(() {
        _legacyLoading = true;
        _legacyError = null;
      });
    }
    try {
      final data = await widget.provider.loadReadReceiptUsers(
        widget.message,
        loader: widget.config.readReceiptUsersLoader,
      );
      if (!mounted || !_isSessionCurrent || generation != _generation) return;
      setState(() {
        _readState
          ..users = List<ChatReadReceiptUserEntry>.of(data.readUsers)
          ..totalCount = data.readCount
          ..initialLoaded = true
          ..hasMore = false;
        _unreadState
          ..users = List<ChatReadReceiptUserEntry>.of(data.unreadUsers)
          ..totalCount = data.unreadCount
          ..initialLoaded = true
          ..hasMore = false;
      });
    } catch (error) {
      if (!mounted || !_isSessionCurrent || generation != _generation) return;
      setState(() => _legacyError = error);
    } finally {
      if (mounted && _isSessionCurrent && generation == _generation) {
        setState(() => _legacyLoading = false);
      }
    }
  }

  Future<void> _loadNextPage(_ReceiptUsersPageState state) async {
    if (!_isSessionCurrent) return;
    final source = state.source;
    if (source == null ||
        state.loading ||
        (state.initialLoaded && !state.hasMore)) {
      return;
    }
    final generation = _generation;
    if (mounted) {
      setState(() {
        state.loading = true;
        state.error = null;
      });
    }
    try {
      final page = await source.loadNextPage();
      if (!mounted || !_isSessionCurrent || generation != _generation) return;
      final knownUserIds = state.users
          .map((user) => user.userId)
          .where((userId) => userId.isNotEmpty)
          .toSet();
      final additions = page.users.where(
        (user) => user.userId.isEmpty || knownUserIds.add(user.userId),
      );
      setState(() {
        state.users = <ChatReadReceiptUserEntry>[...state.users, ...additions];
        state.totalCount = page.totalCount;
        state.initialLoaded = true;
        state.hasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted || !_isSessionCurrent || generation != _generation) return;
      setState(() => state.error = error);
    } finally {
      if (mounted && _isSessionCurrent && generation == _generation) {
        setState(() => state.loading = false);
      }
    }
  }

  void _retry() {
    if (_legacyError != null) {
      unawaited(_loadLegacy());
    }
  }

  Future<ChatProfileInfo?>? _profileFutureFor(ChatReadReceiptUserEntry user) {
    final profileProvider = widget.profileProvider;
    final userId = user.userId.trim();
    if (profileProvider == null || userId.isEmpty || !_isSessionCurrent) {
      return null;
    }
    return _profileFutures.putIfAbsent(userId, () {
      final generation = _generation;
      final profileMessage = _ReadReceiptProfileMessage(widget.message, userId);
      return Future<ChatProfileInfo?>.sync(
        () => profileProvider(widget.provider.channel, message: profileMessage),
      ).then<ChatProfileInfo?>((profile) {
        if (!_isSessionCurrent || generation != _generation) return null;
        return profile;
      }, onError: (_, __) => null);
    });
  }

  Future<ChatProfileInfo?>? _senderProfileFuture() {
    final profileProvider = widget.profileProvider;
    if (profileProvider == null || !_isSessionCurrent) {
      return null;
    }
    return Future<ChatProfileInfo?>.sync(
      () => profileProvider(widget.provider.channel, message: widget.message),
    );
  }

  @override
  void dispose() {
    _generation++;
    _engineProvider.removeListener(_handleSessionChanged);
    _engineProvider.readReceiptVersionNotifier.removeListener(
      _handleSessionChanged,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_invalidSession) return const SizedBox.shrink();
    final l10n = context.chatUIL10n;
    return Scaffold(
      key: ReadReceiptUsersPage.pageKey,
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          widget.config.readReceiptUsersTitle ?? l10n.chatReadReceiptUsersTitle,
        ),
      ),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, NexconnChatUILocalizations l10n) {
    if (_legacyLoading && !_readState.initialLoaded) {
      return _ReceiptLoading(
        text:
            widget.config.readReceiptUsersLoadingText ??
            l10n.chatReadReceiptUsersLoading,
      );
    }
    if (_legacyError != null && !_readState.initialLoaded) {
      return _ReceiptError(
        text:
            widget.config.readReceiptUsersLoadFailedText ??
            l10n.chatReadReceiptUsersLoadFailed,
        onRetry: _retry,
      );
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _MessageSummaryCard(
            message: widget.message,
            senderProfileFuture: _senderProfileFuture(),
            now: widget.provider.engineProvider.serverNow,
          ),
          Container(
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA))),
            ),
            child: TabBar(
              labelColor: const Color(0xFF3D6DCC),
              unselectedLabelColor: const Color(0xFF666666),
              indicatorColor: const Color(0xFF3D6DCC),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  key: ReadReceiptUsersPage.readTabKey,
                  text:
                      '${widget.config.readReceiptUsersReadTabText ?? l10n.chatReadReceiptUsersReadTab}(${_readState.totalCount})',
                ),
                Tab(
                  key: ReadReceiptUsersPage.unreadTabKey,
                  text:
                      '${widget.config.readReceiptUsersUnreadTabText ?? l10n.chatReadReceiptUsersUnreadTab}(${_unreadState.totalCount})',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUsersList(context, _readState),
                _buildUsersList(context, _unreadState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList(BuildContext context, _ReceiptUsersPageState state) {
    final l10n = context.chatUIL10n;
    return _ReceiptUsersList(
      users: state.users,
      now: widget.provider.engineProvider.serverNow,
      status: state.status,
      profileFutureFor: _profileFutureFor,
      memberBuilder: widget.memberBuilder,
      emptyText:
          widget.config.readReceiptUsersEmptyText ??
          l10n.chatReadReceiptUsersEmpty,
      loadingText:
          widget.config.readReceiptUsersLoadingText ??
          l10n.chatReadReceiptUsersLoading,
      errorText:
          widget.config.readReceiptUsersLoadFailedText ??
          l10n.chatReadReceiptUsersLoadFailed,
      initialLoading: state.loading && state.users.isEmpty,
      loadingMore: state.loading && state.users.isNotEmpty,
      hasMore: state.hasMore,
      error: state.error,
      onLoadMore: () => _loadNextPage(state),
      onRetry: () => _loadNextPage(state),
    );
  }
}

/// Header card showing the message preview above the read/unread tabs.
class _MessageSummaryCard extends StatelessWidget {
  final Message message;
  final Future<ChatProfileInfo?>? senderProfileFuture;
  final DateTime? now;

  const _MessageSummaryCard({
    required this.message,
    this.senderProfileFuture,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.chatUIL10n;
    final timeText = TimeUtil.chatViewFormatTime(
      message.sentTime,
      now: now,
      l10n: l10n,
    );
    final fallbackName = message.senderUserId ?? '';
    final imagePreview = message is ImageMessage
        ? _summaryImagePreview(message as ImageMessage)
        : null;
    final summary = imagePreview == null
        ? messageSummary(message, localizations: l10n)
        : '';
    final nameTile = FutureBuilder<ChatProfileInfo?>(
      future: senderProfileFuture,
      builder: (context, snapshot) {
        final resolved = snapshot.data?.name?.trim();
        final name = resolved != null && resolved.isNotEmpty
            ? resolved
            : (fallbackName.isNotEmpty ? fallbackName : '');
        return Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF111111), fontSize: 15),
        );
      },
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: nameTile),
              const SizedBox(width: 12),
              Text(
                timeText,
                style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
              ),
            ],
          ),
          if (imagePreview != null) ...[
            const SizedBox(height: 10),
            imagePreview,
          ] else if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 15),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _summaryImagePreview(ImageMessage image) {
    final thumbnail = ChatUIImageUtil.getDecodedBase64(
      image.thumbnailBase64String,
    );
    if (thumbnail != null) {
      return _thumbnailBox(Image.memory(thumbnail, fit: BoxFit.cover));
    }
    final localPath = image.localPath?.trim();
    if (localPath != null && localPath.isNotEmpty && !_isNetwork(localPath)) {
      final file = Uri.tryParse(localPath)?.scheme == 'file'
          ? File.fromUri(Uri.parse(localPath))
          : File(localPath);
      if (file.existsSync()) {
        return _thumbnailBox(Image.file(file, fit: BoxFit.cover));
      }
    }
    final remotePath = image.remotePath?.trim();
    if (remotePath != null && remotePath.isNotEmpty) {
      return _thumbnailBox(
        Image.network(
          remotePath,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
        ),
      );
    }
    return null;
  }

  Widget _thumbnailBox(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox.square(dimension: 60, child: child),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFFEFF1F7),
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: Color(0xFFC1C1C1),
      ),
    );
  }

  bool _isNetwork(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}

class _ReadReceiptCapabilitySnapshot {
  final ReadReceiptVersion? version;
  final bool enabledForChannel;

  const _ReadReceiptCapabilitySnapshot({
    required this.version,
    required this.enabledForChannel,
  });

  factory _ReadReceiptCapabilitySnapshot.capture(ChatProvider provider) {
    final channelType = provider.channel.channelType;
    final options = provider.readReceiptOptions;
    return _ReadReceiptCapabilitySnapshot(
      version: provider.engineProvider.readReceiptVersion,
      enabledForChannel:
          options.enabled &&
          options.enabledChannelTypes.contains(channelType) &&
          (channelType == ChannelType.direct ||
              channelType == ChannelType.group),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _ReadReceiptCapabilitySnapshot &&
      other.version == version &&
      other.enabledForChannel == enabledForChannel;

  @override
  int get hashCode => Object.hash(version, enabledForChannel);
}

class _ReadReceiptSessionIdentity {
  final ChannelType channelType;
  final String channelId;
  final String? subChannelId;
  final String messageId;

  const _ReadReceiptSessionIdentity({
    required this.channelType,
    required this.channelId,
    required this.subChannelId,
    required this.messageId,
  });

  static _ReadReceiptSessionIdentity? capture(
    ChatProvider provider,
    Message message,
  ) {
    try {
      final channel = provider.channel.channelIdentifier;
      final messageType = message.channelType;
      final messageChannelId = message.channelId?.trim();
      final messageId = message.messageId?.trim();
      final channelId = channel.channelId.trim();
      final subChannelId = _normalize(channel.subChannelId);
      final messageSubChannelId = _normalize(message.subChannelId);
      if (messageType == null ||
          messageChannelId == null ||
          messageChannelId.isEmpty ||
          messageId == null ||
          messageId.isEmpty ||
          channelId.isEmpty ||
          messageType != channel.channelType ||
          messageChannelId != channelId ||
          messageSubChannelId != subChannelId) {
        return null;
      }
      return _ReadReceiptSessionIdentity(
        channelType: channel.channelType,
        channelId: channelId,
        subChannelId: subChannelId,
        messageId: messageId,
      );
    } catch (_) {
      return null;
    }
  }

  bool matches(ChatProvider provider, Message message) =>
      this == capture(provider, message);

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  bool operator ==(Object other) =>
      other is _ReadReceiptSessionIdentity &&
      other.channelType == channelType &&
      other.channelId == channelId &&
      other.subChannelId == subChannelId &&
      other.messageId == messageId;

  @override
  int get hashCode =>
      Object.hash(channelType, channelId, subChannelId, messageId);
}

class _ReadReceiptProfileMessage extends Message {
  final String profileUserId;

  _ReadReceiptProfileMessage(Message source, this.profileUserId)
    : super.wrap(source.raw);

  @override
  String get senderUserId => profileUserId;
}

class _ReceiptUsersPageState {
  ChatReadReceiptUsersPageSource? source;
  List<ChatReadReceiptUserEntry> users = <ChatReadReceiptUserEntry>[];
  final MessageReadReceiptStatus status;
  int totalCount;
  bool initialLoaded = false;
  bool loading = false;
  bool hasMore = true;
  Object? error;

  _ReceiptUsersPageState({required this.status, required this.totalCount});
}

class _ReceiptUsersList extends StatelessWidget {
  final List<ChatReadReceiptUserEntry> users;
  final DateTime? now;
  final MessageReadReceiptStatus status;
  final Future<ChatProfileInfo?>? Function(ChatReadReceiptUserEntry user)
  profileFutureFor;
  final ChatReadReceiptMemberBuilder? memberBuilder;
  final String emptyText;
  final String loadingText;
  final String errorText;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRetry;

  const _ReceiptUsersList({
    required this.users,
    required this.now,
    required this.status,
    required this.profileFutureFor,
    required this.memberBuilder,
    required this.emptyText,
    required this.loadingText,
    required this.errorText,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.onLoadMore,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty && initialLoading) {
      return _ReceiptLoading(text: loadingText);
    }
    if (users.isEmpty && error != null) {
      return _ReceiptError(
        text: errorText,
        onRetry: () => unawaited(onRetry()),
      );
    }
    if (users.isEmpty) {
      return _ReceiptEmpty(text: emptyText);
    }
    final showFooter = loadingMore || error != null;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return _ReceiptPageFooter(loading: loadingMore, onRetry: onRetry);
        }
        if (hasMore && index >= users.length - 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) unawaited(onLoadMore());
          });
        }
        final user = users[index];
        final readTimeText = status == MessageReadReceiptStatus.read
            ? _formatReadTime(context, user, now)
            : null;
        return _ReceiptUserItem(
          user: user,
          status: status,
          index: index,
          trailingText: readTimeText,
          profileFuture: profileFutureFor(user),
          memberBuilder: memberBuilder,
        );
      },
    );
  }

  String? _formatReadTime(
    BuildContext context,
    ChatReadReceiptUserEntry user,
    DateTime? now,
  ) {
    if (!user.isRead || user.timestamp == null) {
      return null;
    }
    return TimeUtil.chatViewFormatTime(
      user.timestamp,
      now: now,
      l10n: context.chatUIL10n,
    );
  }
}

class _ReceiptUserItem extends StatelessWidget {
  final ChatReadReceiptUserEntry user;
  final MessageReadReceiptStatus status;
  final int index;
  final String? trailingText;
  final Future<ChatProfileInfo?>? profileFuture;
  final ChatReadReceiptMemberBuilder? memberBuilder;

  const _ReceiptUserItem({
    required this.user,
    required this.status,
    required this.index,
    required this.trailingText,
    required this.profileFuture,
    required this.memberBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = _effectiveProfile(context, null);
    final future = profileFuture;
    if (future == null) {
      return _buildWithProfile(context, fallback);
    }
    return FutureBuilder<ChatProfileInfo?>(
      future: future,
      initialData: fallback,
      builder: (context, snapshot) =>
          _buildWithProfile(context, _effectiveProfile(context, snapshot.data)),
    );
  }

  Widget _buildWithProfile(BuildContext context, ChatProfileInfo profile) {
    final customBuilder = memberBuilder;
    if (customBuilder != null) {
      return customBuilder(
        context,
        ChatReadReceiptMemberViewData(
          receiptUser: user,
          profile: profile,
          readStatus: status,
          index: index,
        ),
      );
    }
    return _DefaultReceiptUserRow(profile: profile, trailingText: trailingText);
  }

  ChatProfileInfo _effectiveProfile(
    BuildContext context,
    ChatProfileInfo? resolved,
  ) {
    final userId = user.userId.trim();
    final entryTitle = user.title.trim();
    final resolvedName = resolved?.name?.trim();
    final hasCustomEntryTitle = entryTitle.isNotEmpty && entryTitle != userId;
    final name = hasCustomEntryTitle
        ? entryTitle
        : resolvedName?.isNotEmpty == true
        ? resolvedName!
        : entryTitle.isNotEmpty
        ? entryTitle
        : userId.isNotEmpty
        ? userId
        : context.chatUIL10n.commonUnknownUser;
    final resolvedId = resolved?.id.trim();
    return ChatProfileInfo(
      id: resolvedId?.isNotEmpty == true ? resolvedId! : userId,
      name: name,
      portraitUri: resolved?.portraitUri,
      extra: resolved?.extra,
    );
  }
}

class _DefaultReceiptUserRow extends StatelessWidget {
  final ChatProfileInfo profile;
  final String? trailingText;

  const _DefaultReceiptUserRow({required this.profile, this.trailingText});

  @override
  Widget build(BuildContext context) {
    final title = profile.name?.trim().isNotEmpty == true
        ? profile.name!.trim()
        : profile.id;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _ReceiptUserAvatar(title: title, imageUrl: profile.portraitUri),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 16),
            ),
          ),
          if (trailingText != null) ...[
            const SizedBox(width: 12),
            Text(
              trailingText!,
              style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptUserAvatar extends StatelessWidget {
  final String title;
  final String? imageUrl;

  const _ReceiptUserAvatar({required this.title, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFEFF3FF),
      child: Text(
        title.characters.first,
        style: const TextStyle(
          color: Color(0xFF3D6DCC),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    final url = imageUrl?.trim();
    final avatar = url != null && url.startsWith('http')
        ? ClipOval(
            child: SizedBox.square(
              dimension: 40,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
          )
        : fallback;
    return Semantics(image: true, label: title, child: avatar);
  }
}

class _ReceiptPageFooter extends StatelessWidget {
  final bool loading;
  final Future<void> Function() onRetry;

  const _ReceiptPageFooter({required this.loading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: () => unawaited(onRetry()),
                child: Text(context.chatUIL10n.commonRetry),
              ),
      ),
    );
  }
}

class _ReceiptLoading extends StatelessWidget {
  final String text;

  const _ReceiptLoading({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Color(0xFF999999))),
        ],
      ),
    );
  }
}

class _ReceiptError extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ReceiptError({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/Attention.png',
            width: 42,
            height: 42,
            color: const Color(0xFFE53935),
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Color(0xFF666666))),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(context.chatUIL10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _ReceiptEmpty extends StatelessWidget {
  final String text;

  const _ReceiptEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/Member.png',
            width: 44,
            height: 44,
            color: const Color(0xFFC7C7CC),
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Color(0xFF999999))),
        ],
      ),
    );
  }
}
