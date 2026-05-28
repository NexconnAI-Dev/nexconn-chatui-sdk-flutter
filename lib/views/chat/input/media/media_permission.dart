part of '../message_input_widget.dart';

@visibleForTesting
bool messageInputPluginNeedsPhotoLibraryPermission(
  MessageInputExtensionPlugin plugin, {
  required bool usesDirectAndroidVideoCapture,
}) {
  return plugin.type == MessageInputExtensionPluginType.photo ||
      plugin.type == MessageInputExtensionPluginType.video ||
      (plugin.type == MessageInputExtensionPluginType.filming &&
          !usesDirectAndroidVideoCapture);
}

extension _MessageInputMediaPermission on _MessageInputWidgetState {
  Future<bool> _requestDefaultMediaPermission(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) async {
    if (messageInputPluginNeedsPhotoLibraryPermission(
      plugin,
      usesDirectAndroidVideoCapture: _usesDirectAndroidVideoCapture(),
    )) {
      final permission = await pm.PhotoManager.requestPermissionExtend();
      if (permission.isAuth || permission.hasAccess) {
        return true;
      }
      if (context.mounted) {
        _showSnackBar(context, context.chatUIL10n.messageInputPermissionDenied);
      }
      return false;
    }

    final permissions = _defaultPermissionsForPlugin(plugin);
    for (final permission in permissions) {
      final status = await permission.request();
      if (status.isGranted || status.isLimited) {
        continue;
      }
      if (context.mounted) {
        _showSnackBar(context, context.chatUIL10n.messageInputPermissionDenied);
      }
      return false;
    }
    return true;
  }

  List<Permission> _defaultPermissionsForPlugin(
    MessageInputExtensionPlugin plugin,
  ) {
    return switch (plugin.type) {
      MessageInputExtensionPluginType.camera => [Permission.camera],
      MessageInputExtensionPluginType.filming => [
        Permission.camera,
        Permission.microphone,
      ],
      MessageInputExtensionPluginType.file => const [],
      _ => const [],
    };
  }

  bool _usesDirectAndroidVideoCapture() => !kIsWeb && Platform.isAndroid;
}
