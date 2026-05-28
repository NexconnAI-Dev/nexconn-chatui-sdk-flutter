import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/channel_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../models/chat_profile_info.dart';
import '../../../ui_config/channel/channel_config.dart';
import '../../../utils/constants.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/message_content_util.dart';
import '../../../utils/time_util.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';

part 'layout/channel_item_layout.dart';
part 'avatar/channel_item_avatar.dart';
part 'avatar/channel_item_avatar_helpers.dart';
part 'status/channel_item_status.dart';
part 'actions/channel_swipe_action_host.dart';

/// Default row widget for one BaseChannel in ChannelPage.
class ChannelItem extends StatelessWidget {
  final BaseChannel channel;
  final int index;
  final ChannelItemConfig config;
  final ChannelListItemOnTap? onTap;
  final ChannelListItemOnTap? onLongPress;
  final ChannelListItemOnTap? onAvatarTap;
  final ChannelListItemOnTap? onAvatarLongPress;
  final ChannelActionHandler? onAction;
  final ChatProfileProvider? profileProvider;
  final bool highlighted;

  const ChannelItem({
    super.key,
    required this.channel,
    required this.index,
    required this.config,
    this.onTap,
    this.onLongPress,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.onAction,
    this.profileProvider,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final initialProfile = _profileFromConfig();
    final resolver = config.displayProfileResolver;
    if (resolver == null &&
        (initialProfile != null || profileProvider == null)) {
      return _buildItem(context, initialProfile);
    }
    if (resolver == null) {
      return FutureBuilder<ChannelDisplayProfile?>(
        initialData: initialProfile,
        future: _resolveSharedProfile(),
        builder: (context, snapshot) {
          return _buildItem(context, snapshot.data ?? initialProfile);
        },
      );
    }
    return FutureBuilder<ChannelDisplayProfile?>(
      initialData: initialProfile,
      future: Future.value(resolver(context, channel)),
      builder: (context, snapshot) {
        return _buildItem(context, snapshot.data ?? initialProfile);
      },
    );
  }

  Future<ChannelDisplayProfile?> _resolveSharedProfile() async {
    final profile = await profileProvider?.call(channel);
    if (profile == null) {
      return null;
    }
    return ChannelDisplayProfile(
      displayName: profile.name,
      avatarUrl: profile.portraitUri,
    );
  }
}
