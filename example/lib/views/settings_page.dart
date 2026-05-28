import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

import '../providers/login_provider.dart';
import '../providers/user_info_provider.dart';
import '../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  final LoginProvider loginProvider;
  final EngineProvider engineProvider;
  final NexconnThemeProvider themeProvider;
  final UserInfoProvider userInfoProvider;

  const SettingsPage({
    super.key,
    required this.loginProvider,
    required this.engineProvider,
    required this.themeProvider,
    required this.userInfoProvider,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationEnabled = true;

  @override
  void initState() {
    super.initState();
    _notificationEnabled = widget.loginProvider.enableLocalNotification;
  }

  Future<void> _toggleNotification(bool value) async {
    widget.loginProvider.enableLocalNotification = value;
    setState(() => _notificationEnabled = value);
    await widget.engineProvider.setupLocalNotification(enable: value);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.engineProvider.currentUserId;
    final userInfo = widget.userInfoProvider.getUserInfo(currentUserId);

    return ListView(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _Avatar(url: userInfo?.avatarUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userInfo?.displayName ??
                          widget.loginProvider.currentNickname ??
                          '未知用户',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $currentUserId',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('消息通知'),
          trailing: Switch(
            value: _notificationEnabled,
            onChanged: _toggleNotification,
            activeThumbColor: Theme.of(context).primaryColor,
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('隐私设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(
            context,
            '/web',
            arguments: {'url': nexconnPrivacyPolicy, 'title': '隐私政策'},
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.color_lens),
          title: const Text('主题设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/theme_settings'),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.storage),
          title: const Text('清理缓存'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showClearCacheDialog,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('关于我们'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _showLogoutDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('退出登录'),
          ),
        ),
      ],
    );
  }

  Future<void> _showClearCacheDialog() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('确定要清理所有缓存数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.userInfoProvider.clearCache();
              if (!mounted) return;
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('缓存已清理')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final navigator = Navigator.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.loginProvider.logout();
              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil('/login', (_) => false);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;

  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    if (value != null && value.isNotEmpty) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return const ColoredBox(
      color: Color(0xFFF2F3F5),
      child: Icon(Icons.person, color: Colors.grey, size: 42),
    );
  }
}
