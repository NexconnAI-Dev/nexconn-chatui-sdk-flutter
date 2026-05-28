import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

class ThemeSettingsPage extends StatefulWidget {
  final NexconnThemeProvider themeProvider;

  const ThemeSettingsPage({super.key, required this.themeProvider});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  NexconnThemeProvider get _themeProvider => widget.themeProvider;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, _) {
        final tokens = _themeProvider.tokens;
        return Scaffold(
          appBar: AppBar(
            title: const Text('主题设置'),
            backgroundColor: tokens.surfaceColor,
            foregroundColor: tokens.primaryTextColor,
          ),
          backgroundColor: tokens.pageBackgroundColor,
          body: ListView(
            children: [
              _themeTile(
                title: '浅色模式',
                subtitle: '明亮界面',
                icon: Icons.light_mode,
                mode: NexconnThemeMode.light,
              ),
              Divider(height: 1, color: tokens.dividerColor),
              _themeTile(
                title: '深色模式',
                subtitle: '暗黑界面',
                icon: Icons.dark_mode,
                mode: NexconnThemeMode.dark,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '当前模式：${_getThemeName(_themeProvider.mode)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tokens.primaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: tokens.surfaceColor,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: tokens.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '主题预览',
                        style: TextStyle(
                          color: tokens.primaryTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: tokens.surfaceMutedColor,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          '用户消息气泡',
                          style: TextStyle(
                            color: tokens.primaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: tokens.primaryColor,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Text(
                              '我的消息气泡',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.done_all, color: tokens.successColor),
                          const SizedBox(width: 8),
                          Text(
                            '已读状态',
                            style: TextStyle(
                              color: tokens.successColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: tokens.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '通知提醒',
                            style: TextStyle(
                              color: tokens.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '辅助文本示例',
                        style: TextStyle(
                          color: tokens.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '提示文本示例',
                        style: TextStyle(
                          color: tokens.secondaryTextColor.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('应用更改并返回'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _themeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required NexconnThemeMode mode,
  }) {
    final tokens = _themeProvider.tokens;
    return ListTile(
      title: Text(title, style: TextStyle(color: tokens.primaryTextColor)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: tokens.secondaryTextColor),
      ),
      leading: Icon(icon, color: tokens.primaryColor),
      trailing: Icon(
        _themeProvider.mode == mode
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        color: _themeProvider.mode == mode
            ? tokens.primaryColor
            : tokens.dividerColor,
      ),
      onTap: () => _changeTheme(mode),
    );
  }

  void _changeTheme(NexconnThemeMode newTheme) {
    if (newTheme == _themeProvider.mode) return;
    _themeProvider.setMode(newTheme);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换到${_getThemeName(newTheme)}主题'),
        backgroundColor: _themeProvider.tokens.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getThemeName(NexconnThemeMode theme) {
    switch (theme) {
      case NexconnThemeMode.light:
        return '浅色';
      case NexconnThemeMode.dark:
        return '深色';
      case NexconnThemeMode.custom:
        return '默认';
    }
  }
}
