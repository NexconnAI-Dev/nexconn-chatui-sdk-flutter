part of '../message_input_config.dart';

/// Describes one item in the MessageInput extension panel.
class MessageInputExtensionPlugin {
  /// Stable plugin id used by callbacks and custom builders.
  final String id;

  /// Display title; localization supplies a default when null for built-ins.
  final String? title;

  /// Material icon used when no custom asset or builder is provided.
  final IconData icon;

  /// Built-in plugin behavior type.
  final MessageInputExtensionPluginType type;

  /// Whether the plugin can be tapped.
  final bool enabled;

  /// Optional tooltip for accessibility and desktop hover.
  final String? tooltip;

  /// Text shown when the plugin is unavailable.
  final String? unavailableText;

  /// Custom tap handler; when set it takes ownership of the action.
  final MessageInputExtensionPluginTap? onTap;

  /// Permission hook scoped to this plugin.
  final MessageInputPermissionRequest? permissionRequest;

  /// Simple path resolver for media plugins.
  final MessageInputMediaPathResolver? mediaPathResolver;

  /// Media draft resolver for photo, video, camera, filming, and file plugins.
  final MessageInputMediaDraftResolver? mediaDraftResolver;

  /// Location resolver used by the location plugin.
  final MessageInputLocationDraftResolver? locationResolver;

  /// Custom grid item builder for this plugin.
  final MessageInputExtensionPluginBuilder? builder;

  /// Optional packaged asset used by the default grid item.
  final String? assetName;

  const MessageInputExtensionPlugin({
    required this.id,
    required this.title,
    required this.icon,
    this.type = MessageInputExtensionPluginType.custom,
    this.enabled = true,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName,
  });

  const MessageInputExtensionPlugin.photo({
    this.id = 'photo',
    this.title,
    this.icon = Icons.photo_outlined,
    bool? enabled,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName = 'NexconnLightIcon/Gallery.png',
  }) : enabled = enabled ?? true,
       type = MessageInputExtensionPluginType.photo;

  const MessageInputExtensionPlugin.video({
    this.id = 'video',
    this.title,
    this.icon = Icons.play_circle_outline,
    bool? enabled,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName = 'NexconnLightIcon/play_video.png',
  }) : enabled = enabled ?? true,
       type = MessageInputExtensionPluginType.video;

  const MessageInputExtensionPlugin.camera({
    this.id = 'camera',
    this.title,
    this.icon = Icons.photo_camera_outlined,
    bool? enabled,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName = 'NexconnLightIcon/Camera.png',
  }) : enabled = enabled ?? true,
       type = MessageInputExtensionPluginType.camera;

  const MessageInputExtensionPlugin.filming({
    this.id = 'filming',
    this.title,
    this.icon = Icons.videocam_outlined,
    bool? enabled,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName = 'NexconnLightIcon/filming.png',
  }) : enabled = enabled ?? true,
       type = MessageInputExtensionPluginType.filming;

  const MessageInputExtensionPlugin.file({
    this.id = 'file',
    this.title,
    this.icon = Icons.insert_drive_file_outlined,
    bool? enabled,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName = 'NexconnLightIcon/Document.png',
  }) : enabled = enabled ?? true,
       type = MessageInputExtensionPluginType.file;

  const MessageInputExtensionPlugin.location({
    this.id = 'location',
    this.title,
    this.icon = Icons.location_on_outlined,
    bool? enabled,
    this.tooltip,
    this.unavailableText,
    this.onTap,
    this.permissionRequest,
    this.mediaPathResolver,
    this.mediaDraftResolver,
    this.locationResolver,
    this.builder,
    this.assetName = 'NexconnLightIcon/Local.png',
  }) : enabled = enabled ?? onTap != null || locationResolver != null,
       type = MessageInputExtensionPluginType.location;

  /// Whether this plugin has a runnable action or default media behavior.
  bool get hasAction =>
      onTap != null ||
      mediaPathResolver != null ||
      mediaDraftResolver != null ||
      locationResolver != null ||
      builder != null ||
      _hasDefaultMediaAction;

  bool get _hasDefaultMediaAction {
    return switch (type) {
      MessageInputExtensionPluginType.photo ||
      MessageInputExtensionPluginType.video ||
      MessageInputExtensionPluginType.camera ||
      MessageInputExtensionPluginType.filming ||
      MessageInputExtensionPluginType.file => true,
      _ => false,
    };
  }
}
