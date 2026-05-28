import 'package:flutter/material.dart';

const String _packageName = 'ai_nexconn_chatui_plugin';

class ChatUIAsset {
  const ChatUIAsset._();

  static Widget image(
    String name, {
    double? width,
    double? height,
    Color? color,
    BoxFit fit = BoxFit.cover,
  }) {
    return Image.asset(
      path(name),
      package: _packageName,
      width: width,
      height: height,
      color: color,
      fit: fit,
    );
  }

  static AssetImage provider(String name) {
    return AssetImage(path(name), package: _packageName);
  }

  static String path(String name) {
    return name.startsWith('assets/') ? name : 'assets/$name';
  }
}
