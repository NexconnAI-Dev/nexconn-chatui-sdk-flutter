import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

class DemoChannelListPage extends StatelessWidget {
  final EngineProvider engineProvider;

  const DemoChannelListPage({super.key, required this.engineProvider});

  @override
  Widget build(BuildContext context) {
    final strings = _ChannelListStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.title),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context, strings),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmDisconnect(context, strings),
          ),
        ],
      ),
      body: ChannelPage(
        onItemTap: (channel, _, context) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ChatPage(channel: channel)),
          );
        },
      ),
    );
  }

  void _showInfo(BuildContext context, _ChannelListStrings strings) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.aboutTitle),
        content: Text(strings.aboutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.chatUIL10n.commonConfirm),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, _ChannelListStrings strings) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.disconnectTitle),
        content: Text(strings.disconnectBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.chatUIL10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              await engineProvider.disconnect();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
            child: Text(context.chatUIL10n.commonConfirm),
          ),
        ],
      ),
    );
  }
}

class _ChannelListStrings {
  final Locale locale;

  const _ChannelListStrings(this.locale);

  static _ChannelListStrings of(BuildContext context) {
    return _ChannelListStrings(Localizations.localeOf(context));
  }

  bool get _zh => locale.languageCode == 'zh';

  String get title => _zh ? '频道列表' : 'Channel List';
  String get aboutTitle => _zh ? '关于频道列表' : 'About Channel List';
  String get aboutBody => _zh
      ? '这是 Nexconn Chat UI 提供的频道列表页面。\n\n连接成功后会显示频道列表，点击频道可进入聊天页面。\n\n主要功能：\n• 显示频道\n• 点击频道进入聊天\n• 支持删除、置顶等操作\n• 显示未读消息数'
      : 'This is the channel list page provided by Nexconn Chat UI.\n\nAfter connecting, channels appear here. Tap a channel to open chat.\n\nFeatures:\n• Show channels\n• Open chat on tap\n• Delete and pin channels\n• Show unread counts';
  String get disconnectTitle => _zh ? '断开连接' : 'Disconnect';
  String get disconnectBody =>
      _zh ? '确定要断开与 Nexconn 服务器的连接吗？' : 'Disconnect from the Nexconn server?';
}
