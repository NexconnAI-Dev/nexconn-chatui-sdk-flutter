import 'package:flutter/material.dart';

import '../providers/login_provider.dart';

class SetupPage extends StatefulWidget {
  final LoginProvider loginProvider;

  const SetupPage({super.key, required this.loginProvider});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final TextEditingController _appKeyController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _naviServerController = TextEditingController();
  final TextEditingController _fileServerController = TextEditingController();
  final TextEditingController _statisticServerController =
      TextEditingController();

  bool _isConnecting = false;

  @override
  void dispose() {
    _appKeyController.dispose();
    _tokenController.dispose();
    _naviServerController.dispose();
    _fileServerController.dispose();
    _statisticServerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = _SetupStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.title), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.welcomeTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.welcomeBody,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.step1,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      strings.step2,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      strings.step3,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _appKeyController,
              decoration: InputDecoration(
                labelText: strings.appKeyLabel,
                hintText: strings.appKeyHint,
                border: const OutlineInputBorder(),
                helperText: strings.appKeyHelper,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: strings.tokenLabel,
                hintText: strings.tokenHint,
                border: const OutlineInputBorder(),
                helperText: strings.tokenHelper,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: Text(strings.advancedOptions),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      TextField(
                        controller: _naviServerController,
                        decoration: InputDecoration(
                          labelText: strings.naviServerLabel,
                          hintText: strings.optionalServerHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fileServerController,
                        decoration: InputDecoration(
                          labelText: strings.fileServerLabel,
                          hintText: strings.optionalServerHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _statisticServerController,
                        decoration: InputDecoration(
                          labelText: strings.statisticServerLabel,
                          hintText: strings.optionalServerHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isConnecting ? null : _connect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isConnecting
                  ? const CircularProgressIndicator()
                  : Text(
                      strings.connectButton,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final strings = _SetupStrings.of(context);
    final appKey = _appKeyController.text.trim();
    final token = _tokenController.text.trim();

    if (appKey.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.missingCredentials)));
      return;
    }

    setState(() => _isConnecting = true);
    try {
      await widget.loginProvider.loginWithCredentials(
        appKey: appKey,
        token: token,
        naviServer: _naviServerController.text,
        fileServer: _fileServerController.text,
        statisticServer: _statisticServerController.text,
      );
      if (!mounted) return;
      if (widget.loginProvider.isLoggedIn) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.connectSuccess)));
        Navigator.pushReplacementNamed(context, '/main_tab');
      } else {
        final errorCode = widget.loginProvider.errorCode;
        final message = widget.loginProvider.errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? strings.connectFailed(errorCode ?? -1)),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.connectError(error))));
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }
}

class _SetupStrings {
  final Locale locale;

  const _SetupStrings(this.locale);

  static _SetupStrings of(BuildContext context) {
    return _SetupStrings(Localizations.localeOf(context));
  }

  bool get _zh => locale.languageCode == 'zh';

  String get title => _zh ? 'Nexconn Chat UI Demo' : 'Nexconn Chat UI Demo';
  String get welcomeTitle =>
      _zh ? '欢迎使用 Nexconn Chat UI' : 'Welcome to Nexconn Chat UI';
  String get welcomeBody => _zh
      ? '这是一个简单的对外 Demo，展示如何快速集成 Chat UI。'
      : 'A simple public demo showing how to integrate Chat UI quickly.';
  String get step1 => _zh
      ? '1. 输入 App Key 和 Token，点击连接服务器'
      : '1. Enter App Key and token, then connect';
  String get step2 =>
      _zh ? '2. 连接成功后自动进入频道列表' : '2. After connecting, the channel list opens';
  String get step3 => _zh ? '3. 点击频道进入聊天页面' : '3. Tap a channel to open chat';
  String get appKeyLabel => _zh ? 'App Key *' : 'App Key *';
  String get appKeyHint =>
      _zh ? '请输入您的 Nexconn App Key' : 'Enter your Nexconn App Key';
  String get appKeyHelper =>
      _zh ? '从 Nexconn 控制台获取' : 'Get it from the Nexconn console';
  String get tokenLabel => _zh ? 'Token *' : 'Token *';
  String get tokenHint => _zh ? '请输入用户 Token' : 'Enter a user token';
  String get tokenHelper => _zh ? '通过您的业务服务端获取' : 'Get it from your app server';
  String get advancedOptions =>
      _zh ? '高级选项（可选）' : 'Advanced options (optional)';
  String get naviServerLabel => _zh ? '导航服务器地址' : 'Navigation server';
  String get fileServerLabel => _zh ? '文件服务器地址' : 'File server';
  String get statisticServerLabel => _zh ? '统计服务器地址' : 'Statistic server';
  String get optionalServerHint =>
      _zh ? '留空使用默认地址' : 'Leave blank to use default';
  String get connectButton => _zh ? '连接 Nexconn 服务器' : 'Connect to Nexconn';
  String get missingCredentials =>
      _zh ? '请输入 App Key 和 Token' : 'Enter App Key and token';
  String get connectSuccess => _zh ? '连接成功！' : 'Connected!';
  String connectFailed(int code) =>
      _zh ? '连接失败，错误码：$code' : 'Connect failed: $code';
  String connectError(Object error) =>
      _zh ? '连接出错：$error' : 'Connect error: $error';
}
