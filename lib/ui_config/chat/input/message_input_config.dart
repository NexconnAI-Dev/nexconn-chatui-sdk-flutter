import 'dart:async';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../utils/constants.dart';

part 'media/message_input_media_config.dart';
part 'voice/message_input_voice_config.dart';
part 'mention/message_input_mention_config.dart';
part 'extension/message_input_extension_plugin_config.dart';
part 'panels/message_input_panel_config.dart';

/// Toolbar controls shown by MessageInputWidget.
enum MessageInputBarControl { voice, emoji, extension }

/// Built-in extension plugin type used by MessageInputWidget.
enum MessageInputExtensionPluginType {
  custom,
  photo,
  video,
  camera,
  filming,
  file,
  location,
}

/// Handles taps on an extension plugin.
typedef MessageInputExtensionPluginTap =
    FutureOr<void> Function(
      BuildContext context,
      MessageInputExtensionPlugin plugin,
    );

/// Requests permission before an extension plugin runs.
typedef MessageInputPermissionRequest =
    FutureOr<bool> Function(
      BuildContext context,
      MessageInputExtensionPlugin plugin,
    );

/// Resolves a local media path for an extension plugin.
typedef MessageInputMediaPathResolver =
    FutureOr<String?> Function(
      BuildContext context,
      MessageInputExtensionPlugin plugin,
    );

/// Builds one emoji item in the emoji panel.
typedef MessageInputEmojiItemBuilder =
    Widget Function(BuildContext context, String emoji, VoidCallback onTap);

/// Builds an action button in the emoji panel.
typedef MessageInputEmojiActionBuilder =
    Widget Function(BuildContext context, VoidCallback onTap);

/// Builds the reference-message preview above the input field.
typedef MessageInputReferencePreviewBuilder =
    Widget Function(
      BuildContext context,
      Message message,
      String senderName,
      String summary,
      VoidCallback onClose,
    );

/// Configuration for a MessageInput toolbar button.
class MessageInputButtonConfig {
  /// Icon shown when the control is inactive.
  final Widget? icon;

  /// Icon shown when the control is active.
  final Widget? activeIcon;

  /// Icon size used by the default toolbar button.
  final double size;

  /// Padding around the button.
  final EdgeInsets? padding;

  /// Inactive icon color.
  final Color? color;

  /// Active icon color.
  final Color? activeColor;

  /// Whether this toolbar control is visible.
  final bool visible;

  const MessageInputButtonConfig({
    this.icon,
    this.activeIcon,
    this.size = kInputFieldIconSize,
    this.padding,
    this.color,
    this.activeColor,
    this.visible = true,
  });
}

/// Configuration for the reference-message preview.
class MessageInputReferencePreviewConfig {
  /// Preview background color.
  final Color? backgroundColor;

  /// Preview content padding.
  final EdgeInsets? padding;

  /// Text style for sender and summary.
  final TextStyle? textStyle;

  /// Close icon override.
  final Widget? closeIcon;

  /// Custom preview builder.
  final MessageInputReferencePreviewBuilder? builder;

  const MessageInputReferencePreviewConfig({
    this.backgroundColor,
    this.padding,
    this.textStyle,
    this.closeIcon,
    this.builder,
  });
}

/// Top-level configuration for MessageInputWidget.
class MessageInputConfig {
  /// Text field placeholder override.
  final String? hintText;

  /// Whether voice input is available.
  final bool enableVoiceInput;

  /// Whether the emoji panel is available.
  final bool enableEmojiPanel;

  /// Whether the extension panel is available.
  final bool enableExtensionPanel;

  /// Toolbar control order.
  final List<MessageInputBarControl> toolbarControls;

  /// Extension panel plugins shown to the user.
  final List<MessageInputExtensionPlugin> extensionPlugins;

  /// Maximum visible text field lines.
  final int maxLines;

  /// Input area background color.
  final Color? backgroundColor;

  /// Text field decoration override.
  final InputDecoration? decoration;
  final String? voiceInputUnavailableText;
  final String? emptyExtensionPanelText;
  final List<String> emojiItems;

  /// Whether @ mention detection is enabled.
  final bool enableMention;

  /// Optional mention candidate resolver.
  final MessageInputMentionResolver? mentionResolver;

  /// Optional custom mention picker.
  final MessageInputMentionPicker? mentionPicker;

  /// Optional mention candidate row builder.
  final MessageInputMentionCandidateBuilder? mentionCandidateBuilder;
  final String? emptyMentionCandidatesText;

  /// Optional resolver that converts a recording path into a voice draft.
  final MessageInputVoiceDraftResolver? voiceDraftResolver;

  /// Optional recorder implementation; defaults to the built-in recorder.
  final MessageInputVoiceRecorder? voiceRecorder;

  /// Minimum accepted voice recording duration.
  final Duration minimumVoiceRecordingDuration;

  /// Maximum voice recording duration before auto-finish.
  final Duration maximumVoiceRecordingDuration;
  final String? voiceInputActionText;

  /// Global permission hook for extension plugins.
  final MessageInputPermissionRequest? onPermissionRequest;

  /// Per-control button configuration.
  final Map<MessageInputBarControl, MessageInputButtonConfig>
  toolbarButtonConfigs;

  /// Reference preview configuration.
  final MessageInputReferencePreviewConfig referencePreviewConfig;

  /// Emoji panel configuration.
  final MessageInputEmojiPanelConfig emojiPanelConfig;

  /// Extension panel configuration.
  final MessageInputExtensionPanelConfig extensionPanelConfig;

  const MessageInputConfig({
    this.hintText,
    this.enableVoiceInput = true,
    this.enableEmojiPanel = true,
    this.enableExtensionPanel = true,
    this.toolbarControls = const [
      MessageInputBarControl.voice,
      MessageInputBarControl.emoji,
      MessageInputBarControl.extension,
    ],
    this.extensionPlugins = defaultMessageInputExtensionPlugins,
    this.maxLines = 5,
    this.backgroundColor,
    this.decoration,
    this.voiceInputUnavailableText,
    this.emptyExtensionPanelText,
    this.enableMention = true,
    this.mentionResolver,
    this.mentionPicker,
    this.mentionCandidateBuilder,
    this.emptyMentionCandidatesText,
    this.voiceDraftResolver,
    this.voiceRecorder,
    this.minimumVoiceRecordingDuration = const Duration(seconds: 1),
    this.maximumVoiceRecordingDuration = const Duration(seconds: 60),
    this.voiceInputActionText,
    this.onPermissionRequest,
    this.toolbarButtonConfigs = const {},
    this.referencePreviewConfig = const MessageInputReferencePreviewConfig(),
    this.emojiPanelConfig = const MessageInputEmojiPanelConfig(),
    this.extensionPanelConfig = const MessageInputExtensionPanelConfig(),
    this.emojiItems = const [],
  });

  /// Whether the extension panel has any plugins to show.
  bool get hasExtensionPlugins => extensionPlugins.isNotEmpty;

  /// Returns whether [control] should be visible and enabled.
  bool isControlEnabled(MessageInputBarControl control) {
    if (toolbarButtonConfigs[control]?.visible == false) {
      return false;
    }
    return switch (control) {
      MessageInputBarControl.voice => enableVoiceInput,
      MessageInputBarControl.emoji => enableEmojiPanel,
      MessageInputBarControl.extension => enableExtensionPanel,
    };
  }

  /// Toolbar controls after visibility and feature flags are applied.
  List<MessageInputBarControl> get enabledToolbarControls {
    return toolbarControls.where(isControlEnabled).toList(growable: false);
  }

  /// Creates a copy with selected values replaced.
  MessageInputConfig copyWith({
    String? hintText,
    bool? enableVoiceInput,
    bool? enableEmojiPanel,
    bool? enableExtensionPanel,
    List<MessageInputBarControl>? toolbarControls,
    List<MessageInputExtensionPlugin>? extensionPlugins,
    int? maxLines,
    Color? backgroundColor,
    InputDecoration? decoration,
    String? voiceInputUnavailableText,
    String? emptyExtensionPanelText,
    List<String>? emojiItems,
    bool? enableMention,
    MessageInputMentionResolver? mentionResolver,
    MessageInputMentionPicker? mentionPicker,
    MessageInputMentionCandidateBuilder? mentionCandidateBuilder,
    String? emptyMentionCandidatesText,
    MessageInputVoiceDraftResolver? voiceDraftResolver,
    MessageInputVoiceRecorder? voiceRecorder,
    Duration? minimumVoiceRecordingDuration,
    Duration? maximumVoiceRecordingDuration,
    String? voiceInputActionText,
    MessageInputPermissionRequest? onPermissionRequest,
    Map<MessageInputBarControl, MessageInputButtonConfig>? toolbarButtonConfigs,
    MessageInputReferencePreviewConfig? referencePreviewConfig,
    MessageInputEmojiPanelConfig? emojiPanelConfig,
    MessageInputExtensionPanelConfig? extensionPanelConfig,
  }) {
    return MessageInputConfig(
      hintText: hintText ?? this.hintText,
      enableVoiceInput: enableVoiceInput ?? this.enableVoiceInput,
      enableEmojiPanel: enableEmojiPanel ?? this.enableEmojiPanel,
      enableExtensionPanel: enableExtensionPanel ?? this.enableExtensionPanel,
      toolbarControls: toolbarControls ?? this.toolbarControls,
      extensionPlugins: extensionPlugins ?? this.extensionPlugins,
      maxLines: maxLines ?? this.maxLines,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      decoration: decoration ?? this.decoration,
      voiceInputUnavailableText:
          voiceInputUnavailableText ?? this.voiceInputUnavailableText,
      emptyExtensionPanelText:
          emptyExtensionPanelText ?? this.emptyExtensionPanelText,
      enableMention: enableMention ?? this.enableMention,
      mentionResolver: mentionResolver ?? this.mentionResolver,
      mentionPicker: mentionPicker ?? this.mentionPicker,
      mentionCandidateBuilder:
          mentionCandidateBuilder ?? this.mentionCandidateBuilder,
      emptyMentionCandidatesText:
          emptyMentionCandidatesText ?? this.emptyMentionCandidatesText,
      voiceDraftResolver: voiceDraftResolver ?? this.voiceDraftResolver,
      voiceRecorder: voiceRecorder ?? this.voiceRecorder,
      minimumVoiceRecordingDuration:
          minimumVoiceRecordingDuration ?? this.minimumVoiceRecordingDuration,
      maximumVoiceRecordingDuration:
          maximumVoiceRecordingDuration ?? this.maximumVoiceRecordingDuration,
      voiceInputActionText: voiceInputActionText ?? this.voiceInputActionText,
      onPermissionRequest: onPermissionRequest ?? this.onPermissionRequest,
      toolbarButtonConfigs: toolbarButtonConfigs ?? this.toolbarButtonConfigs,
      referencePreviewConfig:
          referencePreviewConfig ?? this.referencePreviewConfig,
      emojiPanelConfig: emojiPanelConfig ?? this.emojiPanelConfig,
      extensionPanelConfig: extensionPanelConfig ?? this.extensionPanelConfig,
      emojiItems: emojiItems ?? this.emojiItems,
    );
  }
}

/// Default extension plugins for photo, video, camera, filming, and file.
const List<MessageInputExtensionPlugin> defaultMessageInputExtensionPlugins = [
  MessageInputExtensionPlugin.photo(),
  MessageInputExtensionPlugin.video(),
  MessageInputExtensionPlugin.camera(),
  MessageInputExtensionPlugin.filming(),
  MessageInputExtensionPlugin.file(),
];
