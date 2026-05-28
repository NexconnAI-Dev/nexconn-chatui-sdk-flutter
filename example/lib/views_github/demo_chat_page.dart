import 'package:flutter/material.dart';

class DemoChatPage extends StatelessWidget {
  const DemoChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = _DemoChatStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.title),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.close),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          strings.aboutTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(strings.aboutBody),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.featuresTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: strings.features.map(Text.new).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.usageTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  strings.codeSample,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoChatStrings {
  final Locale locale;

  const _DemoChatStrings(this.locale);

  static _DemoChatStrings of(BuildContext context) {
    return _DemoChatStrings(Localizations.localeOf(context));
  }

  bool get _zh => locale.languageCode == 'zh';

  String get title => _zh ? '聊天页面说明' : 'Chat Page Guide';
  String get close => _zh ? '关闭' : 'Close';
  String get aboutTitle => _zh ? '关于聊天页面' : 'About Chat Page';
  String get aboutBody => _zh
      ? 'ChatPage 是 Nexconn Chat UI 提供的聊天页面组件。\n\n实际使用中通常从频道列表点击进入聊天页面，而不是单独设置参数。'
      : 'ChatPage is the chat page component provided by Nexconn Chat UI.\n\nIn real apps, open it from the channel list instead of configuring it alone.';
  String get featuresTitle => _zh ? '主要功能' : 'Features';
  List<String> get features => _zh
      ? const [
          '• 发送文本、图片、语音等消息',
          '• 支持消息撤回、删除',
          '• 支持 @ 功能',
          '• 支持表情和扩展面板',
          '• 支持自定义消息气泡',
        ]
      : const [
          '• Send text, image, voice, and other messages',
          '• Delete messages for yourself or everyone',
          '• Mention users with @',
          '• Emoji and extension panels',
          '• Custom message bubbles',
        ];
  String get usageTitle => _zh ? '使用方式' : 'Usage';
  String get codeSample =>
      'ChannelPage(\n'
      '  onItemTap: (channel, index, context) {\n'
      '    Navigator.push(\n'
      '      context,\n'
      '      MaterialPageRoute(\n'
      '        builder: (_) => ChatPage(channel: channel),\n'
      '      ),\n'
      '    );\n'
      '  },\n'
      ')';
}
