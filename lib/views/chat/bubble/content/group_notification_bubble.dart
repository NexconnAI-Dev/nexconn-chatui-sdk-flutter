part of '../message_bubble.dart';

extension _MessageBubbleGroupNotification on _MessageBubbleBase {
  Widget _groupNotificationTip(BuildContext context) {
    final text = _groupNotificationText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: kBubblePaddingVertical,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _bubbleMaxWidth(context)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFEDEFF3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF8C919C),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _groupNotificationText(BuildContext context) {
    if (message is GroupNotificationMessage) {
      final groupMessage = message as GroupNotificationMessage;
      final displayText = groupMessage.message?.trim();
      if (displayText != null && displayText.isNotEmpty) {
        return displayText;
      }
      final data = groupMessage.data?.trim();
      if (data != null && data.isNotEmpty) {
        return data;
      }
      return messageSummary(message, localizations: context.chatUIL10n);
    }
    if (message is CustomMessage) {
      return _customGroupNotificationText(context, message as CustomMessage);
    }
    return messageSummary(message, localizations: context.chatUIL10n);
  }

  String _customGroupNotificationText(
    BuildContext context,
    CustomMessage custom,
  ) {
    final fields = custom.fields;
    if (fields == null) {
      return messageSummary(message, localizations: context.chatUIL10n);
    }
    final currentUserId = _maybeEngineProvider(context)?.currentUserId;
    final operation = fields['operation']?.toString();
    final data = fields['data'];
    final dataMap = data is Map ? data : const <String, dynamic>{};
    final operatorUserId = fields['operatorUserId']?.toString();
    var operatorName =
        dataMap['operatorNickname']?.toString().trim().isNotEmpty == true
        ? dataMap['operatorNickname'].toString()
        : operatorUserId ?? '';
    if (operatorUserId != null &&
        operatorUserId.isNotEmpty &&
        operatorUserId == currentUserId) {
      operatorName = 'You';
    }
    final targetNames = _targetDisplayNames(dataMap, currentUserId);
    return switch (operation) {
      'Add' =>
        targetNames.isEmpty
            ? '$operatorName invited members to the group'
            : '$operatorName invited $targetNames to the group',
      'Create' => '$operatorName created the group',
      'Kicked' =>
        targetNames.isEmpty
            ? '$operatorName removed members from the group'
            : '$operatorName removed $targetNames from the group',
      _ => messageSummary(message, localizations: context.chatUIL10n),
    };
  }

  String _targetDisplayNames(Map data, String? currentUserId) {
    final ids = data['targetUserIds'];
    final names = data['targetUserDisplayNames'];
    if (ids is! List || names is! List) {
      return '';
    }
    final values = <String>[];
    for (var index = 0; index < names.length; index++) {
      final id = index < ids.length ? ids[index]?.toString() : null;
      final name = id != null && id == currentUserId
          ? 'You'
          : names[index]?.toString();
      if (name != null && name.trim().isNotEmpty) {
        values.add(name.trim());
      }
    }
    return values.join(' ');
  }
}
