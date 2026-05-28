import 'package:flutter/material.dart';

import '../../../utils/constants.dart';
import 'message_style_config.dart';

/// Avatar shape used in the chat message list.
enum ChatAvatarShape { circle, roundedRectangle, square }

/// Avatar configuration for message bubbles.
class ChatAvatarConfig {
  final double size;
  final ChatAvatarShape shape;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final TextStyle? textStyle;

  const ChatAvatarConfig({
    this.size = kBubbleAvatarSize,
    this.shape = ChatAvatarShape.circle,
    this.borderRadius,
    this.backgroundColor = const Color(0xFF9CA3AF),
    this.textStyle,
  });

  BorderRadius get effectiveBorderRadius {
    switch (shape) {
      case ChatAvatarShape.circle:
        return BorderRadius.circular(size / 2);
      case ChatAvatarShape.roundedRectangle:
        return borderRadius ?? BorderRadius.circular(10);
      case ChatAvatarShape.square:
        return BorderRadius.zero;
    }
  }
}

/// Image preview behavior for image and short-video messages.
class ChatImagePreviewConfig {
  final BoxFit fit;
  final double maxWidth;
  final double maxHeight;
  final double borderRadius;

  const ChatImagePreviewConfig({
    this.fit = BoxFit.contain,
    this.maxWidth = 200,
    this.maxHeight = 200,
    this.borderRadius = 8,
  });

  ChatImagePreviewConfig copyWith({
    BoxFit? fit,
    double? maxWidth,
    double? maxHeight,
    double? borderRadius,
  }) {
    return ChatImagePreviewConfig(
      fit: fit ?? this.fit,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}

/// Top-level configuration for message bubble rendering.
class BubbleConfig {
  final MessageStyleConfig sentStyle;
  final MessageStyleConfig receivedStyle;
  final double borderRadius;
  final ChatAvatarConfig avatarConfig;
  final ChatImagePreviewConfig imagePreviewConfig;

  const BubbleConfig({
    this.sentStyle = const MessageStyleConfig(
      backgroundColor: meBubbleColor,
      textColor: Colors.white,
    ),
    this.receivedStyle = const MessageStyleConfig(
      backgroundColor: othersBubbleColor,
      textColor: Color(0xFF111111),
    ),
    this.borderRadius = kBubbleBorderRadius,
    this.avatarConfig = const ChatAvatarConfig(),
    this.imagePreviewConfig = const ChatImagePreviewConfig(),
  });

  BubbleConfig copyWith({
    MessageStyleConfig? sentStyle,
    MessageStyleConfig? receivedStyle,
    double? borderRadius,
    ChatAvatarConfig? avatarConfig,
    ChatImagePreviewConfig? imagePreviewConfig,
  }) {
    return BubbleConfig(
      sentStyle: sentStyle ?? this.sentStyle,
      receivedStyle: receivedStyle ?? this.receivedStyle,
      borderRadius: borderRadius ?? this.borderRadius,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      imagePreviewConfig: imagePreviewConfig ?? this.imagePreviewConfig,
    );
  }
}
