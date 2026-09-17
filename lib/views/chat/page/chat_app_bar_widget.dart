import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/nexconn_chat_ui_l10n.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../routes/nexconn_chat_ui_routes.dart';
import '../../../ui_config/chat/page/chat_page_config.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/constants.dart';
import '../../../utils/system_ui_overlay.dart';
import '../../chat_extras/chat_message_search_page.dart';

class ChatAppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  final BaseChannel channel;
  final ChatPageConfig config;

  const ChatAppBarWidget({
    super.key,
    required this.channel,
    required this.config,
  });

  @override
  State<ChatAppBarWidget> createState() => _ChatAppBarWidgetState();

  @override
  Size get preferredSize => Size.fromHeight(config.appBarConfig.height);
}

class _ChatAppBarWidgetState extends State<ChatAppBarWidget> {
  String? _resolvedTitle;
  int _titleResolveVersion = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveTitle();
  }

  @override
  void didUpdateWidget(covariant ChatAppBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDifferentChannel(oldWidget.channel, widget.channel) ||
        oldWidget.channel.latestMessage != widget.channel.latestMessage ||
        oldWidget.config.appBarConfig.titleResolver !=
            widget.config.appBarConfig.titleResolver ||
        oldWidget.config.profileProvider != widget.config.profileProvider ||
        oldWidget.config.appBarConfig.title !=
            widget.config.appBarConfig.title) {
      _resolveTitle();
    }
  }

  Future<void> _resolveTitle() async {
    final requestVersion = ++_titleResolveVersion;
    final title = await _loadResolvedTitle();
    if (!mounted || requestVersion != _titleResolveVersion) {
      return;
    }
    if (_resolvedTitle == title) {
      return;
    }
    setState(() => _resolvedTitle = title);
  }

  Future<String?> _loadResolvedTitle() async {
    final resolver = widget.config.appBarConfig.titleResolver;
    if (resolver != null) {
      final resolved = _normalizeTitle(await resolver(context, widget.channel));
      if (resolved != null) {
        return resolved;
      }
    }
    final profileProvider = widget.config.profileProvider;
    if (profileProvider == null) {
      return null;
    }
    final profile = await profileProvider(widget.channel);
    return _normalizeTitle(profile?.name);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ChatProvider>(context, listen: false);
    final engineProvider = Provider.of<EngineProvider?>(context, listen: false);
    final multiSelectMode = context.select<ChatProvider, bool>(
      (provider) => provider.multiSelectMode,
    );
    final theme = NexconnThemeProvider.resolveTokens(context);
    final l10n = context.chatUIL10n;
    final appBarConfig = widget.config.appBarConfig;
    final actions = <Widget>[
      if (appBarConfig.showSearchButton)
        IconButton(
          tooltip:
              appBarConfig.searchButtonTooltip ?? l10n.chatSearchButtonTooltip,
          onPressed: () => _openSearchPage(context, provider),
          icon: ChatUIAsset.image(
            'NexconnLightIcon/Search.png',
            width: 30,
            height: 30,
            color: theme.primaryTextColor,
          ),
        ),
      ...?appBarConfig.actions,
    ];
    final leadingWidth = multiSelectMode
        ? 100.0
        : _leadingWidth(engineProvider);
    final backgroundColor = appBarConfig.backgroundColor ?? theme.panelColor;
    return AppBar(
      toolbarHeight: appBarConfig.height,
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: false,
      leading: _buildLeading(context, engineProvider),
      title: Text(
        appBarConfig.title ?? _resolvedTitle ?? _title(context, widget.channel),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            appBarConfig.titleTextStyle ??
            TextStyle(
              color: theme.primaryTextColor,
              fontSize: appbarFontSize,
              fontWeight: appbarFontWeight,
            ),
      ),
      centerTitle: appBarConfig.centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: theme.primaryTextColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemUiOverlayStyleForBackground(backgroundColor),
      actions: actions.isEmpty ? null : actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.dividerColor),
      ),
    );
  }

  double _leadingWidth(EngineProvider? engineProvider) {
    if (!widget.config.appBarConfig.showBackUnreadBadge) {
      return 56;
    }
    final unreadCount = _otherUnreadCount(engineProvider);
    if (unreadCount <= 0) {
      return 56;
    }
    final badgeWidth = unreadCount > 99
        ? unreadBubbleWidth
        : unreadCount > 9
        ? unreadBubbleWidth * 0.7
        : unreadBubbleWidth / 2;
    return 39 + badgeWidth;
  }

  Widget _buildLeading(BuildContext context, EngineProvider? engineProvider) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        if (provider.multiSelectMode) {
          return TextButton(
            onPressed: () => provider.setMultiSelectMode(false),
            child: Text(
              context.chatUIL10n.commonCancel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.primaryTextColor, fontSize: 16),
            ),
          );
        }
        final unreadCount = _otherUnreadCount(engineProvider);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 3, 0),
                child: ChatUIAsset.image(
                  'NexconnLightIcon/Left-arrow.png',
                  width: 24,
                  height: 24,
                  color: theme.primaryTextColor,
                ),
              ),
              if (widget.config.appBarConfig.showBackUnreadBadge &&
                  unreadCount > 0)
                _UnreadBackBadge(count: unreadCount),
            ],
          ),
        );
      },
    );
  }

  int _otherUnreadCount(EngineProvider? engineProvider) {
    if (engineProvider == null) {
      return 0;
    }
    final current = widget.channel.unreadCount ?? 0;
    final count = engineProvider.totalUnreadCount - current;
    return count < 0 ? 0 : count;
  }

  Future<void> _openSearchPage(
    BuildContext context,
    ChatProvider provider,
  ) async {
    final title =
        widget.config.appBarConfig.searchPageTitle ??
        context.chatUIL10n.chatSearchPageTitle;
    await pushNexconnChatUINamedRouteOr<void>(
      context,
      NexconnChatUIRoutes.chatSearch,
      arguments: NexconnChatSearchRouteArguments(
        provider: provider,
        channel: widget.channel,
        title: title,
      ),
      fallbackRoute: () => MaterialPageRoute<void>(
        builder: (_) => ChatMessageSearchPage(
          provider: provider,
          channel: widget.channel,
          title: title,
        ),
      ),
    );
  }

  String _title(BuildContext context, BaseChannel channel) {
    switch (channel.channelType) {
      case ChannelType.direct:
        return channel.channelId;
      case ChannelType.group:
        return context.chatUIL10n.channelGroupTitle(channel.channelId);
      case ChannelType.open:
        return context.chatUIL10n.channelOpenTitle(channel.channelId);
      case ChannelType.community:
        return context.chatUIL10n.channelCommunityTitle(channel.channelId);
      case ChannelType.system:
        return channel.channelId;
    }
  }

  String? _normalizeTitle(String? title) {
    final normalized = title?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  bool _isDifferentChannel(BaseChannel previous, BaseChannel next) {
    return previous.channelType != next.channelType ||
        previous.channelId != next.channelId ||
        previous.channelIdentifier.subChannelId !=
            next.channelIdentifier.subChannelId;
  }
}

class _UnreadBackBadge extends StatelessWidget {
  final int count;

  const _UnreadBackBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : count.toString();
    final width = count > 99
        ? unreadBubbleWidth
        : count > 9
        ? unreadBubbleWidth * 0.7
        : unreadBubbleWidth / 2;
    return SizedBox(
      width: width,
      height: 21,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10.5),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: convoUnreadFontSize,
              fontWeight: convoUnreadFontWeight,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
