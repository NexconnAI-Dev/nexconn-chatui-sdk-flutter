import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'providers/login_provider.dart';
import 'providers/user_info_provider.dart';
import 'views/at_people_page.dart';
import 'views/main_tab_page.dart';
import 'views/theme_settings_page.dart';
import 'views/web_page.dart';
import 'views_github/setup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureExampleAudioSession();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  unawaited(_requestExampleMediaPermissions());

  final engineProvider = EngineProvider();
  final themeProvider = NexconnThemeProvider();
  final loginProvider = LoginProvider(engineProvider: engineProvider);
  final userInfoProvider = UserInfoProvider();

  runApp(
    NexconnChatUIProviders(
      engineProvider: engineProvider,
      themeProvider: themeProvider,
      child: ChangeNotifierProvider<UserInfoProvider>.value(
        value: userInfoProvider,
        child: MyPublicApp(
          engineProvider: engineProvider,
          themeProvider: themeProvider,
          loginProvider: loginProvider,
          userInfoProvider: userInfoProvider,
        ),
      ),
    ),
  );
}

Future<void> _configureExampleAudioSession() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  try {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionSetActiveOptions:
            AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ),
    );
  } catch (_) {
    // Best effort for the demo app: platforms and plugin registration can vary.
  }
}

Future<void> _requestExampleMediaPermissions() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  const permissions = <Permission>[
    Permission.camera,
    Permission.microphone,
    Permission.photos,
    Permission.storage,
    Permission.manageExternalStorage,
    Permission.videos,
    Permission.audio,
  ];

  for (final permission in permissions) {
    try {
      await permission.request();
    } catch (_) {
      // Best effort: unsupported permissions vary by Android version and ROM.
    }
  }
}

class MyPublicApp extends StatefulWidget {
  final EngineProvider engineProvider;
  final NexconnThemeProvider themeProvider;
  final LoginProvider loginProvider;
  final UserInfoProvider userInfoProvider;

  const MyPublicApp({
    super.key,
    required this.engineProvider,
    required this.themeProvider,
    required this.loginProvider,
    required this.userInfoProvider,
  });

  @override
  State<MyPublicApp> createState() => _MyPublicAppState();
}

class _MyPublicAppState extends State<MyPublicApp> {
  @override
  void initState() {
    super.initState();
    widget.themeProvider.addListener(_handleThemeChanged);
  }

  @override
  void dispose() {
    widget.themeProvider.removeListener(_handleThemeChanged);
    widget.loginProvider.dispose();
    widget.userInfoProvider.dispose();
    super.dispose();
  }

  void _handleThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => _PublicStrings.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: nexconnChatUIDefaultLocale,
      localizationsDelegates: NexconnChatUILocalizations.localizationsDelegates,
      supportedLocales: NexconnChatUILocalizations.supportedLocales,
      theme: widget.themeProvider.themeData(),
      home: SetupPage(loginProvider: widget.loginProvider),
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute<void>(
          builder: (_) => SetupPage(loginProvider: widget.loginProvider),
          settings: settings,
        );
      case '/main_tab':
        return MaterialPageRoute<void>(
          builder: (_) => MainTabPage(
            loginProvider: widget.loginProvider,
            engineProvider: widget.engineProvider,
            themeProvider: widget.themeProvider,
            userInfoProvider: widget.userInfoProvider,
          ),
          settings: settings,
        );
      case '/chat':
        final args = settings.arguments;
        if (args is NexconnChatPageRouteArguments) {
          return MaterialPageRoute<void>(
            builder: (_) => ChatPage(
              channel: args.channel,
              config: args.config,
              provider: args.provider,
              forwardChannelProviderBuilder: args.forwardChannelProviderBuilder,
            ),
            settings: settings,
          );
        }
        final legacyArgs = args is Map<String, dynamic> ? args : null;
        final channel = legacyArgs?['channel'] as BaseChannel?;
        return MaterialPageRoute<void>(
          builder: (_) {
            final targetChannel = channel ?? DirectChannel('alice');
            return ChatPage(
              channel: targetChannel,
              config: ChatPageConfig(
                appBarConfig: ChatAppBarConfig(
                  titleResolver: _resolveChatTitle,
                ),
                profileProvider: _resolveChatProfile,
                inputConfig: MessageInputConfig(
                  mentionPicker: _pickMentionCandidate,
                ),
              ),
            );
          },
          settings: settings,
        );
      case NexconnChatUIRoutes.chatSearch:
        final args = settings.arguments;
        if (args is! NexconnChatSearchRouteArguments) {
          return _invalidRoute(settings, 'Missing chat search arguments.');
        }
        return MaterialPageRoute<void>(
          builder: (_) => ChatMessageSearchPage(
            provider: args.provider,
            channel: args.channel,
            title: args.title,
            onMessageTap: args.onMessageTap,
          ),
          settings: settings,
        );
      case NexconnChatUIRoutes.forward:
        final args = settings.arguments;
        if (args is! NexconnForwardSelectRouteArguments) {
          return _invalidRoute(settings, 'Missing forward arguments.');
        }
        return MaterialPageRoute<bool>(
          builder: (_) => ForwardSelectPage(
            provider: args.provider,
            messages: args.messages,
            initialMode: args.initialMode,
            onChannelSelected: args.onChannelSelected,
          ),
          settings: settings,
        );
      case NexconnChatUIRoutes.photoPreview:
        final args = settings.arguments;
        if (args is! NexconnPhotoPreviewRouteArguments) {
          return _invalidRoute(settings, 'Missing photo preview arguments.');
        }
        return MaterialPageRoute<void>(
          builder: (_) => PhotoPreviewPage(
            images: args.images,
            initialIndex: args.initialIndex,
            provider: args.provider,
          ),
          settings: settings,
        );
      case NexconnChatUIRoutes.shortVideoPreview:
        final args = settings.arguments;
        if (args is! NexconnShortVideoPreviewRouteArguments) {
          return _invalidRoute(settings, 'Missing short video arguments.');
        }
        return MaterialPageRoute<void>(
          builder: (_) => ShortVideoPreviewPage(
            videos: args.videos,
            initialIndex: args.initialIndex,
            provider: args.provider,
          ),
          settings: settings,
        );
      case NexconnChatUIRoutes.filePreview:
        final args = settings.arguments;
        if (args is! NexconnFilePreviewRouteArguments) {
          return _invalidRoute(settings, 'Missing file preview arguments.');
        }
        return MaterialPageRoute<void>(
          builder: (_) => FilePreviewPage(fileMessage: args.fileMessage),
          settings: settings,
        );
      case NexconnChatUIRoutes.combineMessageDetail:
        final args = settings.arguments;
        if (args is! NexconnCombineMessageDetailRouteArguments) {
          return _invalidRoute(
            settings,
            'Missing combine message detail arguments.',
          );
        }
        return _combineMessageDetailRoute(settings, args);
      case NexconnChatUIRoutes.userProfile:
        final args = settings.arguments;
        if (args is! NexconnUserProfileRouteArguments) {
          return _invalidRoute(settings, 'Missing user profile arguments.');
        }
        return MaterialPageRoute<void>(
          builder: (_) => NexconnUserProfilePage(
            userId: args.userId,
            config: args.config,
            provider: args.provider,
          ),
          settings: settings,
        );
      case '/theme_settings':
        return MaterialPageRoute<void>(
          builder: (_) =>
              ThemeSettingsPage(themeProvider: widget.themeProvider),
          settings: settings,
        );
      case '/web':
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute<void>(
          builder: (_) => WebViewPage(
            url: (args?['url'] as String?) ?? 'https://www.nexconn.ai',
            title: args?['title'] as String?,
          ),
          settings: settings,
        );
      case '/video_player_page':
        final args = settings.arguments as Map<String, dynamic>?;
        final currentIndex = args?['currentIndex'] as int? ?? 0;
        final rawVideos = args?['videos'] as List<dynamic>? ?? const [];
        final videos = rawVideos.whereType<ShortVideoMessage>().toList();
        return MaterialPageRoute<void>(
          builder: (_) =>
              ShortVideoPreviewPage(videos: videos, initialIndex: currentIndex),
          settings: settings,
        );
      case '/at_people':
        final args = settings.arguments as Map<String, dynamic>?;
        final groupId = args?['groupId'] as String?;
        if (groupId == null || groupId.isEmpty) {
          return MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Missing group ID'))),
            settings: settings,
          );
        }
        return MaterialPageRoute<UserAtInfo>(
          builder: (_) => AtPeoplePage(
            groupId: groupId,
            currentUserId: widget.loginProvider.currentUserId,
          ),
          settings: settings,
        );
      case '/user_profile':
        final args = settings.arguments as Map<String, dynamic>?;
        final userId = args?['userId'] as String?;
        return MaterialPageRoute<void>(
          builder: (_) => NexconnUserProfilePage(
            userId: userId,
            config: NexconnUserProfilePageConfig(
              providerConfig: NexconnUserProfileProviderConfig(
                profileResolver: widget.userInfoProvider.getUserProfile,
                currentUserProfileResolver: (_) => widget.userInfoProvider
                    .getUserProfile(widget.loginProvider.currentUserId),
              ),
            ),
          ),
          settings: settings,
        );
    }
    return null;
  }

  Route<T> _invalidRoute<T>(RouteSettings settings, String message) {
    return MaterialPageRoute<T>(
      builder: (_) => Scaffold(body: Center(child: Text(message))),
      settings: settings,
    );
  }

  Route<void> _combineMessageDetailRoute(
    RouteSettings settings,
    NexconnCombineMessageDetailRouteArguments args,
  ) {
    final detail = CombineMessageDetailPage(
      message: args.message,
      config: args.config,
    );
    final child = args.audioPlayerProvider == null
        ? ChangeNotifierProvider<ChatProvider>.value(
            value: args.provider,
            child: detail,
          )
        : MultiProvider(
            providers: [
              ChangeNotifierProvider<ChatProvider>.value(value: args.provider),
              ChangeNotifierProvider<NexconnAudioPlayerProvider>.value(
                value: args.audioPlayerProvider!,
              ),
            ],
            child: detail,
          );
    return MaterialPageRoute<void>(builder: (_) => child, settings: settings);
  }

  Future<String?> _resolveChatTitle(
    BuildContext context,
    BaseChannel channel,
  ) async {
    final l10n = context.chatUIL10n;
    switch (channel.channelType) {
      case ChannelType.open:
        return l10n.channelOpenTitle(channel.channelId);
      case ChannelType.community:
        return l10n.channelCommunityTitle(channel.channelId);
      case ChannelType.group:
      case ChannelType.direct:
      case ChannelType.system:
        break;
    }
    final profile = await _resolveChatProfile(channel);
    final name = profile?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    if (channel.channelType == ChannelType.group) {
      return l10n.channelGroupTitle(channel.channelId);
    }
    if (channel.channelType == ChannelType.system) {
      return channel.channelId.trim().isEmpty
          ? l10n.channelSystemTitle
          : channel.channelId;
    }
    return channel.channelId;
  }

  Future<ChatProfileInfo?> _resolveChatProfile(
    BaseChannel channel, {
    Message? message,
  }) async {
    final userInfoProvider = widget.userInfoProvider;
    if (message != null) {
      final targetId = message.senderUserId?.trim();
      if (targetId == null || targetId.isEmpty) {
        return const ChatProfileInfo(id: '');
      }
      final userInfo = await userInfoProvider.getUserInfoSync(targetId);
      return ChatProfileInfo(
        id: targetId,
        name: userInfo?.name?.trim().isNotEmpty == true
            ? userInfo!.name
            : targetId,
        portraitUri: userInfo?.avatarUrl,
      );
    }

    final targetId = channel.channelId;
    if (channel.channelType == ChannelType.group) {
      final groupInfo = await userInfoProvider.getGroupInfoSync(targetId);
      return ChatProfileInfo(
        id: targetId,
        name: groupInfo?.groupName?.trim().isNotEmpty == true
            ? groupInfo!.groupName
            : targetId,
        portraitUri: groupInfo?.avatarUrl,
        extra: groupInfo?.introduction,
      );
    }

    final userInfo = await userInfoProvider.getUserInfoSync(targetId);
    return ChatProfileInfo(
      id: targetId,
      name: userInfo?.name?.trim().isNotEmpty == true
          ? userInfo!.name
          : targetId,
      portraitUri: userInfo?.avatarUrl,
    );
  }

  Future<MessageInputMentionCandidate?> _pickMentionCandidate(
    BuildContext context,
    BaseChannel channel,
  ) async {
    final result = await Navigator.of(context).pushNamed<UserAtInfo>(
      '/at_people',
      arguments: {'groupId': channel.channelId},
    );
    if (result == null) {
      return null;
    }
    return MessageInputMentionCandidate(
      userId: result.userId,
      displayName: result.name,
    );
  }
}

class _PublicStrings {
  final Locale locale;

  const _PublicStrings(this.locale);

  static _PublicStrings of(BuildContext context) {
    return _PublicStrings(Localizations.localeOf(context));
  }

  bool get _zh => locale.languageCode == 'zh';

  String get appTitle =>
      _zh ? 'Nexconn Chat UI 快速 Demo' : 'Nexconn Chat UI Quick Demo';
}
