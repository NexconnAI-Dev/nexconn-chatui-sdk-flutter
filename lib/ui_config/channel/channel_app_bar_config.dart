import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// Configuration for the channel list top bar.
class ChannelAppBarConfig {
  final double height;
  final String? title;
  final bool centerTitle;
  final Color? backgroundColor;
  final TextStyle? titleTextStyle;
  final double titleSpacing;
  final List<Widget>? actions;

  const ChannelAppBarConfig({
    this.height = appbarHeight,
    this.title,
    this.centerTitle = false,
    this.backgroundColor,
    this.titleTextStyle,
    this.titleSpacing = 26,
    this.actions,
  });
}
