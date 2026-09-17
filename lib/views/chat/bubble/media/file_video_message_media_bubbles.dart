part of '../message_bubble.dart';

extension _MessageBubbleFileVideoMessageMediaBubbles on _MessageBubbleBase {
  Widget _fileBubble(
    BuildContext context,
    FileMessage file,
    MessageStyleConfig style,
  ) {
    return SizedBox(
      width: kBubbleFileWidth,
      height: kBubbleFileHeight,
      child: Row(
        children: [
          ChatUIAsset.image(
            'NexconnLightIcon/File.png',
            width: kBubbleFileIconSize,
            height: kBubbleFileIconSize,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name ?? context.chatUIL10n.fileUntitled,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      style.textStyle ??
                      TextStyle(
                        color: style.textColor,
                        fontSize: kBubbleFileNameFontSize,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fileSizeText(context, file.size),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.textColor.withValues(alpha: 0.65),
                    fontSize: kBubbleFileSizeFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fileSizeText(BuildContext context, int? size) {
    if (size == null || size < 0) {
      return context.chatUIL10n.fileSizeBytes(0);
    }
    if (size < 1024) {
      return context.chatUIL10n.fileSizeBytes(size);
    }
    final kb = size / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }

  String _durationText(int duration) {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
