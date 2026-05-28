part of '../message_input_widget.dart';

extension _MessageInputPluginPermissions on _MessageInputWidgetState {
  bool _canSendLocationWithPlugin(MessageInputExtensionPlugin plugin) {
    return plugin.type == MessageInputExtensionPluginType.location &&
        plugin.locationResolver != null;
  }

  Future<bool> _requestPluginPermission(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) async {
    final request =
        plugin.permissionRequest ?? widget.config.onPermissionRequest;
    if (request == null) {
      return true;
    }
    return await request(context, plugin);
  }
}
