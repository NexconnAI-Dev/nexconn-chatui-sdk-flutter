part of '../message_bubble.dart';

extension _MessageBubbleContent on _MessageBubbleBase {
  Widget _content(
    BuildContext context,
    MessageStyleConfig style,
    ChatMessageBubbleBuilder? customBuilder,
  ) {
    if (customBuilder != null) {
      return customBuilder(context, message, config);
    }
    return buildMessageContent(context, style);
  }
}
