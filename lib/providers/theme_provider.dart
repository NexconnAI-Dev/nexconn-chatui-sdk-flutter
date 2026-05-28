import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Theme mode used by NexconnThemeProvider.
enum NexconnThemeMode { light, dark, custom }

/// Color tokens used by built-in ChatUI widgets.
class NexconnThemeTokens {
  /// Brightness used by generated ThemeData.
  final Brightness brightness;

  /// Page background color.
  final Color pageBackgroundColor;

  /// Default surface color.
  final Color surfaceColor;
  final Color surfaceMutedColor;
  final Color panelColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color dividerColor;
  final Color primaryColor;
  final Color destructiveColor;
  final Color successColor;
  final Color overlayColor;

  const NexconnThemeTokens({
    required this.brightness,
    required this.pageBackgroundColor,
    required this.surfaceColor,
    required this.surfaceMutedColor,
    required this.panelColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.dividerColor,
    required this.primaryColor,
    required this.destructiveColor,
    required this.successColor,
    required this.overlayColor,
  });

  static const NexconnThemeTokens light = NexconnThemeTokens(
    brightness: Brightness.light,
    pageBackgroundColor: Color(0xFFF5F6F9),
    surfaceColor: Color(0xFFF5F6F9),
    surfaceMutedColor: Color(0xFFF5F6F9),
    panelColor: Color(0xFFFFFFFF),
    primaryTextColor: Color(0xFF111111),
    secondaryTextColor: Color(0xFF8C8C8C),
    dividerColor: Color(0xFFE6E6E6),
    primaryColor: Color(0xFF4679FF),
    destructiveColor: Color(0xFFE44C43),
    successColor: Color(0xFF2DB26B),
    overlayColor: Color(0x14000000),
  );

  static const NexconnThemeTokens dark = NexconnThemeTokens(
    brightness: Brightness.dark,
    pageBackgroundColor: Color(0xFF111111),
    surfaceColor: Color(0xFF1D1D1D),
    surfaceMutedColor: Color(0xFF252629),
    panelColor: Color(0xFF2B2D31),
    primaryTextColor: Color(0xFFEDEDED),
    secondaryTextColor: Color(0xFF9EA3AA),
    dividerColor: Color(0xFF2D2D2D),
    primaryColor: Color(0xFF608DFF),
    destructiveColor: Color(0xFFFD6B6B),
    successColor: Color(0xFF46D98A),
    overlayColor: Color(0x22000000),
  );

  /// Creates a copy with selected token values replaced.
  NexconnThemeTokens copyWith({
    Brightness? brightness,
    Color? pageBackgroundColor,
    Color? surfaceColor,
    Color? surfaceMutedColor,
    Color? panelColor,
    Color? primaryTextColor,
    Color? secondaryTextColor,
    Color? dividerColor,
    Color? primaryColor,
    Color? destructiveColor,
    Color? successColor,
    Color? overlayColor,
  }) {
    return NexconnThemeTokens(
      brightness: brightness ?? this.brightness,
      pageBackgroundColor: pageBackgroundColor ?? this.pageBackgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      surfaceMutedColor: surfaceMutedColor ?? this.surfaceMutedColor,
      panelColor: panelColor ?? this.panelColor,
      primaryTextColor: primaryTextColor ?? this.primaryTextColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      dividerColor: dividerColor ?? this.dividerColor,
      primaryColor: primaryColor ?? this.primaryColor,
      destructiveColor: destructiveColor ?? this.destructiveColor,
      successColor: successColor ?? this.successColor,
      overlayColor: overlayColor ?? this.overlayColor,
    );
  }
}

/// Provides ThemeData and ChatUI color tokens to the widget tree.
class NexconnThemeProvider with ChangeNotifier {
  NexconnThemeMode _mode;
  NexconnThemeTokens? _customTokens;

  NexconnThemeProvider({NexconnThemeMode mode = NexconnThemeMode.light})
    : _mode = mode;

  /// Current theme mode.
  NexconnThemeMode get mode => _mode;

  /// Active token set for the current mode.
  NexconnThemeTokens get tokens {
    return switch (_mode) {
      NexconnThemeMode.light => NexconnThemeTokens.light,
      NexconnThemeMode.dark => NexconnThemeTokens.dark,
      NexconnThemeMode.custom => _customTokens ?? NexconnThemeTokens.light,
    };
  }

  /// Whether the active tokens use dark brightness.
  bool get isDark => tokens.brightness == Brightness.dark;

  /// Active page background color.
  Color get backgroundColor => tokens.pageBackgroundColor;

  Color get surfaceColor => tokens.surfaceColor;

  Color get surfaceMutedColor => tokens.surfaceMutedColor;

  Color get panelColor => tokens.panelColor;

  Color get primaryTextColor => tokens.primaryTextColor;

  Color get secondaryTextColor => tokens.secondaryTextColor;

  Color get dividerColor => tokens.dividerColor;

  Color get primaryColor => tokens.primaryColor;

  Color get destructiveColor => tokens.destructiveColor;

  Color get successColor => tokens.successColor;

  Color get overlayColor => tokens.overlayColor;

  /// Builds Flutter ThemeData from the active ChatUI tokens.
  ThemeData themeData({
    TargetPlatform? platform,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    return legacyThemeData(
      tokens: tokens,
      platform: platform,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );
  }

  /// Builds Flutter ThemeData from explicit ChatUI tokens.
  static ThemeData legacyThemeData({
    NexconnThemeTokens tokens = NexconnThemeTokens.light,
    TargetPlatform? platform,
    String? fontFamily,
    List<String>? fontFamilyFallback,
  }) {
    final targetPlatform = platform ?? defaultTargetPlatform;
    return ThemeData(
      brightness: tokens.brightness,
      platform: targetPlatform,
      primarySwatch: Colors.blue,
      primaryColor: tokens.primaryColor,
      scaffoldBackgroundColor: tokens.pageBackgroundColor,
      canvasColor: tokens.pageBackgroundColor,
      cardColor: tokens.panelColor,
      dividerColor: tokens.dividerColor,
      colorScheme: _colorSchemeFromTokens(tokens),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.black,
      ),
      typography: Typography.material2014(platform: targetPlatform),
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      useMaterial3: false,
    );
  }

  static ColorScheme _colorSchemeFromTokens(NexconnThemeTokens tokens) {
    final onPrimary = tokens.brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    if (tokens.brightness == Brightness.dark) {
      return ColorScheme.dark(
        primary: tokens.primaryColor,
        onPrimary: onPrimary,
        secondary: tokens.primaryColor,
        onSecondary: onPrimary,
        surface: tokens.panelColor,
        onSurface: tokens.primaryTextColor,
        error: tokens.destructiveColor,
        onError: Colors.white,
      );
    }
    return ColorScheme.light(
      primary: tokens.primaryColor,
      onPrimary: onPrimary,
      secondary: tokens.primaryColor,
      onSecondary: onPrimary,
      surface: tokens.panelColor,
      onSurface: tokens.primaryTextColor,
      error: tokens.destructiveColor,
      onError: Colors.white,
    );
  }

  void setMode(NexconnThemeMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    if (mode != NexconnThemeMode.custom) {
      _customTokens = null;
    }
    notifyListeners();
  }

  void setCustomTheme(NexconnThemeTokens tokens) {
    _customTokens = tokens;
    _mode = NexconnThemeMode.custom;
    notifyListeners();
  }

  static NexconnThemeTokens resolveTokens(
    BuildContext context, {
    bool listen = true,
  }) {
    try {
      final provider = Provider.of<NexconnThemeProvider>(
        context,
        listen: listen,
      );
      return provider.tokens;
    } on ProviderNotFoundException {
      return NexconnThemeTokens.light;
    }
  }
}
