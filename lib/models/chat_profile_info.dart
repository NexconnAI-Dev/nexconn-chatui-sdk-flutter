import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';

/// Display profile used by chat titles, sender names, and avatars.
class ChatProfileInfo {
  final String id;
  final String? name;
  final String? portraitUri;
  final String? extra;

  const ChatProfileInfo({
    required this.id,
    this.name,
    this.portraitUri,
    this.extra,
  });
}

/// Resolves display profile data for a user in a channel.
typedef ChatProfileProvider =
    Future<ChatProfileInfo?> Function(BaseChannel channel, {Message? message});
