// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart' as pm;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart';

import '../../../models/chat_profile_info.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/channel_provider.dart';
import '../../../providers/engine_provider.dart';
import '../../../providers/message_input_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../routes/nexconn_chat_ui_routes.dart';
import '../../../ui_config/chat/input/message_input_config.dart';
import '../../../utils/chatui_asset.dart';
import '../../../utils/chatui_image_util.dart';
import '../../../utils/constants.dart';
import '../../../utils/message_content_util.dart';
import '../page/message_list_controller.dart';
import '../../chat_extras/forward_select_page.dart';
import '../../../l10n/nexconn_chat_ui_l10n.dart';

part 'core/message_input_consumer.dart';
part 'core/multi_select_bar.dart';
part 'core/reference_preview.dart';
part 'core/input_area.dart';
part 'core/input_toolbar_controls.dart';
part 'panels/emoji_panel.dart';
part 'panels/emoji_panel_controls.dart';
part 'panels/extension_panel.dart';
part 'actions/plugin_actions.dart';
part 'media/picked_input_media.dart';
part 'media/media_picker.dart';
part 'media/media_permission.dart';
part 'actions/plugin_permissions.dart';
part 'voice/voice_recording.dart';
part 'voice/voice_feedback.dart';
part 'core/input_feedback.dart';
part 'core/input_text_editing.dart';
part 'core/draft_sync.dart';
part 'actions/mention_picker.dart';

/// Input bar for text, mentions, references, voice, emoji, and extension actions.
class MessageInputWidget extends StatefulWidget {
  static const Key referenceImagePreviewKey = ValueKey(
    'message-input-reference-image-preview',
  );

  final BaseChannel channel;
  final MessageInputConfig config;
  final ChatProfileProvider? profileProvider;
  final ChannelProvider Function(BuildContext context)?
  forwardChannelProviderBuilder;

  const MessageInputWidget({
    super.key,
    required this.channel,
    required this.config,
    this.profileProvider,
    this.forwardChannelProviderBuilder,
  });

  @override
  State<MessageInputWidget> createState() => _MessageInputWidgetState();
}

class _MessageInputWidgetState extends State<MessageInputWidget>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _textScrollController = ScrollController();
  final PageController _emojiPageController = PageController();
  final PageController _extensionPageController = PageController();
  static final Map<String, MessageInputMode> _channelInputModes =
      <String, MessageInputMode>{};
  MessageInputProvider? _ownedInputProvider;
  MessageInputProvider? _listenedInputProvider;
  Timer? _draftSaveTimer;
  Timer? _typingTimer;
  Timer? _voiceMaximumDurationTimer;
  Timer? _inputTextScrollTimer;
  Timer? _chatBottomStabilizeTimer;
  Timer? _keyboardMetricsBottomStabilizeTimer;
  MessageInputVoiceRecorder? _activeVoiceRecorder;
  Future<void>? _voiceStartOperation;
  String? _lastAutoFocusedReferenceKey;
  bool _didSyncInitialDraft = false;
  bool _didResolveInputProvider = false;
  bool _isPickingMention = false;
  bool _syncingFocusForInputMode = false;
  bool _pendingInputTextScroll = false;
  bool _pendingKeepBottomOnComposerResize = false;
  bool _pendingKeyboardMetricsKeepBottom = false;
  bool _composerResizeKeepBottomResetScheduled = false;
  bool _keyboardKeepBottomIntent = false;

  static const Duration _draftSaveDelay = Duration(milliseconds: 350);
  static const Duration _typingSendDelay = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleInputTextChanged);
    _focusNode.addListener(_handleComposerFocusChanged);
    _emojiPageController.addListener(_handleEmojiPageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didResolveInputProvider) {
      return;
    }
    _didResolveInputProvider = true;
    if (_providedInputProvider() == null) {
      _ownedInputProvider = MessageInputProvider();
    }
    _syncInitialDraft();
    _bindInputProviderStateListener();
    _scheduleEmojiPageLoad();
  }

  @override
  void didUpdateWidget(covariant MessageInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isDifferentChannel(oldWidget.channel, widget.channel)) {
      _draftSaveTimer?.cancel();
      _typingTimer?.cancel();
      _didSyncInitialDraft = false;
      _syncInitialDraft(clearReference: true);
    } else if (oldWidget.channel.draft != widget.channel.draft) {
      _didSyncInitialDraft = false;
      _syncInitialDraft();
    }
    if (oldWidget.config.emojiItems != widget.config.emojiItems ||
        oldWidget.config.emojiPanelConfig != widget.config.emojiPanelConfig) {
      _scheduleEmojiPageLoad();
    }
    final inputProvider = _inputProvider;
    if (!_isModeAvailable(inputProvider.mode, widget.config)) {
      inputProvider.setMode(MessageInputMode.initial);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftSaveTimer?.cancel();
    _typingTimer?.cancel();
    _voiceMaximumDurationTimer?.cancel();
    _inputTextScrollTimer?.cancel();
    _chatBottomStabilizeTimer?.cancel();
    _keyboardMetricsBottomStabilizeTimer?.cancel();
    unawaited(_cancelActiveVoiceRecording());
    _emojiPageController.removeListener(_handleEmojiPageChanged);
    _controller.removeListener(_handleInputTextChanged);
    _focusNode.removeListener(_handleComposerFocusChanged);
    _emojiPageController.dispose();
    _extensionPageController.dispose();
    _textScrollController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _listenedInputProvider?.removeListener(_handleInputProviderStateChanged);
    _listenedInputProvider = null;
    _ownedInputProvider?.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted || !_focusNode.hasFocus) {
      return;
    }
    if (!_keyboardKeepBottomIntent && !_shouldKeepBottomForInputTransition()) {
      return;
    }
    _keyboardKeepBottomIntent = true;
    _scheduleKeyboardMetricsKeepBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ownedInputProvider = _ownedInputProvider;
    Widget child;
    if (ownedInputProvider != null) {
      child = ChangeNotifierProvider<MessageInputProvider>.value(
        value: ownedInputProvider,
        child: _buildInputConsumer(),
      );
    } else {
      child = _buildInputConsumer();
    }
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _handleComposerSizeChanged();
        return false;
      },
      child: SizeChangedLayoutNotifier(child: child),
    );
  }

  void _bindInputProviderStateListener() {
    final provider = _inputProvider;
    if (identical(_listenedInputProvider, provider)) {
      return;
    }
    _listenedInputProvider?.removeListener(_handleInputProviderStateChanged);
    _listenedInputProvider = provider;
    provider.addListener(_handleInputProviderStateChanged);
    _handleInputProviderStateChanged();
  }

  void _handleInputProviderStateChanged() {
    final provider = _listenedInputProvider;
    if (provider == null) {
      return;
    }
    final mode = provider.mode;
    _channelInputModes[_channelInputModeKey(widget.channel)] = mode;
    _syncKeyboardToInputMode(mode);
  }

  void _syncKeyboardToInputMode(MessageInputMode mode) {
    if (!mounted || _syncingFocusForInputMode) {
      return;
    }
    _syncingFocusForInputMode = true;
    try {
      if (mode == MessageInputMode.text) {
        if (!_focusNode.hasFocus && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
        return;
      }
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    } finally {
      _syncingFocusForInputMode = false;
    }
  }

  String _channelInputModeKey(BaseChannel channel) {
    final subChannelId = channel.channelIdentifier.subChannelId;
    final normalizedSubChannelId = subChannelId == null || subChannelId.isEmpty
        ? ''
        : subChannelId;
    return '${channel.channelType.name}:${channel.channelId}:$normalizedSubChannelId';
  }
}
