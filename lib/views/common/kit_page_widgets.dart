import 'package:flutter/material.dart';

import '../../providers/theme_provider.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/constants.dart';
import '../../utils/system_ui_overlay.dart';

const double kitAppBarHeight = 56.0;
const double kitListItemHeight = 64.0;
const double kitAvatarSize = 44.0;
const EdgeInsets kitPagePadding = EdgeInsets.symmetric(horizontal: 16);

class KitAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;
  final Widget? leading;
  final double leadingWidth;
  final bool automaticallyImplyLeading;

  const KitAppBar({
    super.key,
    required this.title,
    this.actions,
    this.centerTitle = true,
    this.leading,
    this.leadingWidth = 56,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final backgroundColor = theme.panelColor;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: systemUiOverlayStyleForBackground(backgroundColor),
      toolbarHeight: kitAppBarHeight,
      leadingWidth: leadingWidth,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      centerTitle: centerTitle,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.primaryTextColor,
          fontSize: appbarFontSize,
          fontWeight: appbarFontWeight,
        ),
      ),
      backgroundColor: backgroundColor,
      foregroundColor: theme.primaryTextColor,
      surfaceTintColor: Colors.transparent,
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: theme.dividerColor),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kitAppBarHeight + 1);
}

class KitSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  const KitSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(color: theme.primaryTextColor, fontSize: 15),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
          prefixIcon: Center(
            child: ChatUIAsset.image(
              'NexconnLightIcon/Search.png',
              width: 20,
              height: 20,
              color: theme.secondaryTextColor,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 36,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: ChatUIAsset.image(
                    'NexconnLightIcon/Close.png',
                    width: 18,
                    height: 18,
                    color: theme.secondaryTextColor,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onClear,
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }
}

class KitAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double size;
  final IconData? icon;

  const KitAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackText,
    this.size = kitAvatarSize,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: size,
        height: size,
        color: theme.surfaceColor,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(theme),
              )
            : _fallback(theme),
      ),
    );
  }

  Widget _fallback(NexconnThemeTokens theme) {
    if (icon != null) {
      return Icon(icon, size: size * 0.56, color: theme.secondaryTextColor);
    }
    final text = fallbackText.trim().isEmpty
        ? '?'
        : fallbackText.trim().characters.first.toUpperCase();
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: theme.primaryTextColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class KitListItem extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final double minHeight;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const KitListItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.minHeight = kitListItemHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.backgroundColor,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final content = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      color: backgroundColor ?? theme.panelColor,
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleStyle ??
                      TextStyle(
                        color: theme.primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        subtitleStyle ??
                        TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 13,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    return Material(
      color: backgroundColor ?? theme.panelColor,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            if (showDivider)
              Padding(
                padding: EdgeInsets.only(
                  left:
                      padding.left + (leading == null ? 0 : kitAvatarSize + 12),
                ),
                child: Container(height: 1, color: theme.dividerColor),
              ),
          ],
        ),
      ),
    );
  }
}

class KitPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool outlined;

  const KitPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.destructive = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    final color = destructive ? theme.destructiveColor : theme.primaryColor;
    final textColor = outlined ? color : Colors.white;
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          backgroundColor: outlined ? theme.panelColor : color,
          disabledForegroundColor: theme.secondaryTextColor,
          disabledBackgroundColor: outlined
              ? theme.panelColor
              : theme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: outlined ? BorderSide(color: color) : BorderSide.none,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}

class KitSectionHeader extends StatelessWidget {
  final String title;

  const KitSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
      ),
    );
  }
}

class KitEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KitEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatUIAsset.image(
              'NexconnLightIcon/No-messages.png',
              width: 48,
              height: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              KitPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
