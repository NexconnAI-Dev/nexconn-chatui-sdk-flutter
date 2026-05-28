part of '../message_bubble.dart';

extension _MessageBubbleMedia on _MessageBubbleBase {
  Widget _mediaLabel(String assetName, String label, MessageStyleConfig style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatUIAsset.image(
          assetName,
          width: 18,
          height: 18,
          color: style.textColor,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: style.textStyle ?? TextStyle(color: style.textColor),
          ),
        ),
      ],
    );
  }
}
