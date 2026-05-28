import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../providers/chat_provider.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/time_util.dart';

/// Displays message search results.
class ChatMessageSearchResultPage extends StatelessWidget {
  final ChatProvider provider;
  final ChatMessageSearchRequest request;
  final List<Message> messages;
  final ValueChanged<Message>? onMessageTap;

  const ChatMessageSearchResultPage({
    super.key,
    required this.provider,
    required this.request,
    required this.messages,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: ChatUIAsset.image(
            'NexconnLightIcon/Left-arrow.png',
            width: 22,
            height: 22,
            color: const Color(0xFF111111),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          context.chatUIL10n.searchResultsTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEAEAEA)),
        ),
      ),
      body: AnimatedBuilder(
        animation: provider,
        builder: (context, _) {
          return Column(
            children: [
              _HeaderCard(request: request, count: messages.length),
              Expanded(
                child: messages.isEmpty
                    ? _EmptyResults(
                        text: context.chatUIL10n.searchNoMatchingMessages,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _MessageRow(
                            message: message,
                            now: provider.engineProvider.serverNow,
                            onTap: () => onMessageTap?.call(message),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 72,
                          color: Color(0xFFEAEAEA),
                        ),
                        itemCount: messages.length,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final ChatMessageSearchRequest request;
  final int count;

  const _HeaderCard({required this.request, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.chatUIL10n.searchResultsCount(count),
            style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final Message message;
  final DateTime? now;
  final VoidCallback? onTap;

  const _MessageRow({required this.message, this.now, this.onTap});

  @override
  Widget build(BuildContext context) {
    final copyText = ChatProvider.extractCopyText(message);
    final body = copyText?.isNotEmpty == true
        ? copyText!
        : context.chatUIL10n.searchUnsupportedMessagePreview;
    final sentTime = TimeUtil.formatMessageTime(
      message.sentTime,
      now: now,
      l10n: context.chatUIL10n,
    );

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEFF3FF),
                ),
                child: ChatUIAsset.image(
                  'NexconnLightIcon/Chat.png',
                  color: Color(0xFF3D6DCC),
                  width: 22,
                  height: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message.senderUserId ??
                                context.chatUIL10n.commonUnknownUser,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (sentTime.isNotEmpty)
                          Text(
                            sentTime,
                            style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final String text;

  const _EmptyResults({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/Search.png',
            width: 44,
            height: 44,
            color: const Color(0xFFC7C7CC),
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Color(0xFF999999))),
        ],
      ),
    );
  }
}
