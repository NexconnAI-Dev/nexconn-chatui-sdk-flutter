import '../l10n/nexconn_chat_ui_localizations.dart';

/// Formats timestamps for ChatUI list and message displays.
class TimeUtil {
  TimeUtil._();

  static String formatMessageTime(
    int? milliseconds, {
    DateTime? now,
    NexconnChatUILocalizations? l10n,
  }) {
    if (milliseconds == null || milliseconds <= 0) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final currentTime = now ?? DateTime.now();
    final sameDay =
        date.year == currentTime.year &&
        date.month == currentTime.month &&
        date.day == currentTime.day;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (sameDay) {
      return '$hour:$minute';
    }
    return '${_formatShortDate(date, l10n)} $hour:$minute';
  }

  static String chatViewFormatTime(
    int? milliseconds, {
    DateTime? now,
    NexconnChatUILocalizations? l10n,
  }) {
    if (milliseconds == null || milliseconds <= 0) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final currentTime = now ?? DateTime.now();
    final minute = date.minute.toString().padLeft(2, '0');
    if (date.year != currentTime.year) {
      return '${date.year}/${date.month}/${date.day} ${date.hour}:$minute';
    }
    if (date.month != currentTime.month) {
      return '${date.month}/${date.day} ${date.hour}:$minute';
    }
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nowOnly = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final differenceInDays = nowOnly.difference(dateOnly).inDays;
    if (differenceInDays == 0) {
      return '${date.hour}:$minute';
    }
    if (differenceInDays == 1) {
      final time = '${date.hour}:$minute';
      return l10n?.combineMessageTimeYesterday(time) ?? '昨天 $time';
    }
    if (differenceInDays > 1 && differenceInDays < 7) {
      return '${_localizedWeekday(date.weekday, l10n)} ${date.hour}:$minute';
    }
    return '${_formatShortDate(date, l10n)} ${date.hour}:$minute';
  }

  static bool shouldShowMessageTime(int? current, int? previous) {
    if (current == null || current <= 0) {
      return false;
    }
    if (previous == null || previous <= 0) {
      return true;
    }
    return (current - previous).abs() > 3 * 60 * 1000;
  }

  static String formatChannelTime(
    int? milliseconds, {
    DateTime? now,
    NexconnChatUILocalizations? l10n,
  }) {
    if (milliseconds == null || milliseconds <= 0) {
      return '';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final currentTime = now ?? DateTime.now();
    if (date.year != currentTime.year) {
      return _formatFullDate(date, l10n);
    }
    final dateOnly = DateTime(date.year, date.month, date.day);
    final nowOnly = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final differenceInDays = nowOnly.difference(dateOnly).inDays;
    if (differenceInDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (differenceInDays == 1) {
      return l10n?.commonYesterday ?? '昨天';
    }
    if (differenceInDays > 1 && differenceInDays < 7) {
      return _localizedWeekday(date.weekday, l10n);
    }
    return _formatShortDate(date, l10n);
  }

  static String _localizedWeekday(
    int weekday,
    NexconnChatUILocalizations? l10n,
  ) {
    if (l10n == null) {
      const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
      return weekdays[weekday % 7];
    }
    return switch (weekday) {
      DateTime.monday => l10n.commonWeekdayMonday,
      DateTime.tuesday => l10n.commonWeekdayTuesday,
      DateTime.wednesday => l10n.commonWeekdayWednesday,
      DateTime.thursday => l10n.commonWeekdayThursday,
      DateTime.friday => l10n.commonWeekdayFriday,
      DateTime.saturday => l10n.commonWeekdaySaturday,
      DateTime.sunday => l10n.commonWeekdaySunday,
      _ => '',
    };
  }

  static String _formatShortDate(
    DateTime date,
    NexconnChatUILocalizations? l10n,
  ) {
    if (l10n?.localeName.startsWith('zh') ?? true) {
      return '${date.month}月${date.day}日';
    }
    return '${date.month}/${date.day}';
  }

  static String _formatFullDate(
    DateTime date,
    NexconnChatUILocalizations? l10n,
  ) {
    if (l10n?.localeName.startsWith('zh') ?? true) {
      return '${date.year}年${date.month}月${date.day}日';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}
