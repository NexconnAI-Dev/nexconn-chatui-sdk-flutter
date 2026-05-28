import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_info_provider.dart';

class ChannelDemoPage extends StatelessWidget {
  final ChannelProvider? provider;

  const ChannelDemoPage({super.key, this.provider});

  @override
  Widget build(BuildContext context) {
    return ChannelPage(
      provider: provider,
      config: const ChannelConfig(
        itemConfig: ChannelItemConfig(
          displayProfileResolver: _resolveChannelProfile,
        ),
      ),
      onItemTap: (channel, _, context) {
        final provider = context.read<ChannelProvider>();
        provider.pushSelectedChannel(channel);
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {'channel': channel},
        ).whenComplete(() {
          provider.popSelectedChannel();
          return provider.reload();
        });
      },
    );
  }
}

Future<ChannelDisplayProfile?> _resolveChannelProfile(
  BuildContext context,
  BaseChannel channel,
) async {
  final userInfoProvider = context.read<UserInfoProvider>();
  final id = channel.channelId;
  if (channel.channelType == ChannelType.group) {
    final group = await userInfoProvider.getGroupInfoSync(id);
    return ChannelDisplayProfile(
      displayName: group?.groupName?.trim().isNotEmpty == true
          ? group!.groupName
          : id,
      avatarUrl: group?.avatarUrl,
    );
  }
  final user = await userInfoProvider.getUserInfoSync(id);
  return ChannelDisplayProfile(
    displayName: user?.name?.trim().isNotEmpty == true ? user!.name : id,
    avatarUrl: user?.avatarUrl,
  );
}
