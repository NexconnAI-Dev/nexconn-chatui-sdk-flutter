import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../providers/chat_provider.dart';
import '../../ui_config/chat/page/chat_page_config.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/time_util.dart';

/// Shows read and unread user lists for a message.
class ReadReceiptUsersSheet extends StatefulWidget {
  static const Key sheetKey = ValueKey('read-receipt-users-sheet');
  static const Key readTabKey = ValueKey('read-receipt-users-read-tab');
  static const Key unreadTabKey = ValueKey('read-receipt-users-unread-tab');

  final ChatProvider provider;
  final Message message;
  final MessageListConfig config;

  const ReadReceiptUsersSheet({
    super.key,
    required this.provider,
    required this.message,
    required this.config,
  });

  static Future<void> show(
    BuildContext context, {
    required ChatProvider provider,
    required Message message,
    required MessageListConfig config,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.72,
          child: ReadReceiptUsersSheet(
            provider: provider,
            message: message,
            config: config,
          ),
        );
      },
    );
  }

  @override
  State<ReadReceiptUsersSheet> createState() => _ReadReceiptUsersSheetState();
}

class _ReadReceiptUsersSheetState extends State<ReadReceiptUsersSheet> {
  late Future<ChatReadReceiptUsersData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ChatReadReceiptUsersData> _load() {
    return widget.provider.loadReadReceiptUsers(
      widget.message,
      loader: widget.config.readReceiptUsersLoader,
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.chatUIL10n;
    return FutureBuilder<ChatReadReceiptUsersData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildScaffold(
            context,
            child: _ReceiptLoading(
              text:
                  widget.config.readReceiptUsersLoadingText ??
                  l10n.chatReadReceiptUsersLoading,
            ),
          );
        }
        if (snapshot.hasError) {
          return _buildScaffold(
            context,
            child: _ReceiptError(
              text:
                  widget.config.readReceiptUsersLoadFailedText ??
                  l10n.chatReadReceiptUsersLoadFailed,
              onRetry: _retry,
            ),
          );
        }
        final data = snapshot.data ?? const ChatReadReceiptUsersData();
        return DefaultTabController(
          length: 2,
          child: _buildScaffold(
            context,
            child: Column(
              children: [
                Container(
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEAEAEA)),
                    ),
                  ),
                  child: TabBar(
                    labelColor: const Color(0xFF3D6DCC),
                    unselectedLabelColor: const Color(0xFF666666),
                    indicatorColor: const Color(0xFF3D6DCC),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: [
                      Tab(
                        key: ReadReceiptUsersSheet.readTabKey,
                        text:
                            '${widget.config.readReceiptUsersReadTabText ?? l10n.chatReadReceiptUsersReadTab} ${data.readCount}',
                      ),
                      Tab(
                        key: ReadReceiptUsersSheet.unreadTabKey,
                        text:
                            '${widget.config.readReceiptUsersUnreadTabText ?? l10n.chatReadReceiptUsersUnreadTab} ${data.unreadCount}',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ReceiptUsersList(
                        users: data.readUsers,
                        now: widget.provider.engineProvider.serverNow,
                        emptyText:
                            widget.config.readReceiptUsersEmptyText ??
                            l10n.chatReadReceiptUsersEmpty,
                      ),
                      _ReceiptUsersList(
                        users: data.unreadUsers,
                        now: widget.provider.engineProvider.serverNow,
                        emptyText:
                            widget.config.readReceiptUsersEmptyText ??
                            l10n.chatReadReceiptUsersEmpty,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context, {required Widget child}) {
    final l10n = context.chatUIL10n;
    return SafeArea(
      top: false,
      child: Material(
        key: ReadReceiptUsersSheet.sheetKey,
        color: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D8D8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.config.readReceiptUsersTitle ??
                                l10n.chatReadReceiptUsersTitle,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.readReceiptCloseTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: ChatUIAsset.image(
                            'NexconnLightIcon/Close.png',
                            width: 22,
                            height: 22,
                            color: const Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptUsersList extends StatelessWidget {
  final List<ChatReadReceiptUserEntry> users;
  final DateTime? now;
  final String emptyText;

  const _ReceiptUsersList({
    required this.users,
    required this.now,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return _ReceiptEmpty(text: emptyText);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, index) {
        final user = users[index];
        final l10n = context.chatUIL10n;
        final title = user.title.isNotEmpty
            ? user.title
            : l10n.commonUnknownUser;
        final subtitle = user.subtitle ?? _defaultSubtitle(context, user, now);
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFFEFF3FF),
                child: Text(
                  title.characters.first,
                  style: const TextStyle(
                    color: Color(0xFF3D6DCC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _defaultSubtitle(
    BuildContext context,
    ChatReadReceiptUserEntry user,
    DateTime? now,
  ) {
    if (user.subtitle != null) {
      return user.subtitle;
    }
    if (!user.isRead || user.timestamp == null) {
      return null;
    }
    final timeText = TimeUtil.formatMessageTime(
      user.timestamp,
      now: now,
      l10n: context.chatUIL10n,
    );
    if (timeText.isEmpty) {
      return null;
    }
    return context.chatUIL10n.readReceiptReadAt(timeText);
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
