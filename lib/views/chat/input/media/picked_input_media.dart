part of '../message_input_widget.dart';

class _PickedInputMedia {
  final String path;
  final int duration;
  final String? mimeType;

  const _PickedInputMedia({
    required this.path,
    this.duration = 0,
    this.mimeType,
  });

  factory _PickedInputMedia.fromDraft(MessageInputMediaDraft draft) {
    return _PickedInputMedia(
      path: draft.path,
      duration: draft.duration,
      mimeType: draft.mimeType,
    );
  }

  bool get isGif {
    final normalizedMime = mimeType?.toLowerCase();
    return normalizedMime == 'image/gif' || path.toLowerCase().endsWith('.gif');
  }
}
