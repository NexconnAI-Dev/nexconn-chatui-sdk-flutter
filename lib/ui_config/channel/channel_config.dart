import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../models/chat_profile_info.dart';
import '../../utils/constants.dart';
import '../../providers/channel_provider.dart';
import 'channel_app_bar_config.dart';

/// Avatar shape used by channel list items.
enum ChannelAvatarShape { circle, roundedRectangle, rectangle }

/// Read/send status rendered in a channel item.
enum ChannelReadStatus { sending, failed, sent, delivered, read }

/// Built-in channel action type for swipe and long-press menus.
enum ChannelActionType { pin, unpin, mute, unmute, delete }

/// Default behavior when a channel item is tapped.
enum ChannelItemTapBehavior { openChatPage, none }

/// Display name and avatar data for a channel row.
class ChannelDisplayProfile {
  /// Name displayed as the channel title.
  final String? displayName;

  /// Remote avatar URL displayed for the channel.
  final String? avatarUrl;

  /// Packaged asset name used when [avatarUrl] is not provided.
  final String? avatarAssetName;

  /// Custom fallback widget used when no image source is available.
  final Widget? avatarFallback;

  const ChannelDisplayProfile({
    this.displayName,
    this.avatarUrl,
    this.avatarAssetName,
    this.avatarFallback,
  });
}

/// Resolves display profile data for a channel row.
typedef ChannelDisplayProfileResolver =
    FutureOr<ChannelDisplayProfile?> Function(
      BuildContext context,
      BaseChannel channel,
    );

/// Visible channel action shown in menus or swipe actions.
class ChannelAction {
  /// Built-in action behavior to run.
  final ChannelActionType type;

  /// Text shown for the action.
  final String label;

  /// Icon shown for the action.
  final IconData icon;

  /// Whether the action should be styled as destructive.
  final bool destructive;

  const ChannelAction({
    required this.type,
    required this.label,
    required this.icon,
    this.destructive = false,
  });
}

/// Appearance and behavior of the channel long-press menu.
class ChannelLongPressMenuConfig {
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final double width;
  final double iconSize;
  final Color? iconColor;
  final EdgeInsetsGeometry padding;
  final double itemHeight;
  final EdgeInsetsGeometry itemPadding;
  final EdgeInsetsGeometry itemMargin;
  final TextStyle? actionTextStyle;
  final TextStyle? destructiveTextStyle;
  final String? cancelText;
  final bool showCancel;

  const ChannelLongPressMenuConfig({
    this.backgroundColor,
    this.shape,
    this.width = 160,
    this.iconSize = 20,
    this.iconColor = const Color(0xFF111111),
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.itemHeight = 34,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    this.itemMargin = const EdgeInsets.symmetric(vertical: 5),
    this.actionTextStyle,
    this.destructiveTextStyle,
    this.cancelText,
    this.showCancel = true,
  }) : assert(width > 0),
       assert(iconSize > 0),
       assert(itemHeight > 0);
}

/// Configuration for channel row swipe actions.
class ChannelSwipeActionsConfig {
  final bool enabled;
  final double actionWidth;
  final double revealThreshold;
  final List<ChannelActionType> actions;
  final Map<ChannelActionType, String> labels;
  final Map<ChannelActionType, IconData> icons;
  final Map<ChannelActionType, Color> backgroundColors;
  final Color foregroundColor;

  const ChannelSwipeActionsConfig({
    this.enabled = true,
    this.actionWidth = 76,
    this.revealThreshold = 0.35,
    this.actions = const [ChannelActionType.pin, ChannelActionType.delete],
    this.labels = const {
      ChannelActionType.pin: 'Pin',
      ChannelActionType.unpin: 'Unpin',
      ChannelActionType.mute: 'Mute',
      ChannelActionType.unmute: 'Unmute',
      ChannelActionType.delete: 'Delete',
    },
    this.icons = const {
      ChannelActionType.pin: Icons.push_pin,
      ChannelActionType.unpin: Icons.push_pin_outlined,
      ChannelActionType.mute: Icons.notifications_off_outlined,
      ChannelActionType.unmute: Icons.notifications_active_outlined,
      ChannelActionType.delete: Icons.delete_outline,
    },
    this.backgroundColors = const {
      ChannelActionType.pin: Color(0xFF147BFF),
      ChannelActionType.unpin: Color(0xFF8E8E93),
      ChannelActionType.mute: Color(0xFF34C759),
      ChannelActionType.unmute: Color(0xFF34C759),
      ChannelActionType.delete: Color(0xFFFF3B30),
    },
    this.foregroundColor = Colors.white,
  }) : assert(actionWidth > 0),
       assert(revealThreshold >= 0 && revealThreshold <= 1);
}

/// Supplies online status for a direct channel.
typedef ChannelOnlineStatusProvider =
    ChannelOnlineStatus? Function(BaseChannel channel);

/// Builds the direct-channel online status indicator.
typedef ChannelOnlineStatusBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelOnlineStatus status,
    );

/// Builds the channel read/send status indicator.
typedef ChannelReadStatusBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelReadStatus status,
    );

/// Builds the channel notification-level indicator.
typedef ChannelNotificationLevelBuilder =
    Widget? Function(
      BuildContext context,
      BaseChannel channel,
      ChannelNoDisturbLevel? level,
    );

/// Builds the avatar area for a channel row.
typedef ChannelItemAvatarBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelDisplayProfile? displayProfile,
      ChannelItemConfig config,
    );

/// Builds the title area for a channel row.
typedef ChannelItemTitleBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelDisplayProfile? displayProfile,
      ChannelItemConfig config,
    );

/// Builds the last-message summary for a channel row.
typedef ChannelItemLastMessageBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelItemConfig config,
    );

/// Builds the timestamp area for a channel row.
typedef ChannelItemTimeBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      ChannelItemConfig config,
    );

/// Builds the unread badge for a channel row.
typedef ChannelItemUnreadBadgeBuilder =
    Widget Function(
      BuildContext context,
      BaseChannel channel,
      int unreadCount,
      ChannelItemConfig config,
    );

/// Returns available actions for a channel.
typedef ChannelActionsBuilder =
    List<ChannelAction> Function(BaseChannel channel);

/// Runs a selected channel action.
typedef ChannelActionHandler =
    Future<void> Function(
      BuildContext context,
      BaseChannel channel,
      ChannelActionType action,
    );

/// Shows a custom channel action menu and returns the selected action.
typedef ChannelLongPressMenuBuilder =
    Future<ChannelActionType?> Function(
      BuildContext context,
      BaseChannel channel,
      List<ChannelAction> actions,
    );

/// Top-level configuration for ChannelPage.
class ChannelConfig {
  /// Top bar configuration.
  final ChannelAppBarConfig appBarConfig;

  /// List loading and empty/search configuration.
  final ChannelListConfig listConfig;

  /// Row display and interaction configuration.
  final ChannelItemConfig itemConfig;

  /// Shared profile resolver used by channel rows and default chat navigation.
  ///
  /// [ChannelItemConfig.displayProfiles] and
  /// [ChannelItemConfig.displayProfileResolver] keep higher priority for
  /// channel rows. When this resolver is provided, the default ChannelPage
  /// chat navigation also passes it through to ChatPage.
  final ChatProfileProvider? profileProvider;

  /// Long-press action menu configuration.
  final ChannelLongPressMenuConfig longPressMenuConfig;

  const ChannelConfig({
    this.appBarConfig = const ChannelAppBarConfig(),
    this.listConfig = const ChannelListConfig(),
    this.itemConfig = const ChannelItemConfig(),
    this.profileProvider,
    this.longPressMenuConfig = const ChannelLongPressMenuConfig(),
  });
}

/// Configuration for channel list loading and empty/search UI.
class ChannelListConfig {
  /// Whether ChannelPage shows the built-in search entry.
  final bool showSearchBar;

  /// Whether ChannelPage shows connection status tips.
  final bool showNetworkStatusTip;

  /// Empty-state text override.
  final String? emptyText;

  /// List background color override.
  final Color? backgroundColor;

  /// Channel types requested from the SDK query.
  final List<ChannelType> channelTypes;

  /// SDK query page size, constrained to 1 through 50.
  final int pageSize;

  /// Default tap behavior for channel rows.
  final ChannelItemTapBehavior itemTapBehavior;

  const ChannelListConfig({
    this.showSearchBar = false,
    this.showNetworkStatusTip = true,
    this.emptyText,
    this.backgroundColor,
    this.pageSize = defaultChannelPageSize,
    this.itemTapBehavior = ChannelItemTapBehavior.openChatPage,
    this.channelTypes = const [
      ChannelType.direct,
      ChannelType.group,
      ChannelType.system,
      ChannelType.open,
      ChannelType.community,
    ],
  }) : assert(
         pageSize > 0 && pageSize <= 50,
         'ChannelListConfig.pageSize must satisfy 0 < pageSize <= 50.',
       );
}

/// Configuration for ChannelItem display and interaction.
class ChannelItemConfig {
  /// Whether unread count is displayed.
  final bool showUnreadBadge;

  /// Whether the last message summary is displayed.
  final bool showLastMessage;

  /// Whether the latest message time is displayed.
  final bool showTime;

  /// Whether pinned channels show a pin indicator.
  final bool showPinnedIndicator;

  /// Whether direct channels show online status.
  final bool showDirectChannelOnlineStatus;

  /// Whether read/send status is displayed for outgoing latest messages.
  final bool showReadStatus;

  /// Whether notification-level state is displayed.
  final bool showNotificationLevelIndicator;

  /// Avatar corner radius or circular radius.
  final double avatarRadius;

  /// Avatar shape used by the default row.
  final ChannelAvatarShape avatarShape;

  /// Optional online status source for direct channels.
  final ChannelOnlineStatusProvider? onlineStatusProvider;
  final ChannelOnlineStatusBuilder? onlineStatusBuilder;
  final ChannelReadStatusBuilder? readStatusBuilder;
  final ChannelNotificationLevelBuilder? notificationLevelBuilder;
  final ChannelItemAvatarBuilder? avatarBuilder;
  final ChannelItemTitleBuilder? titleBuilder;
  final ChannelItemLastMessageBuilder? lastMessageBuilder;
  final ChannelItemTimeBuilder? timeBuilder;
  final ChannelItemUnreadBadgeBuilder? unreadBadgeBuilder;
  final TextStyle? titleStyle;
  final TextStyle? lastMessageStyle;
  final TextStyle? timeStyle;
  final Color? dividerColor;
  final double dividerIndent;
  final double dividerEndIndent;
  final double dividerHeight;
  final Color? backgroundColor;
  final Color? pinnedBackgroundColor;
  final bool useDefaultAvatarAsset;

  /// Async resolver for display profile data.
  final ChannelDisplayProfileResolver? displayProfileResolver;

  /// Static display profile overrides keyed by channel id.
  final Map<String, ChannelDisplayProfile> displayProfiles;
  final String? directChannelAvatarAssetName;
  final String? groupChannelAvatarAssetName;
  final String? systemChannelAvatarAssetName;
  final Color? longPressBackgroundColor;

  /// Swipe action configuration for the row.
  final ChannelSwipeActionsConfig swipeActionsConfig;

  const ChannelItemConfig({
    this.showUnreadBadge = true,
    this.showLastMessage = true,
    this.showTime = true,
    this.showPinnedIndicator = false,
    this.showDirectChannelOnlineStatus = false,
    this.showReadStatus = false,
    this.showNotificationLevelIndicator = true,
    this.avatarRadius = 12,
    this.avatarShape = ChannelAvatarShape.roundedRectangle,
    this.onlineStatusProvider,
    this.onlineStatusBuilder,
    this.readStatusBuilder,
    this.notificationLevelBuilder,
    this.avatarBuilder,
    this.titleBuilder,
    this.lastMessageBuilder,
    this.timeBuilder,
    this.unreadBadgeBuilder,
    this.titleStyle,
    this.lastMessageStyle,
    this.timeStyle,
    this.dividerColor,
    this.dividerIndent = 0,
    this.dividerEndIndent = 0,
    this.dividerHeight = 1,
    this.backgroundColor,
    this.pinnedBackgroundColor,
    this.useDefaultAvatarAsset = true,
    this.displayProfileResolver,
    this.displayProfiles = const {},
    this.directChannelAvatarAssetName,
    this.groupChannelAvatarAssetName,
    this.systemChannelAvatarAssetName,
    this.longPressBackgroundColor = const Color(0xFFDBE0EF),
    this.swipeActionsConfig = const ChannelSwipeActionsConfig(),
  });
}

/// Handles taps on the channel search entry.
typedef ChannelSearchTap = void Function(BuildContext context);
