import 'package:flutter/material.dart';

import '../../../providers/theme_provider.dart';
import '../../../ui_config/channel/channel_app_bar_config.dart';
import '../../../utils/constants.dart';
import '../../../utils/system_ui_overlay.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';

/// Default app bar for ChannelPage.
class ChannelAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final ChannelAppBarConfig config;

  const ChannelAppBarWidget({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final l10n = context.chatUIL10n;
    final backgroundColor = config.backgroundColor ?? theme.panelColor;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemUiOverlayStyleForBackground(backgroundColor),
      toolbarHeight: config.height,
      title: Text(
        config.title ?? l10n.channelAppBarTitle,
        style:
            config.titleTextStyle ??
            TextStyle(
              color: theme.primaryTextColor,
              fontSize: appbarFontSize,
              fontWeight: appbarFontWeight,
            ),
      ),
      titleSpacing: config.titleSpacing,
      centerTitle: config.centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: theme.primaryTextColor,
      actions: config.actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.dividerColor),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(config.height + 1);
}
