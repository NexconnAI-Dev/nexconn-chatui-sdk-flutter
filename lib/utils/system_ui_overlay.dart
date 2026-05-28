import 'package:flutter/services.dart';

SystemUiOverlayStyle systemUiOverlayStyleForBackground(Color backgroundColor) {
  final iconBrightness = backgroundColor.computeLuminance() > 0.5
      ? Brightness.dark
      : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: iconBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
  );
}
