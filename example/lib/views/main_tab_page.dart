import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/material.dart';

import '../providers/login_provider.dart';
import '../providers/user_info_provider.dart';
import 'channel_demo_page.dart';
import 'settings_page.dart';

class MainTabPage extends StatefulWidget {
  final LoginProvider loginProvider;
  final EngineProvider engineProvider;
  final NexconnThemeProvider themeProvider;
  final UserInfoProvider userInfoProvider;

  const MainTabPage({
    super.key,
    required this.loginProvider,
    required this.engineProvider,
    required this.themeProvider,
    required this.userInfoProvider,
  });

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const ChannelDemoPage(),
      SettingsPage(
        loginProvider: widget.loginProvider,
        engineProvider: widget.engineProvider,
        themeProvider: widget.themeProvider,
        userInfoProvider: widget.userInfoProvider,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeProvider.tokens;
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: widget.themeProvider.mode == NexconnThemeMode.light
            ? theme.panelColor
            : theme.pageBackgroundColor,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: theme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
