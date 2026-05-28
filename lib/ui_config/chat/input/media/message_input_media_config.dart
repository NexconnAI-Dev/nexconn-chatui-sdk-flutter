part of '../message_input_config.dart';

/// Resolved media selected from the MessageInput extension panel.
class MessageInputMediaDraft {
  /// Local or remote media path passed to ChatProvider send helpers.
  final String path;

  /// Media duration in seconds for voice and short-video messages.
  final int duration;

  /// Optional MIME type used to distinguish GIF and file payloads.
  final String? mimeType;

  const MessageInputMediaDraft({
    required this.path,
    this.duration = 0,
    this.mimeType,
  });

  /// Whether the draft should be sent as a GIF image.
  bool get isGif {
    final normalizedMime = mimeType?.toLowerCase();
    return normalizedMime == 'image/gif' || path.toLowerCase().endsWith('.gif');
  }
}

/// Resolves a media draft for an extension plugin.
typedef MessageInputMediaDraftResolver =
    FutureOr<List<MessageInputMediaDraft>?> Function(
      BuildContext context,
      MessageInputExtensionPlugin plugin,
    );

/// Builds a custom extension panel item.
typedef MessageInputExtensionPluginBuilder =
    Widget Function(BuildContext context, MessageInputExtensionPlugin plugin);
