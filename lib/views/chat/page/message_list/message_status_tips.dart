part of '../message_list_widget.dart';

enum _ChatMessageMenuAction {
  copy,
  edit,
  delete,
  deleteForAll,
  reference,
  more,
}

class _NetworkTip extends StatelessWidget {
  final String text;

  const _NetworkTip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: const Color(0xFFFFF3CD),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF7A4D00)),
      ),
    );
  }
}

class _StatusTip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _StatusTip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Align(
        alignment: Alignment.center,
        child: TextButton(onPressed: onTap, child: Text(text)),
      ),
    );
  }
}

class _UnreadMentionedTip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _UnreadMentionedTip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.redAccent.withValues(alpha: .8),
        foregroundColor: Colors.white,
      ),
      onPressed: onTap,
      child: Text(context.chatUIL10n.chatUnreadMentionedTip(count)),
    );
  }
}

class _UnreadCountTip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _UnreadCountTip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      onPressed: onTap,
      child: Text('${context.chatUIL10n.chatUnreadHistoryTip} ($count)'),
    );
  }
}
