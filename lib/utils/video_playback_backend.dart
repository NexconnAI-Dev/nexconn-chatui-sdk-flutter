import 'package:video_player_media_kit/video_player_media_kit.dart';

/// Configures the video playback backend used by package:video_player.
class NexconnChatUIVideoPlayback {
  const NexconnChatUIVideoPlayback._();

  static bool _initialized = false;

  /// Uses media_kit as the Android backend for package:video_player.
  ///
  /// Call this before creating any [VideoPlayerController] or running the app.
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }
    VideoPlayerMediaKit.ensureInitialized(android: true);
    _initialized = true;
  }
}
