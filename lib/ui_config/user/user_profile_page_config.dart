import 'package:flutter/material.dart';

import '../../models/nexconn_user_profile.dart';
import 'user_profile_provider_config.dart';

/// Handles an action from NexconnUserProfilePage.
typedef NexconnUserProfileActionCallback =
    Future<void> Function(BuildContext context, NexconnUserProfile profile);

/// One action displayed on NexconnUserProfilePage.
class NexconnUserProfileActionConfig {
  final bool showActions;
  final bool showStartChat;
  final bool showAddFriend;
  final bool showDeleteFriend;
  final bool showUpdateRemark;
  final String? startChatText;
  final String? addFriendText;
  final String? deleteFriendText;
  final String? updateRemarkText;
  final String? unsupportedText;
  final Color? deleteFriendColor;
  final NexconnUserProfileActionCallback? onStartChat;
  final NexconnUserProfileActionCallback? onAddFriend;
  final NexconnUserProfileActionCallback? onDeleteFriend;
  final NexconnUserProfileActionCallback? onUpdateRemark;
  final Widget Function(BuildContext context, NexconnUserProfile profile)?
  actionBuilder;

  const NexconnUserProfileActionConfig({
    this.showActions = true,
    this.showStartChat = true,
    this.showAddFriend = true,
    this.showDeleteFriend = true,
    this.showUpdateRemark = true,
    this.startChatText,
    this.addFriendText,
    this.deleteFriendText,
    this.updateRemarkText,
    this.unsupportedText,
    this.deleteFriendColor,
    this.onStartChat,
    this.onAddFriend,
    this.onDeleteFriend,
    this.onUpdateRemark,
    this.actionBuilder,
  });
}

/// Display configuration for the Nexconn user profile page.
class NexconnUserProfilePageConfig {
  final String? title;
  final Color? backgroundColor;
  final Color? cardColor;
  final TextStyle? titleTextStyle;
  final TextStyle? labelTextStyle;
  final TextStyle? valueTextStyle;
  final double avatarSize;
  final bool showUserId;
  final bool showUniqueId;
  final bool showEmail;
  final bool showBirthday;
  final bool showGender;
  final bool showLocation;
  final bool showRole;
  final bool showLevel;
  final bool showExtProfile;
  final String? emptyText;
  final String? errorText;
  final String? loadingText;
  final String? refreshTooltip;
  final NexconnUserProfileActionConfig actionConfig;
  final NexconnUserProfileProviderConfig providerConfig;

  const NexconnUserProfilePageConfig({
    this.title,
    this.backgroundColor,
    this.cardColor,
    this.titleTextStyle,
    this.labelTextStyle,
    this.valueTextStyle,
    this.avatarSize = 72,
    this.showUserId = true,
    this.showUniqueId = true,
    this.showEmail = true,
    this.showBirthday = true,
    this.showGender = true,
    this.showLocation = true,
    this.showRole = true,
    this.showLevel = true,
    this.showExtProfile = true,
    this.emptyText,
    this.errorText,
    this.loadingText,
    this.refreshTooltip,
    this.actionConfig = const NexconnUserProfileActionConfig(),
    this.providerConfig = const NexconnUserProfileProviderConfig(),
  });
}
