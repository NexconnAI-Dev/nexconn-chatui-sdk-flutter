import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/engine_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/video_playback_backend.dart';

/// Injects the shared EngineProvider and NexconnThemeProvider used by ChatUI pages.
class NexconnChatUIProviders extends StatelessWidget {
  final EngineProvider engineProvider;
  final NexconnThemeProvider themeProvider;
  final Widget child;

  NexconnChatUIProviders({
    super.key,
    required this.engineProvider,
    NexconnThemeProvider? themeProvider,
    required this.child,
  }) : themeProvider = themeProvider ?? _defaultThemeProvider {
    NexconnChatUIVideoPlayback.ensureInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EngineProvider>.value(value: engineProvider),
        ChangeNotifierProvider<NexconnThemeProvider>.value(
          value: themeProvider,
        ),
      ],
      child: Consumer<NexconnThemeProvider>(
        builder: (context, provider, child) {
          return Theme(data: provider.themeData(), child: child!);
        },
        child: child,
      ),
    );
  }
}

final NexconnThemeProvider _defaultThemeProvider = NexconnThemeProvider();
