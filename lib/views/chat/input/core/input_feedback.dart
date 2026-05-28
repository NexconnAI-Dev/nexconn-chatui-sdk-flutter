part of '../message_input_widget.dart';

extension _MessageInputInputFeedback on _MessageInputWidgetState {
  String _pluginTitle(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) {
    if (plugin.title != null) {
      return plugin.title!;
    }
    final l10n = context.chatUIL10n;
    return switch (plugin.type) {
      MessageInputExtensionPluginType.photo => l10n.messageInputPhotosTitle,
      MessageInputExtensionPluginType.video => l10n.messageInputVideoTitle,
      MessageInputExtensionPluginType.camera => l10n.messageInputCameraTitle,
      MessageInputExtensionPluginType.filming => l10n.messageInputFilmingTitle,
      MessageInputExtensionPluginType.file => l10n.messageInputFilesTitle,
      MessageInputExtensionPluginType.location =>
        l10n.messageInputLocationTitle,
      MessageInputExtensionPluginType.custom => plugin.id,
    };
  }

  String _extensionPluginUnavailableText(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) {
    if (plugin.unavailableText != null) {
      return plugin.unavailableText!;
    }
    final l10n = context.chatUIL10n;
    return switch (plugin.type) {
      MessageInputExtensionPluginType.photo =>
        l10n.messageInputPhotoPickerUnavailable,
      MessageInputExtensionPluginType.video =>
        l10n.messageInputVideoPickerUnavailable,
      MessageInputExtensionPluginType.camera =>
        l10n.messageInputCameraUnavailable,
      MessageInputExtensionPluginType.filming =>
        l10n.messageInputFilmingUnavailable,
      MessageInputExtensionPluginType.file =>
        l10n.messageInputFilePickerUnavailable,
      MessageInputExtensionPluginType.location =>
        l10n.messageInputLocationPickerUnavailable,
      MessageInputExtensionPluginType.custom =>
        l10n.messageInputPluginUnavailable,
    };
  }

  void _showUnavailablePlugin(
    BuildContext context,
    MessageInputExtensionPlugin plugin,
  ) {
    _showSnackBar(context, _extensionPluginUnavailableText(context, plugin));
  }

  void _showSnackBar(BuildContext context, String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  void _showEmptyTextWarning(BuildContext context, MessageInputProvider input) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.chatUIL10n.messageInputEmptyTextWarning),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
    input.setMode(MessageInputMode.text);
  }
}
