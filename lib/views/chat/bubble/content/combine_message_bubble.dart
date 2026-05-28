part of '../message_bubble.dart';

extension _MessageBubbleCombineContent on _MessageBubbleBase {
  Widget _combineBubble(BuildContext context, CombineMessage combine) {
    final l10n = context.chatUIL10n;
    final summaries = (combine.summaryList ?? const <String>[])
        .where((summary) => summary.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    return ConstrainedBox(
      key: MessageBubble.combinePreviewKey,
      constraints: const BoxConstraints.tightFor(width: 222),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE1E4E8), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    combineMessageTitle(
                      combine.nameList,
                      localizations: l10n,
                      sourceChannelType: combineMessageSourceChannelType(
                        combine,
                        fallbackChannelType: channel?.channelType,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final summary in summaries)
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8C95A3),
                        fontSize: 13,
                        height: 17 / 13,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(
              height: 0.5,
              thickness: 0.5,
              color: Color(0xFFE6E6E6),
            ),
            SizedBox(
              height: 30,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    l10n.combineMessageChatHistoryLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8C95A3),
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
