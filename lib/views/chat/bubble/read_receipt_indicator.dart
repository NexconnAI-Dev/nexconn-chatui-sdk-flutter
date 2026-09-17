import 'dart:math' as math;

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../../l10n/nexconn_chat_ui_l10n.dart';
import '../../../providers/read_receipt_repository.dart';
import '../../../providers/theme_provider.dart';

/// Compact V5 read-receipt state shown below an outgoing message bubble.
class ChatReadReceiptIndicator extends StatelessWidget {
  static const Key indicatorKey = ValueKey<String>(
    'chat-read-receipt-indicator',
  );

  final ChatReadReceiptDisplayData displayData;
  final ChannelType channelType;
  final double size;
  final Color? readColor;
  final Color? unreadColor;
  final VoidCallback? onTap;

  const ChatReadReceiptIndicator({
    super.key,
    required this.displayData,
    required this.channelType,
    this.size = 16,
    this.readColor,
    this.unreadColor,
    this.onTap,
  }) : assert(size > 0);

  @override
  Widget build(BuildContext context) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    final effectiveReadColor = readColor ?? tokens.successColor;
    final effectiveUnreadColor = unreadColor ?? tokens.secondaryTextColor;
    final state = _displayState;
    final minimumExtent = math.max(size, 24.0);

    return Semantics(
      key: indicatorKey,
      container: true,
      label: _semanticLabel(context, state),
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: SizedBox.square(
          dimension: minimumExtent,
          child: Center(
            child: CustomPaint(
              size: Size.square(size),
              painter: ChatReadReceiptPainter(
                state: state,
                readRatio: _paintReadRatio,
                readColor: effectiveReadColor,
                unreadColor: effectiveUnreadColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ChatReadReceiptDisplayState get _displayState {
    if (channelType == ChannelType.direct && displayData.readCount > 0) {
      return ChatReadReceiptDisplayState.read;
    }
    return displayData.state;
  }

  double get _paintReadRatio {
    final ratio = displayData.readRatio;
    return displayData.readCount > 0 && ratio < 0.1 ? 0.1 : ratio;
  }

  String _semanticLabel(
    BuildContext context,
    ChatReadReceiptDisplayState state,
  ) {
    final l10n = context.chatUIL10n;
    if (!displayData.isAuthoritative) return l10n.chatReadReceiptPending;
    return switch (state) {
      ChatReadReceiptDisplayState.unread => l10n.chatReadReceiptNotRead,
      ChatReadReceiptDisplayState.partial => l10n.chatReadReceiptPartiallyRead(
        displayData.readCount,
        displayData.effectiveTotalCount,
      ),
      ChatReadReceiptDisplayState.read => l10n.chatReadReceiptFullyRead,
    };
  }
}

/// Paints the unread outline, partial group pie, or fully-read check mark.
class ChatReadReceiptPainter extends CustomPainter {
  final ChatReadReceiptDisplayState state;
  final double readRatio;
  final Color readColor;
  final Color unreadColor;

  const ChatReadReceiptPainter({
    required this.state,
    required this.readRatio,
    required this.readColor,
    required this.unreadColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = math.max(1.2, side * 0.1);
    final radius = math.max(0.0, side / 2 - strokeWidth / 2);
    final active = state != ChatReadReceiptDisplayState.unread;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = active ? readColor : unreadColor;
    canvas.drawCircle(center, radius, outline);

    if (state == ChatReadReceiptDisplayState.partial) {
      final progressRadius = math.max(0.0, radius - strokeWidth * 1.35);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: progressRadius),
        -math.pi / 2,
        math.pi * 2 * readRatio.clamp(0.0, 1.0),
        true,
        Paint()
          ..style = PaintingStyle.fill
          ..color = readColor,
      );
      return;
    }

    if (state == ChatReadReceiptDisplayState.read) {
      final check = Path()
        ..moveTo(center.dx - side * 0.22, center.dy)
        ..lineTo(center.dx - side * 0.05, center.dy + side * 0.17)
        ..lineTo(center.dx + side * 0.25, center.dy - side * 0.2);
      canvas.drawPath(
        check,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = readColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ChatReadReceiptPainter oldDelegate) {
    return state != oldDelegate.state ||
        readRatio != oldDelegate.readRatio ||
        readColor != oldDelegate.readColor ||
        unreadColor != oldDelegate.unreadColor;
  }
}
