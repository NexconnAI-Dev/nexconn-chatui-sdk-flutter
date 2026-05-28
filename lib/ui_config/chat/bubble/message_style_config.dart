import 'package:flutter/material.dart';

/// Visual style for built-in message bubble content.
class MessageStyleConfig {
  final Color backgroundColor;
  final Color textColor;
  final TextStyle? textStyle;

  const MessageStyleConfig({
    required this.backgroundColor,
    required this.textColor,
    this.textStyle,
  });
}
