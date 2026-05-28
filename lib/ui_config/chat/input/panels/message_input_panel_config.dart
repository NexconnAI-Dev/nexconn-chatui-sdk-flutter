part of '../message_input_config.dart';

/// Configuration for the emoji panel layout.
class MessageInputEmojiPanelConfig {
  final Color? backgroundColor;
  final double height;
  final int rowCount;
  final int columnCount;
  final double emojiSize;
  final double rowSpacing;
  final double columnSpacing;
  final EdgeInsets padding;
  final MessageInputPanelIndicatorConfig pageIndicatorConfig;
  final Widget deleteIcon;
  final MessageInputEmojiSendButtonConfig sendButtonConfig;
  final MessageInputEmojiItemBuilder? emojiItemBuilder;
  final MessageInputEmojiActionBuilder? deleteButtonBuilder;
  final MessageInputEmojiActionBuilder? sendButtonBuilder;

  const MessageInputEmojiPanelConfig({
    this.backgroundColor,
    this.height = 224.0,
    this.rowCount = 3,
    this.columnCount = 8,
    this.emojiSize = 24.0,
    this.rowSpacing = 10.0,
    this.columnSpacing = 5.0,
    this.padding = const EdgeInsets.all(15.0),
    this.pageIndicatorConfig = const MessageInputPanelIndicatorConfig(),
    this.deleteIcon = const Icon(
      Icons.backspace,
      color: Color(0xFF666666),
      size: 24,
    ),
    this.sendButtonConfig = const MessageInputEmojiSendButtonConfig(),
    this.emojiItemBuilder,
    this.deleteButtonBuilder,
    this.sendButtonBuilder,
  });

  MessageInputEmojiPanelConfig copyWith({
    Color? backgroundColor,
    double? height,
    int? rowCount,
    int? columnCount,
    double? emojiSize,
    double? rowSpacing,
    double? columnSpacing,
    EdgeInsets? padding,
    MessageInputPanelIndicatorConfig? pageIndicatorConfig,
    Widget? deleteIcon,
    MessageInputEmojiSendButtonConfig? sendButtonConfig,
    MessageInputEmojiItemBuilder? emojiItemBuilder,
    MessageInputEmojiActionBuilder? deleteButtonBuilder,
    MessageInputEmojiActionBuilder? sendButtonBuilder,
  }) {
    return MessageInputEmojiPanelConfig(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      height: height ?? this.height,
      rowCount: rowCount ?? this.rowCount,
      columnCount: columnCount ?? this.columnCount,
      emojiSize: emojiSize ?? this.emojiSize,
      rowSpacing: rowSpacing ?? this.rowSpacing,
      columnSpacing: columnSpacing ?? this.columnSpacing,
      padding: padding ?? this.padding,
      pageIndicatorConfig: pageIndicatorConfig ?? this.pageIndicatorConfig,
      deleteIcon: deleteIcon ?? this.deleteIcon,
      sendButtonConfig: sendButtonConfig ?? this.sendButtonConfig,
      emojiItemBuilder: emojiItemBuilder ?? this.emojiItemBuilder,
      deleteButtonBuilder: deleteButtonBuilder ?? this.deleteButtonBuilder,
      sendButtonBuilder: sendButtonBuilder ?? this.sendButtonBuilder,
    );
  }
}

/// Configuration for an input panel page indicator.
class MessageInputPanelIndicatorConfig {
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final double spacing;
  final double bottomPadding;

  const MessageInputPanelIndicatorConfig({
    this.activeColor,
    this.inactiveColor,
    this.size = 8.0,
    this.spacing = 4.0,
    this.bottomPadding = 10.0,
  });
}

/// Configuration for the emoji panel send button.
class MessageInputEmojiSendButtonConfig {
  final String? text;
  final double width;
  final double height;
  final Color? backgroundColor;
  final TextStyle textStyle;
  final double borderRadius;
  final EdgeInsets margin;

  const MessageInputEmojiSendButtonConfig({
    this.text,
    this.width = 60.0,
    this.height = 35.0,
    this.backgroundColor,
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.w500,
    ),
    this.borderRadius = 8.0,
    this.margin = const EdgeInsets.only(right: 15.0, bottom: 0.0),
  });
}

/// Configuration for the extension panel grid.
class MessageInputExtensionPanelConfig {
  final int itemsPerPage;
  final int crossAxisCount;
  final Color? backgroundColor;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets padding;
  final MessageInputPanelIndicatorConfig pageIndicatorConfig;
  final double height;
  final double itemRadius;
  final double titleAreaHeight;

  const MessageInputExtensionPanelConfig({
    this.itemsPerPage = 8,
    this.crossAxisCount = 4,
    this.backgroundColor,
    this.mainAxisSpacing = 24.0,
    this.crossAxisSpacing = 28.0,
    this.padding = const EdgeInsets.fromLTRB(26, 16, 26, 42),
    this.pageIndicatorConfig = const MessageInputPanelIndicatorConfig(
      activeColor: Color(0xFF999999),
      inactiveColor: Color(0xFFD8D8D8),
    ),
    this.height = 224.0,
    this.itemRadius = 6.0,
    this.titleAreaHeight = 28.0,
  });
}
