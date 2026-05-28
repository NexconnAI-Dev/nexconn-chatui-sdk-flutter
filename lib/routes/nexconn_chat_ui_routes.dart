import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../providers/audio_player_provider.dart';
import '../providers/channel_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/user_profile_provider.dart';
import '../ui_config/chat/page/chat_page_config.dart';
import '../ui_config/user/user_profile_page_config.dart';

/// Named route helpers and argument types for ChatUI pages.
class NexconnChatUIRoutes {
  /// ChatPage route name.
  static const String chat = '/chat';

  /// ChatMessageSearchPage route name.
  static const String chatSearch = '/search';

  /// ForwardSelectPage route name.
  static const String forward = '/forward';

  /// PhotoPreviewPage route name.
  static const String photoPreview = '/photo-preview';

  /// ShortVideoPreviewPage route name.
  static const String shortVideoPreview = '/short-video-preview';

  /// FilePreviewPage route name.
  static const String filePreview = '/file-preview';

  /// CombineMessageDetailPage route name.
  static const String combineMessageDetail = '/combine-message-detail';

  /// NexconnUserProfilePage route name.
  static const String userProfile = '/user-profile';

  const NexconnChatUIRoutes._();
}

/// Callback fired when a forward target channel is selected.
typedef NexconnForwardChannelSelected =
    Future<bool> Function(BaseChannel channel, ChatForwardMode mode);

/// Pushes a named route when the app defines it, otherwise pushes [fallbackRoute].
Future<T?> pushNexconnChatUINamedRouteOr<T>(
  BuildContext context,
  String routeName, {
  Object? arguments,
  required Route<T> Function() fallbackRoute,
}) {
  final navigator = Navigator.of(context);
  final route = _resolveNamedRoute<T>(
    navigator,
    RouteSettings(name: routeName, arguments: arguments),
  );
  if (route == null) {
    return navigator.push<T>(fallbackRoute());
  }
  return navigator.push<T>(route);
}

Route<T>? _resolveNamedRoute<T>(
  NavigatorState navigator,
  RouteSettings settings,
) {
  try {
    final generatedRoute = navigator.widget.onGenerateRoute?.call(settings);
    if (generatedRoute != null) {
      return generatedRoute as Route<T>;
    }
    final unknownRoute = navigator.widget.onUnknownRoute?.call(settings);
    if (unknownRoute != null) {
      return unknownRoute as Route<T>;
    }
  } catch (error, stackTrace) {
    if (!_isMissingNamedRoute(error)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
  return null;
}

bool _isMissingNamedRoute(Object error) {
  if (error is! FlutterError) {
    return false;
  }
  final message = error.toString();
  return message.contains('Could not find a generator for route') ||
      message.contains('Could not find a generator for RouteSettings') ||
      message.contains('Navigator.onGenerateRoute returned null') ||
      message.contains('Navigator.onUnknownRoute returned null');
}

/// Route arguments for opening ChatPage.
class NexconnChatPageRouteArguments {
  final BaseChannel channel;
  final ChatPageConfig config;
  final ChatProvider? provider;
  final ChannelProvider Function(BuildContext context)?
  forwardChannelProviderBuilder;

  const NexconnChatPageRouteArguments({
    required this.channel,
    this.config = const ChatPageConfig(),
    this.provider,
    this.forwardChannelProviderBuilder,
  });
}

/// Route arguments for opening ChatMessageSearchPage.
class NexconnChatSearchRouteArguments {
  final ChatProvider provider;
  final BaseChannel channel;
  final String title;
  final ValueChanged<Message>? onMessageTap;

  const NexconnChatSearchRouteArguments({
    required this.provider,
    required this.channel,
    this.title = '',
    this.onMessageTap,
  });
}

/// Route arguments for opening ForwardSelectPage.
class NexconnForwardSelectRouteArguments {
  final ChannelProvider provider;
  final List<Message> messages;
  final ChatForwardMode? initialMode;
  final NexconnForwardChannelSelected onChannelSelected;

  const NexconnForwardSelectRouteArguments({
    required this.provider,
    required this.messages,
    this.initialMode,
    required this.onChannelSelected,
  });
}

/// Route arguments for opening PhotoPreviewPage.
class NexconnPhotoPreviewRouteArguments {
  final List<MediaMessage> images;
  final int initialIndex;
  final ChatProvider? provider;

  const NexconnPhotoPreviewRouteArguments({
    required this.images,
    this.initialIndex = 0,
    this.provider,
  });
}

/// Route arguments for opening ShortVideoPreviewPage.
class NexconnShortVideoPreviewRouteArguments {
  final List<ShortVideoMessage> videos;
  final int initialIndex;
  final ChatProvider? provider;

  const NexconnShortVideoPreviewRouteArguments({
    required this.videos,
    this.initialIndex = 0,
    this.provider,
  });
}

/// Route arguments for opening FilePreviewPage.
class NexconnFilePreviewRouteArguments {
  final FileMessage fileMessage;
  final ChatProvider? provider;

  const NexconnFilePreviewRouteArguments({
    required this.fileMessage,
    this.provider,
  });
}

/// Route arguments for opening CombineMessageDetailPage.
class NexconnCombineMessageDetailRouteArguments {
  final CombineMessage message;
  final ChatPageConfig config;
  final ChatProvider provider;
  final NexconnAudioPlayerProvider? audioPlayerProvider;

  const NexconnCombineMessageDetailRouteArguments({
    required this.message,
    required this.config,
    required this.provider,
    this.audioPlayerProvider,
  });
}

/// Route arguments for opening NexconnUserProfilePage.
class NexconnUserProfileRouteArguments {
  final String userId;
  final NexconnUserProfilePageConfig config;
  final NexconnUserProfileProvider? provider;

  const NexconnUserProfileRouteArguments({
    required this.userId,
    this.config = const NexconnUserProfilePageConfig(),
    this.provider,
  });
}
