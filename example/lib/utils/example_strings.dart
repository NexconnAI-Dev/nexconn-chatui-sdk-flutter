import 'package:flutter/widgets.dart';

class ExampleStrings {
  final Locale locale;

  const ExampleStrings(this.locale);

  static ExampleStrings of(BuildContext context) {
    return ExampleStrings(Localizations.localeOf(context));
  }

  bool get _zh => locale.languageCode == 'zh';

  String get appTitle => _zh ? 'Nexconn Chat UI 示例' : 'Nexconn Chat UI Example';
  String get loginSubtitle => _zh
      ? '使用内置测试账号连接 Nexconn SDK。'
      : 'Connect to Nexconn SDK with built-in test accounts.';
  String get appKeyLabel => _zh ? 'App Key' : 'App Key';
  String get tokenLabel => _zh ? 'Token / 账号序号' : 'Token / Account Index';
  String get tokenHint =>
      _zh ? '填 1 / 2 / 3 或完整 Token' : 'Enter 1 / 2 / 3 or a full token';
  String get connect => _zh ? '登录并连接' : 'Sign in and connect';
  String get missingToken =>
      _zh ? '请填写 Token 或账号序号。' : 'Enter a token or account index.';
  String connectFailed(int code) =>
      _zh ? '连接失败：$code' : 'Connect failed: $code';
  String get chats => _zh ? '频道' : 'Chats';
  String get settings => _zh ? '设置' : 'Settings';
  String get friends => _zh ? '好友' : 'Friends';
  String get groups => _zh ? '群组' : 'Groups';
  String get currentUser => _zh ? '当前用户' : 'Current User';
  String get onlineMode => _zh ? '真实 SDK 连接' : 'Live SDK connection';
  String get connectionStatus => _zh ? '连接状态' : 'Connection Status';
  String get themeSettings => _zh ? '主题设置' : 'Theme Settings';
  String get createGroup => _zh ? '创建群组' : 'Create Group';
  String get clearCache => _zh ? '清理缓存' : 'Clear Cache';
  String get clearCacheDone => _zh ? '缓存已清理' : 'Cache cleared';
  String get signOut => _zh ? '退出登录' : 'Sign Out';
  String get lightTheme => _zh ? '浅色主题' : 'Light Theme';
  String get darkTheme => _zh ? '深色主题' : 'Dark Theme';
  String get themePreview => _zh ? '主题预览' : 'Theme Preview';
  String get incomingBubble => _zh ? '对方消息气泡' : 'Incoming bubble';
  String get outgoingBubble => _zh ? '我的消息气泡' : 'Outgoing bubble';
  String get readStatus => _zh ? '已读状态' : 'Read status';
  String connectionStatusName(String status) {
    switch (status) {
      case 'connected':
        return _zh ? '已连接' : 'Connected';
      case 'connecting':
        return _zh ? '连接中' : 'Connecting';
      case 'disconnected':
        return _zh ? '已断开' : 'Disconnected';
      case 'tokenIncorrect':
        return _zh ? 'Token 错误' : 'Token incorrect';
      case 'networkUnavailable':
        return _zh ? '网络不可用' : 'Network unavailable';
      default:
        return status;
    }
  }

  String accountLabel(String index) => _zh ? '账号 $index' : 'Account $index';
}
