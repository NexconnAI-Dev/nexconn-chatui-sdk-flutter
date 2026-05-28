import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/channel_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/chat_profile_info.dart';
import '../../../routes/nexconn_chat_ui_routes.dart';
import '../../../ui_config/channel/channel_app_bar_config.dart';
import '../../../ui_config/channel/channel_config.dart';
import '../../../ui_config/chat/page/chat_page_config.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/constants.dart';
import '../../chat/page/chat_page.dart';
import '../item/channel_item.dart';
import 'channel_app_bar_widget.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';

/// Builds a custom app bar for ChannelPage.
typedef ChannelAppBarBuilder =
    PreferredSizeWidget Function(
      BuildContext context,
      ChannelAppBarConfig config,
    );

/// Builds a custom channel row.
typedef ChannelItemBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelItemConfig config,
    );

/// Opens a chat page for a selected channel.
typedef ChannelChatPageOpener =
    Future<void> Function(BuildContext context, BaseChannel channel);

Future<T?> openChannelChatPage<T>(
  BuildContext context,
  BaseChannel channel, {
  ChatPageConfig config = const ChatPageConfig(),
  ChatProvider? provider,
  ChannelProvider Function(BuildContext context)? forwardChannelProviderBuilder,
}) {
  return pushNexconnChatUINamedRouteOr<T>(
    context,
    NexconnChatUIRoutes.chat,
    arguments: NexconnChatPageRouteArguments(
      channel: channel,
      config: config,
      provider: provider,
      forwardChannelProviderBuilder: forwardChannelProviderBuilder,
    ),
    fallbackRoute: () => MaterialPageRoute<T>(
      builder: (_) => ChatPage(
        channel: channel,
        config: config,
        provider: provider,
        forwardChannelProviderBuilder: forwardChannelProviderBuilder,
      ),
    ),
  );
}

/// Page that loads and displays channels from ChannelProvider.
class ChannelPage extends StatefulWidget {
  final ChannelConfig config;
  final ChannelProvider? provider;
  final ChannelAppBarBuilder? appBarBuilder;
  final ChannelItemBuilder? itemBuilder;
  final ChannelListItemOnTap? onItemTap;
  final ChannelListItemOnTap? onItemLongPress;
  final ChannelListItemOnTap? onAvatarTap;
  final ChannelListItemOnTap? onAvatarLongPress;
  final ChannelSearchTap? onSearchTap;
  final ChannelChatPageOpener? chatPageOpener;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? headerBuilder;
  final WidgetBuilder? footerBuilder;
  final ChannelActionsBuilder? channelActionsBuilder;
  final ChannelActionHandler? onChannelAction;
  final ChannelLongPressMenuBuilder? longPressMenuBuilder;
  final ChannelListDataProcessor? channelListDataProcessor;

  const ChannelPage({
    super.key,
    this.config = const ChannelConfig(),
    this.provider,
    this.appBarBuilder,
    this.itemBuilder,
    this.onItemTap,
    this.onItemLongPress,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.onSearchTap,
    this.chatPageOpener,
    this.emptyBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.channelActionsBuilder,
    this.onChannelAction,
    this.longPressMenuBuilder,
    this.channelListDataProcessor,
  });

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  ChannelProvider? _ownedProvider;

  ChannelProvider get _provider => widget.provider ?? _ownedProvider!;

  @override
  void initState() {
    super.initState();
    if (widget.provider == null) {
      _ownedProvider = ChannelProvider(
        engineProvider: context.read<EngineProvider>(),
        channelTypes: widget.config.listConfig.channelTypes,
        pageSize: widget.config.listConfig.pageSize,
        channelListDataProcessor: widget.channelListDataProcessor,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _ownedProvider?.reload();
        }
      });
    }
  }

  @override
  void dispose() {
    _ownedProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final resolvedBackgroundColor =
        widget.config.listConfig.backgroundColor ??
        _defaultListBackgroundColor(theme);
    final body = ChangeNotifierProvider<ChannelProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: resolvedBackgroundColor,
        appBar:
            widget.appBarBuilder?.call(context, widget.config.appBarConfig) ??
            ChannelAppBarWidget(
              config: _resolveDefaultAppBarConfig(resolvedBackgroundColor),
            ),
        body: _ChannelBody(page: widget),
      ),
    );
    return body;
  }

  ChannelAppBarConfig _resolveDefaultAppBarConfig(Color backgroundColor) {
    final appBarConfig = widget.config.appBarConfig;
    if (appBarConfig.backgroundColor != null) {
      return appBarConfig;
    }
    return ChannelAppBarConfig(
      height: appBarConfig.height,
      title: appBarConfig.title,
      centerTitle: appBarConfig.centerTitle,
      backgroundColor: backgroundColor,
      titleTextStyle: appBarConfig.titleTextStyle,
      titleSpacing: appBarConfig.titleSpacing,
      actions: appBarConfig.actions,
    );
  }

  Color _defaultListBackgroundColor(NexconnThemeTokens theme) {
    if (theme.brightness == Brightness.light &&
        theme.pageBackgroundColor ==
            NexconnThemeTokens.light.pageBackgroundColor) {
      return const Color(0xFFF2F2F2);
    }
    return theme.pageBackgroundColor;
  }
}

class _ChannelBody extends StatefulWidget {
  final ChannelPage page;

  const _ChannelBody({required this.page});

  @override
  State<_ChannelBody> createState() => _ChannelBodyState();
}

class _ChannelBodyState extends State<_ChannelBody> {
  static const int _maxScrollRestoreAttempts = 8;
  static const Key _loadingListKey = ValueKey('channel-loading-list');
  static const Key _loadingMoreIndicatorKey = ValueKey(
    'channel-loading-more-indicator',
  );
  static const int _loadingPlaceholderCount = 8;

  String? _highlightedChannelKey;
  ChannelProvider? _channelProvider;
  bool _isRestoringScrollOffset = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<ChannelProvider>();
    if (identical(_channelProvider, provider)) {
      return;
    }
    _channelProvider?.detachChannelListView();
    _channelProvider = provider;
    _channelProvider?.attachChannelListView();
  }

  @override
  void dispose() {
    _channelProvider?.detachChannelListView();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChannelProvider>(
      builder: (context, provider, _) {
        if (provider.isFetching && provider.channels.isEmpty) {
          return _loading(context, provider);
        }
        if (provider.channels.isEmpty) {
          return _empty(context, provider);
        }
        if (provider.needsChannelListScrollRestore) {
          _restoreScrollOffset(provider, provider.channelListScrollOffset);
        }
        return RefreshIndicator(
          onRefresh: provider.reload,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                provider.rememberChannelListScrollOffset(
                  notification.metrics.pixels,
                );
              }
              return false;
            },
            child: ListView.builder(
              controller: provider.scrollController,
              itemCount: _itemCount(provider),
              itemBuilder: (context, rawIndex) {
                var index = rawIndex;
                if (_showsNetworkTip(provider)) {
                  if (index == 0) {
                    return const _NetworkTip();
                  }
                  index -= 1;
                }
                if (widget.page.headerBuilder != null) {
                  if (index == 0) {
                    return widget.page.headerBuilder!(context);
                  }
                  index -= 1;
                }
                if (widget.page.config.listConfig.showSearchBar) {
                  if (index == 0) {
                    return _SearchBar(onTap: widget.page.onSearchTap);
                  }
                  index -= 1;
                }
                if (index < provider.channels.length) {
                  final channel = provider.channels[index];
                  final item =
                      widget.page.itemBuilder?.call(
                        context,
                        channel,
                        widget.page.config.itemConfig,
                      ) ??
                      ChannelItem(
                        channel: channel,
                        index: index,
                        config: widget.page.config.itemConfig,
                        highlighted:
                            _highlightedChannelKey ==
                            _highlightKey(channel, index),
                        onTap: widget.page.onItemTap ?? _handleDefaultTap,
                        onLongPress: _handleItemLongPress,
                        onAvatarTap: widget.page.onAvatarTap,
                        onAvatarLongPress: widget.page.onAvatarLongPress,
                        onAction: _runChannelAction,
                        profileProvider: widget.page.config.profileProvider,
                      );
                  return Column(
                    key: _channelRowKey(channel),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item,
                      _ChannelDivider(config: widget.page.config.itemConfig),
                    ],
                  );
                }
                index -= provider.channels.length;
                if (widget.page.footerBuilder != null) {
                  if (index == 0) {
                    return widget.page.footerBuilder!(context);
                  }
                  index -= 1;
                }
                _scheduleLoadMore(context, provider);
                return _loadMoreFooter(provider);
              },
            ),
          ),
        );
      },
    );
  }

  int _itemCount(ChannelProvider provider) {
    return provider.channels.length +
        (_showsNetworkTip(provider) ? 1 : 0) +
        (widget.page.headerBuilder != null ? 1 : 0) +
        (widget.page.config.listConfig.showSearchBar ? 1 : 0) +
        (widget.page.footerBuilder != null ? 1 : 0) +
        (provider.hasMore ? 1 : 0);
  }

  void _scheduleLoadMore(BuildContext context, ChannelProvider provider) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        provider.loadMore();
      }
    });
  }

  ValueKey<Object> _channelRowKey(BaseChannel channel) {
    return ValueKey<Object>(_channelRowIdentity(channel));
  }

  Object _channelRowIdentity(BaseChannel channel) {
    return (
      type: channel.channelType,
      id: channel.channelId,
      subId: _normalizedSubChannelId(channel.channelIdentifier.subChannelId),
    );
  }

  String _normalizedSubChannelId(String? subChannelId) {
    return subChannelId == null || subChannelId.isEmpty ? '' : subChannelId;
  }

  bool _showsNetworkTip(ChannelProvider provider) {
    return widget.page.config.listConfig.showNetworkStatusTip &&
        _isOffline(provider.connectionStatus);
  }

  Future<void> _handleDefaultTap(
    BaseChannel channel,
    int index,
    BuildContext context,
  ) async {
    if (widget.page.config.listConfig.itemTapBehavior ==
        ChannelItemTapBehavior.none) {
      return;
    }
    final provider = context.read<ChannelProvider>();
    final preservedOffset = provider.scrollController.hasClients
        ? provider.scrollController.offset
        : null;
    provider.requestChannelListScrollRestore(preservedOffset);
    provider.pushSelectedChannel(channel);
    try {
      final chatPageOpener = widget.page.chatPageOpener;
      if (chatPageOpener != null) {
        await chatPageOpener(context, channel);
      } else {
        await openChannelChatPage(
          context,
          channel,
          config: _chatPageConfigFor(channel),
        );
      }
    } finally {
      provider.popSelectedChannel();
      if (context.mounted) {
        provider.requestChannelListScrollRestore(preservedOffset);
        _restoreScrollOffset(provider, preservedOffset);
      }
    }
  }

  ChatPageConfig _chatPageConfigFor(BaseChannel channel) {
    final itemConfig = widget.page.config.itemConfig;
    final sharedProfileProvider = widget.page.config.profileProvider;
    return ChatPageConfig(
      appBarConfig: ChatAppBarConfig(
        titleResolver: (context, titleChannel) =>
            _resolveChannelTitle(context, titleChannel, itemConfig),
      ),
      profileProvider:
          sharedProfileProvider ??
          (profileChannel, {message}) async {
            final profile = await _resolveChannelDisplayProfile(
              context,
              profileChannel,
              itemConfig,
            );
            final displayName = profile?.displayName?.trim();
            final avatarUrl = profile?.avatarUrl?.trim();
            if ((displayName == null || displayName.isEmpty) &&
                (avatarUrl == null || avatarUrl.isEmpty)) {
              return null;
            }
            return ChatProfileInfo(
              id: profileChannel.channelId,
              name: displayName,
              portraitUri: avatarUrl,
            );
          },
    );
  }

  Future<String?> _resolveChannelTitle(
    BuildContext context,
    BaseChannel channel,
    ChannelItemConfig itemConfig,
  ) async {
    final profile = await _resolveChannelDisplayProfile(
      context,
      channel,
      itemConfig,
    );
    final title = profile?.displayName?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    final sharedProfileProvider = widget.page.config.profileProvider;
    if (sharedProfileProvider == null) {
      return null;
    }
    final sharedProfile = await sharedProfileProvider(channel);
    final sharedTitle = sharedProfile?.name?.trim();
    return sharedTitle == null || sharedTitle.isEmpty ? null : sharedTitle;
  }

  Future<ChannelDisplayProfile?> _resolveChannelDisplayProfile(
    BuildContext context,
    BaseChannel channel,
    ChannelItemConfig itemConfig,
  ) async {
    final configured =
        itemConfig.displayProfiles[_typedProfileKey(channel)] ??
        itemConfig.displayProfiles[channel.channelId];
    final resolver = itemConfig.displayProfileResolver;
    if (resolver == null) {
      return configured;
    }
    return await Future.value(resolver(context, channel)) ?? configured;
  }

  String _typedProfileKey(BaseChannel channel) =>
      '${channel.channelType.name}:${channel.channelId}';

  void _restoreScrollOffset(
    ChannelProvider provider,
    double? offset, {
    int attempt = 0,
  }) {
    if (offset == null) {
      return;
    }
    if (_isRestoringScrollOffset && attempt == 0) {
      return;
    }
    _isRestoringScrollOffset = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isRestoringScrollOffset = false;
        return;
      }
      if (!provider.scrollController.hasClients) {
        _retryScrollRestore(provider, offset, attempt);
        return;
      }
      final position = provider.scrollController.position;
      if (!position.hasContentDimensions) {
        _retryScrollRestore(provider, offset, attempt);
        return;
      }
      if (offset > position.maxScrollExtent && provider.hasMore) {
        provider.loadMore();
        _retryScrollRestore(provider, offset, attempt);
        return;
      }
      final target = offset.clamp(0.0, position.maxScrollExtent);
      if ((position.pixels - target).abs() > 0.5) {
        provider.scrollController.jumpTo(target);
      }
      provider.markChannelListScrollRestoreComplete();
      _isRestoringScrollOffset = false;
    });
  }

  void _retryScrollRestore(
    ChannelProvider provider,
    double offset,
    int attempt,
  ) {
    _isRestoringScrollOffset = false;
    if (attempt >= _maxScrollRestoreAttempts) {
      return;
    }
    _restoreScrollOffset(provider, offset, attempt: attempt + 1);
  }

  Future<void> _handleItemLongPress(
    BaseChannel channel,
    int index,
    BuildContext context,
  ) async {
    if (_highlightedChannelKey != null) {
      return;
    }
    final highlightKey = _highlightKey(channel, index);
    setState(() {
      _highlightedChannelKey = highlightKey;
    });

    if (widget.page.onItemLongPress != null) {
      widget.page.onItemLongPress!(channel, index, context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _clearHighlightedChannel(highlightKey);
      });
      return;
    }

    try {
      await _handleDefaultLongPress(channel, index, context);
    } finally {
      _clearHighlightedChannel(highlightKey);
    }
  }

  Future<void> _handleDefaultLongPress(
    BaseChannel channel,
    int index,
    BuildContext context,
  ) async {
    final actions =
        widget.page.channelActionsBuilder?.call(channel) ??
        _defaultChannelActions(context, channel);
    if (actions.isEmpty) {
      return;
    }
    final actionFuture = widget.page.longPressMenuBuilder != null
        ? widget.page.longPressMenuBuilder!(context, channel, actions)
        : _showDefaultActionMenu(context, actions);
    final action = await actionFuture;
    if (action == null || !context.mounted) {
      return;
    }
    await _runChannelAction(context, channel, action);
  }

  List<ChannelAction> _defaultChannelActions(
    BuildContext context,
    BaseChannel channel,
  ) {
    final pinned = channel.isPinned ?? false;
    final muted = channel.notificationLevel == ChannelNoDisturbLevel.blocked;
    return [
      ChannelAction(
        type: pinned ? ChannelActionType.unpin : ChannelActionType.pin,
        label: pinned
            ? context.chatUIL10n.channelActionUnpin
            : context.chatUIL10n.channelActionPin,
        icon: pinned ? Icons.push_pin_outlined : Icons.push_pin,
      ),
      ChannelAction(
        type: muted ? ChannelActionType.unmute : ChannelActionType.mute,
        label: muted
            ? context.chatUIL10n.channelActionUnmute
            : context.chatUIL10n.channelActionMute,
        icon: muted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
      ),
      ChannelAction(
        type: ChannelActionType.delete,
        label: context.chatUIL10n.channelActionDelete,
        icon: Icons.delete_outline,
        destructive: true,
      ),
    ];
  }

  Future<ChannelActionType?> _showDefaultActionMenu(
    BuildContext context,
    List<ChannelAction> actions,
  ) {
    final menuConfig = widget.page.config.longPressMenuConfig;
    final resolvedMenuPadding = menuConfig.padding.resolve(
      Directionality.of(context),
    );
    final actionStyle =
        menuConfig.actionTextStyle ??
        const TextStyle(fontSize: 14, color: Color(0xFF111111));
    return showMenu<ChannelActionType>(
      context: context,
      position: _menuPositionFor(context),
      menuPadding: EdgeInsets.zero,
      elevation: 8,
      color: menuConfig.backgroundColor ?? Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x33000000),
      shape:
          menuConfig.shape ??
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      constraints: BoxConstraints(
        minWidth: menuConfig.width,
        maxWidth: menuConfig.width,
      ),
      items: [
        PopupMenuItem<ChannelActionType>(
          enabled: false,
          height: resolvedMenuPadding.vertical / 2,
          padding: EdgeInsets.zero,
          child: const SizedBox.shrink(),
        ),
        for (final action in actions)
          PopupMenuItem<ChannelActionType>(
            value: action.type,
            height: menuConfig.itemHeight,
            padding: EdgeInsets.zero,
            child: Container(
              padding: menuConfig.itemPadding,
              margin: menuConfig.itemMargin,
              child: Row(
                children: [
                  ChatUIAsset.image(
                    _actionIconAsset(action.type),
                    width: menuConfig.iconSize,
                    height: menuConfig.iconSize,
                    color: menuConfig.iconColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: action.destructive
                          ? menuConfig.destructiveTextStyle ?? actionStyle
                          : actionStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        PopupMenuItem<ChannelActionType>(
          enabled: false,
          height: resolvedMenuPadding.vertical / 2,
          padding: EdgeInsets.zero,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }

  RelativeRect _menuPositionFor(BuildContext context) {
    final renderObject = context.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (renderObject is! RenderBox || overlay is! RenderBox) {
      return RelativeRect.fill;
    }
    final offset = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
      ancestor: overlay,
    );
    return RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy);
  }

  String _actionIconAsset(ChannelActionType action) {
    return switch (action) {
      ChannelActionType.pin => 'NexconnLightIcon/Pin.png',
      ChannelActionType.unpin => 'NexconnLightIcon/unpin.png',
      ChannelActionType.delete => 'NexconnLightIcon/Delete.png',
      ChannelActionType.mute => 'NexconnLightIcon/Do-not-disturb-1.png',
      ChannelActionType.unmute => 'NexconnLightIcon/allow_noti.png',
    };
  }

  String _highlightKey(BaseChannel channel, int index) {
    return '${channel.channelType.name}:${channel.channelId}:$index';
  }

  void _clearHighlightedChannel(String highlightKey) {
    if (!mounted || _highlightedChannelKey != highlightKey) {
      return;
    }
    setState(() {
      _highlightedChannelKey = null;
    });
  }

  Future<void> _runChannelAction(
    BuildContext context,
    BaseChannel channel,
    ChannelActionType action,
  ) async {
    if (widget.page.onChannelAction != null) {
      await widget.page.onChannelAction!(context, channel, action);
      return;
    }
    final provider = context.read<ChannelProvider>();
    final error = switch (action) {
      ChannelActionType.pin => await provider.pinChannel(channel),
      ChannelActionType.unpin => await provider.unpinChannel(channel),
      ChannelActionType.mute => await provider.muteChannel(channel),
      ChannelActionType.unmute => await provider.unmuteChannel(channel),
      ChannelActionType.delete => await provider.deleteChannel(channel),
    };
    if (!context.mounted || error == null || error.isSuccess) {
      return;
    }
    final l10n = context.chatUIL10n;
    final message = error.message ?? error.reason ?? l10n.channelActionFailed;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _empty(BuildContext context, ChannelProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_showsNetworkTip(provider)) const _NetworkTip(),
          if (widget.page.headerBuilder != null)
            widget.page.headerBuilder!(context),
          if (widget.page.config.listConfig.showSearchBar)
            _SearchBar(onTap: widget.page.onSearchTap),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child:
                widget.page.emptyBuilder?.call(context) ??
                _ChannelEmptyState(
                  text:
                      widget.page.config.listConfig.emptyText ??
                      context.chatUIL10n.channelListEmpty,
                ),
          ),
          if (widget.page.footerBuilder != null)
            widget.page.footerBuilder!(context),
        ],
      ),
    );
  }

  Widget _loading(BuildContext context, ChannelProvider provider) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return RefreshIndicator(
      onRefresh: provider.reload,
      child: ListView(
        key: _loadingListKey,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_showsNetworkTip(provider)) const _NetworkTip(),
          if (widget.page.headerBuilder != null)
            widget.page.headerBuilder!(context),
          if (widget.page.config.listConfig.showSearchBar)
            _SearchBar(onTap: widget.page.onSearchTap),
          for (var i = 0; i < _loadingPlaceholderCount; i++)
            _ChannelLoadingPlaceholder(
              theme: theme,
              config: widget.page.config.itemConfig,
            ),
          _loadMoreFooter(provider),
          if (widget.page.footerBuilder != null)
            widget.page.footerBuilder!(context),
        ],
      ),
    );
  }

  Widget _loadMoreFooter(ChannelProvider provider) {
    if (!provider.isFetching && !provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox.shrink(),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          key: _loadingMoreIndicatorKey,
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }

  bool _isOffline(ConnectionStatus status) {
    return status == ConnectionStatus.networkUnavailable ||
        status == ConnectionStatus.unconnected ||
        status == ConnectionStatus.suspend ||
        status == ConnectionStatus.timeout;
  }
}

class _ChannelDivider extends StatelessWidget {
  final ChannelItemConfig config;

  const _ChannelDivider({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return Divider(
      indent: config.dividerIndent,
      endIndent: config.dividerEndIndent,
      height: config.dividerHeight,
      color: config.dividerColor ?? _defaultDividerColor(theme),
    );
  }

  Color _defaultDividerColor(NexconnThemeTokens theme) {
    return theme.brightness == Brightness.light
        ? theme.panelColor
        : theme.surfaceColor;
  }
}

class _ChannelEmptyState extends StatelessWidget {
  final String text;

  const _ChannelEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/Chat.png',
            width: 48,
            height: 48,
            color: const Color(0xFFD7D7D7),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: TextStyle(
              fontSize: convoLastFontSize,
              color: NexconnThemeProvider.resolveTokens(
                context,
              ).secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelLoadingPlaceholder extends StatelessWidget {
  final NexconnThemeTokens theme;
  final ChannelItemConfig config;

  const _ChannelLoadingPlaceholder({required this.theme, required this.config});

  @override
  Widget build(BuildContext context) {
    final lineColor = theme.brightness == Brightness.light
        ? const Color(0xFFE6E6E6)
        : theme.surfaceColor;
    final mutedColor = theme.brightness == Brightness.light
        ? const Color(0xFFF0F0F0)
        : theme.panelColor;
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mutedColor,
                    borderRadius: BorderRadius.circular(config.avatarRadius),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        height: 12,
                        decoration: BoxDecoration(
                          color: mutedColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 36,
                  height: 12,
                  decoration: BoxDecoration(
                    color: mutedColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          _ChannelDivider(config: config),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ChannelSearchTap? onTap;

  const _SearchBar({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: onTap == null ? null : () => onTap!(context),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Center(
            child: TextField(
              enabled: false,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: context.chatUIL10n.channelSearchPlaceholder,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkTip extends StatelessWidget {
  const _NetworkTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      color: const Color(0x33FD4C4C),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChatUIAsset.image(
              'NexconnLightIcon/Attention.png',
              width: 18,
              height: 18,
              color: const Color(0xFFFF3B30),
            ),
            const SizedBox(width: 4.0),
            Text(
              context.chatUIL10n.channelNetworkUnavailable,
              style: TextStyle(
                color: NexconnThemeProvider.resolveTokens(
                  context,
                ).primaryTextColor,
                fontSize: convoAuxiliaryFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
