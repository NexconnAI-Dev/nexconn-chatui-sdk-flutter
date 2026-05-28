part of '../message_input_config.dart';

/// Location payload selected from the MessageInput extension panel.
class MessageInputLocationDraft {
  /// Location longitude.
  final double longitude;

  /// Location latitude.
  final double latitude;

  /// Display name for the selected place.
  final String poiName;

  /// Local thumbnail path for the location preview.
  final String thumbnailPath;

  const MessageInputLocationDraft({
    required this.longitude,
    required this.latitude,
    required this.poiName,
    required this.thumbnailPath,
  });
}

/// Resolves a location draft for an extension plugin.
typedef MessageInputLocationDraftResolver =
    FutureOr<MessageInputLocationDraft?> Function(
      BuildContext context,
      MessageInputExtensionPlugin plugin,
    );

/// Candidate shown by MessageInput mention search.
class MessageInputMentionCandidate {
  /// Nexconn user id inserted into mentioned info.
  final String userId;

  /// Name displayed in the input draft.
  final String displayName;

  const MessageInputMentionCandidate({
    required this.userId,
    required this.displayName,
  });

  /// Text inserted into the input field.
  String get insertedText => '@$displayName ';
}

/// Searches mention candidates for MessageInput.
typedef MessageInputMentionResolver =
    FutureOr<List<MessageInputMentionCandidate>> Function(
      BuildContext context,
      BaseChannel channel,
    );

/// Lets the host app provide a custom mention picker.
typedef MessageInputMentionPicker =
    FutureOr<MessageInputMentionCandidate?> Function(
      BuildContext context,
      BaseChannel channel,
    );

/// Builds a mention candidate row.
typedef MessageInputMentionCandidateBuilder =
    Widget Function(
      BuildContext context,
      MessageInputMentionCandidate candidate,
    );
