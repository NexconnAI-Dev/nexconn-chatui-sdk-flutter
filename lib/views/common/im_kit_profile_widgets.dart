import 'package:flutter/material.dart';

import '../../providers/theme_provider.dart';
import '../../utils/chatui_asset.dart';
import '../../utils/system_ui_overlay.dart';

const double _appBarHeight = 50;
const double _avatarSize = 52;
const double _cellMinHeight = 64;
const double _horizontalPadding = 16;

AppBar imKitAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  final tokens = NexconnThemeProvider.resolveTokens(context);
  final backgroundColor = tokens.panelColor;
  return AppBar(
    title: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    ),
    centerTitle: true,
    toolbarHeight: _appBarHeight,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: backgroundColor,
    foregroundColor: tokens.primaryTextColor,
    systemOverlayStyle: systemUiOverlayStyleForBackground(backgroundColor),
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: tokens.dividerColor),
    ),
  );
}

InputDecoration imKitInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  Widget? prefixIcon,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: NexconnThemeProvider.resolveTokens(context).panelColor,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: colors.primary),
    ),
  );
}

ButtonStyle imKitPrimaryButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size(0, 44),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );
}

class ImKitSectionTitle extends StatelessWidget {
  final String title;

  const ImKitSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.secondaryTextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ImKitAvatar extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isGroup;
  final double size;
  final VoidCallback? onTap;

  const ImKitAvatar({
    super.key,
    required this.label,
    this.imageUrl,
    this.isGroup = false,
    this.size = _avatarSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isGroup ? 12 : size / 2),
        child: SizedBox.square(dimension: size, child: _image(context)),
      ),
    );
    if (onTap == null) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }

  Widget _image(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return ChatUIAsset.image(
      isGroup ? 'avatar_default_group.png' : 'avatar_default_single.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}

class ImKitCell extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;
  final bool showDivider;

  const ImKitCell({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    final effectiveEnabled = enabled && onTap != null;
    final textColor = !enabled
        ? tokens.secondaryTextColor.withValues(alpha: 0.55)
        : destructive
        ? Theme.of(context).colorScheme.error
        : tokens.primaryTextColor;
    final subtitleColor = !enabled
        ? tokens.secondaryTextColor.withValues(alpha: 0.45)
        : tokens.secondaryTextColor;
    return Material(
      color: tokens.panelColor,
      child: InkWell(
        onTap: effectiveEnabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: _cellMinHeight),
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: tokens.dividerColor))
                : null,
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subtitleColor, fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class ImKitInfoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  const ImKitInfoCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.dividerColor),
      ),
      child: child,
    );
  }
}

class ImKitUnsupportedBadge extends StatelessWidget {
  final String text;

  const ImKitUnsupportedBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tokens.secondaryTextColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String? imKitSafeAvatarUrl(Object? value) {
  if (value == null) {
    return null;
  }
  try {
    final avatarUrl = (value as dynamic).avatarUrl;
    if (avatarUrl is String && avatarUrl.trim().isNotEmpty) {
      return avatarUrl;
    }
  } catch (_) {
    return null;
  }
  return null;
}
