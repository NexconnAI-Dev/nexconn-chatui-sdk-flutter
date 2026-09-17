import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Current visible mode of the MessageInputWidget.
enum MessageInputMode { initial, text, voice, emoji, extension }

/// Voice recording send/cancel state for the input area.
enum MessageInputVoiceRecordingState { idle, sending, canceling }

/// Selected mention inserted into a message draft.
class MessageInputMention {
  /// Nexconn user id carried in message mentioned info.
  final String userId;

  /// Display name inserted into the text field.
  final String displayName;

  const MessageInputMention({required this.userId, required this.displayName});

  /// Text inserted into the input draft.
  String get insertedText => '@$displayName ';
}

/// Stores message input mode, text draft, reference message, voice state, and mentions.
class MessageInputProvider with ChangeNotifier {
  MessageInputMode _mode = MessageInputMode.initial;
  String _draft = '';
  Message? _referenceMessage;
  Message? _editingMessage;
  String? _draftBeforeEditing;
  Message? _referenceBeforeEditing;
  MessageInputMode? _modeBeforeEditing;
  bool _editExpanded = false;
  List<MessageInputMention>? _mentionsBeforeEditing;
  List<String> _editingFallbackMentionUserIds = const <String>[];
  String? _editingFallbackMentionDraft;
  int _editingRevision = 0;
  List<MessageInputMention> _mentions = const <MessageInputMention>[];
  List<List<String>> _emojiPages = const <List<String>>[];
  int _currentEmojiPage = 0;
  int _emojiRowCount = 3;
  int _emojiColumnCount = 8;
  MessageInputVoiceRecordingState _voiceRecordingState =
      MessageInputVoiceRecordingState.idle;

  /// Current input mode.
  MessageInputMode get mode => _mode;

  /// Current text draft.
  String get draft => _draft;

  /// Message currently referenced by the input.
  Message? get referenceMessage => _referenceMessage;

  /// Message currently being edited, if any.
  Message? get editingMessage => _editingMessage;

  bool get isEditing => _editingMessage != null;

  /// Whether the active edit session is shown in the full-screen editor.
  bool get editExpanded => _editExpanded;

  /// Switches the active edit session between the inline bar and the
  /// full-screen editor overlay.
  void setEditExpanded(bool expanded) {
    if (!_isEditingAvailableForExpansion && expanded) {
      return;
    }
    if (_editExpanded == expanded) {
      return;
    }
    _editExpanded = expanded;
    notifyListeners();
  }

  bool get _isEditingAvailableForExpansion => _editingMessage != null;

  /// Increments whenever the active edit session changes.
  int get editingRevision => _editingRevision;

  /// Normal text draft captured before entering the current edit session.
  String? get draftBeforeEditing => _draftBeforeEditing;

  /// Mentions retained in the current draft.
  List<MessageInputMention> get mentions => List.unmodifiable(_mentions);

  /// Emoji pages prepared for the emoji panel.
  List<List<String>> get emojiPages => List.unmodifiable(_emojiPages);

  /// Current emoji page index.
  int get currentEmojiPage => _currentEmojiPage;

  /// Current voice recording state.
  MessageInputVoiceRecordingState get voiceRecordingState =>
      _voiceRecordingState;

  /// Whether a voice recording interaction is active.
  bool get isVoiceRecording =>
      _voiceRecordingState != MessageInputVoiceRecordingState.idle;

  /// Whether the active voice recording is being canceled.
  bool get isVoiceCanceling =>
      _voiceRecordingState == MessageInputVoiceRecordingState.canceling;

  /// User ids extracted from retained mentions.
  List<String> get mentionUserIds {
    final explicit = _mentions
        .map((mention) => mention.userId)
        .toList(growable: false);
    if (explicit.isNotEmpty ||
        !isEditing ||
        _draft != _editingFallbackMentionDraft) {
      return explicit;
    }
    return List<String>.unmodifiable(_editingFallbackMentionUserIds);
  }

  /// Whether the draft contains non-whitespace text.
  bool get hasDraft => _draft.trim().isNotEmpty;

  /// Whether a reference message is active.
  bool get hasReferenceMessage => _referenceMessage != null;

  /// Whether the emoji panel has more than one page.
  bool get hasMultipleEmojiPages => _emojiPages.length > 1;

  /// Updates the current input mode and notifies listeners.
  void setMode(MessageInputMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  /// Updates the current input mode without notifying listeners.
  void setModeSilently(MessageInputMode mode) {
    _mode = mode;
  }

  /// Toggles [mode], returning to text mode when already selected.
  void toggleMode(MessageInputMode mode) {
    setMode(_mode == mode ? MessageInputMode.text : mode);
  }

  /// Updates voice recording state.
  void setVoiceRecordingState(MessageInputVoiceRecordingState state) {
    if (_voiceRecordingState == state) {
      return;
    }
    _voiceRecordingState = state;
    notifyListeners();
  }

  /// Resets voice recording state to idle.
  void clearVoiceRecordingState() {
    setVoiceRecordingState(MessageInputVoiceRecordingState.idle);
  }

  /// Updates the text draft and prunes mentions no longer present.
  void updateDraft(String value) {
    final normalizedMentions = _normalizeMentions(value);
    final didMentionChange = !_sameMentions(_mentions, normalizedMentions);
    if (_draft == value) {
      if (didMentionChange) {
        _mentions = normalizedMentions;
        notifyListeners();
      }
      return;
    }
    _draft = value;
    _mentions = normalizedMentions;
    notifyListeners();
  }

  /// Updates the text draft without notifying listeners.
  void updateDraftSilently(String value) {
    _draft = value;
    _mentions = _normalizeMentions(value);
  }

  /// Clears the current draft.
  void clearDraft() {
    updateDraft('');
  }

  /// Adds a mention to the current draft state.
  void addMention(String userId, String displayName) {
    _mentions = [
      ..._mentions,
      MessageInputMention(userId: userId, displayName: displayName),
    ];
    notifyListeners();
  }

  /// Clears all retained mentions.
  void clearMentions() {
    if (_mentions.isEmpty) {
      return;
    }
    _mentions = const <MessageInputMention>[];
    notifyListeners();
  }

  /// Sets the active reference message.
  void setReferenceMessage(Message? message) {
    if (_referenceMessage == message) {
      return;
    }
    _referenceMessage = message;
    notifyListeners();
  }

  /// Restores a referenced-message draft before listeners are attached.
  void setReferenceMessageSilently(Message? message) {
    _referenceMessage = message;
  }

  /// Clears the active reference message.
  void clearReferenceMessage() {
    if (_referenceMessage == null) {
      return;
    }
    _referenceMessage = null;
    notifyListeners();
  }

  /// Enters edit mode while preserving the complete normal composer state.
  void startEditing(
    Message message, {
    String? content,
    List<String>? mentionUserIds,
  }) {
    if (identical(_editingMessage, message) && content == null) return;
    if (_editingMessage == null) {
      _draftBeforeEditing = _draft;
      _referenceBeforeEditing = _referenceMessage;
      _modeBeforeEditing = _mode;
      _mentionsBeforeEditing = List<MessageInputMention>.of(_mentions);
    }
    final editingContent = content ?? _messageContent(message);
    _editingMessage = message;
    _editExpanded = false;
    _referenceMessage = null;
    _mode = MessageInputMode.text;
    _draft = editingContent;
    final editingMentionUserIds =
        mentionUserIds ?? _messageMentionUserIds(message);
    _mentions = _editingMentionsFromContent(
      editingContent,
      editingMentionUserIds,
    );
    _editingFallbackMentionUserIds = List<String>.unmodifiable(
      editingMentionUserIds,
    );
    _editingFallbackMentionDraft = editingContent;
    _editingRevision++;
    notifyListeners();
  }

  void clearEditing({bool restoreDraft = true}) {
    if (_editingMessage == null) return;
    _editingMessage = null;
    _editExpanded = false;
    if (restoreDraft) {
      _draft = _draftBeforeEditing ?? '';
      _referenceMessage = _referenceBeforeEditing;
      _mode = _modeBeforeEditing ?? MessageInputMode.text;
      _mentions = List<MessageInputMention>.of(
        _mentionsBeforeEditing ?? const <MessageInputMention>[],
      );
    } else {
      _draft = '';
      _referenceMessage = null;
      _mode = MessageInputMode.text;
      _mentions = const <MessageInputMention>[];
    }
    _draftBeforeEditing = null;
    _referenceBeforeEditing = null;
    _modeBeforeEditing = null;
    _mentionsBeforeEditing = null;
    _editingFallbackMentionUserIds = const <String>[];
    _editingFallbackMentionDraft = null;
    _editingRevision++;
    notifyListeners();
  }

  /// Sets the current emoji page index.
  void setCurrentEmojiPage(int page) {
    final normalizedPage = page.clamp(0, _lastEmojiPageIndex).toInt();
    if (_currentEmojiPage == normalizedPage) {
      return;
    }
    _currentEmojiPage = normalizedPage;
    notifyListeners();
  }

  /// Loads custom or bundled emoji pages.
  Future<void> loadEmojis({
    int? rowCount,
    int? columnCount,
    List<String>? customEmojis,
  }) async {
    if (rowCount != null) {
      _emojiRowCount = rowCount;
    }
    if (columnCount != null) {
      _emojiColumnCount = columnCount;
    }
    final emojis = customEmojis == null || customEmojis.isEmpty
        ? await _loadBundledEmojis()
        : customEmojis;
    _processEmojiPages(emojis.isEmpty ? _fallbackEmojis : emojis);
    notifyListeners();
  }

  /// Resets input state for a new channel and notifies listeners.
  void resetForChannel({
    String draft = '',
    MessageInputMode mode = MessageInputMode.initial,
  }) {
    if (_resetForChannel(draft: draft, mode: mode)) {
      notifyListeners();
    }
  }

  /// Resets input state for a new channel without notifying listeners.
  void resetForChannelSilently({
    String draft = '',
    MessageInputMode mode = MessageInputMode.initial,
  }) {
    _resetForChannel(draft: draft, mode: mode);
  }

  bool _resetForChannel({
    required String draft,
    required MessageInputMode mode,
  }) {
    final didChangeDraft = _draft != draft;
    final didChangeMode = _mode != mode;
    final didChangeReference = _referenceMessage != null;
    final didChangeEditing = _editingMessage != null;
    final didChangeMentions = _mentions.isNotEmpty;
    final didChangeVoiceState =
        _voiceRecordingState != MessageInputVoiceRecordingState.idle;
    if (!didChangeDraft &&
        !didChangeMode &&
        !didChangeReference &&
        !didChangeEditing &&
        !didChangeMentions &&
        !didChangeVoiceState) {
      return false;
    }
    _mode = mode;
    _draft = draft;
    _referenceMessage = null;
    _editingMessage = null;
    _editExpanded = false;
    _draftBeforeEditing = null;
    _referenceBeforeEditing = null;
    _modeBeforeEditing = null;
    _mentionsBeforeEditing = null;
    _editingFallbackMentionUserIds = const <String>[];
    _editingFallbackMentionDraft = null;
    _editingRevision++;
    _mentions = _normalizeMentions(draft);
    _voiceRecordingState = MessageInputVoiceRecordingState.idle;
    return true;
  }

  String _messageContent(Message message) {
    if (message is TextMessage) return message.text ?? '';
    if (message is ReferenceMessage) return message.text ?? '';
    return '';
  }

  List<String> _messageMentionUserIds(Message message) {
    try {
      final mentionedInfo = message.mentionedInfo;
      if (mentionedInfo?.type == MentionedType.all) {
        return const <String>['All'];
      }
      return List<String>.of(mentionedInfo?.userIdList ?? const <String>[]);
    } on NoSuchMethodError {
      return const <String>[];
    }
  }

  List<MessageInputMention> _editingMentionsFromContent(
    String content,
    List<String> userIds,
  ) {
    if (content.isEmpty || userIds.isEmpty) {
      return const <MessageInputMention>[];
    }
    final matches = RegExp(r'@[^\s]+ ').allMatches(content).toList();
    if (matches.length != userIds.length) {
      return const <MessageInputMention>[];
    }
    return List<MessageInputMention>.generate(matches.length, (index) {
      final token = matches[index].group(0)!;
      return MessageInputMention(
        userId: userIds[index],
        displayName: token.substring(1, token.length - 1),
      );
    }, growable: false);
  }

  List<MessageInputMention> _normalizeMentions(String draft) {
    if (_mentions.isEmpty || draft.isEmpty) {
      return const <MessageInputMention>[];
    }
    final occurrenceBudget = <String, int>{};
    for (final mention in _mentions) {
      final token = mention.insertedText;
      occurrenceBudget[token] = _countOccurrences(draft, token);
    }
    final retained = <MessageInputMention>[];
    for (final mention in _mentions) {
      final token = mention.insertedText;
      final remaining = occurrenceBudget[token] ?? 0;
      if (remaining <= 0) {
        continue;
      }
      retained.add(mention);
      occurrenceBudget[token] = remaining - 1;
    }
    return retained;
  }

  int _countOccurrences(String text, String pattern) {
    if (text.isEmpty || pattern.isEmpty) {
      return 0;
    }
    var count = 0;
    var start = 0;
    while (true) {
      final index = text.indexOf(pattern, start);
      if (index < 0) {
        break;
      }
      count++;
      start = index + pattern.length;
    }
    return count;
  }

  int get _lastEmojiPageIndex =>
      _emojiPages.isEmpty ? 0 : _emojiPages.length - 1;

  Future<List<String>> _loadBundledEmojis() async {
    const assetCandidates = [
      'packages/ai_nexconn_chatui_plugin/assets/emoji.plist',
      'assets/emoji.plist',
    ];
    for (final asset in assetCandidates) {
      try {
        final content = await rootBundle.loadString(asset);
        final emojis = _parsePlistStrings(content);
        if (emojis.isNotEmpty) {
          return emojis;
        }
      } catch (_) {
        // Try the next package/local asset path, then fall back to Unicode.
      }
    }
    return _fallbackEmojis;
  }

  List<String> _parsePlistStrings(String content) {
    final matches = RegExp(
      r'<string>(.*?)</string>',
      dotAll: true,
    ).allMatches(content);
    return matches
        .map((match) => _decodeXmlEntities(match.group(1)?.trim() ?? ''))
        .where((emoji) => emoji.isNotEmpty)
        .toList(growable: false);
  }

  String _decodeXmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  void _processEmojiPages(List<String> emojis) {
    final itemsPerPage = (_emojiRowCount * _emojiColumnCount - 1).clamp(1, 999);
    final pages = <List<String>>[];
    for (var index = 0; index < emojis.length; index += itemsPerPage) {
      final end = (index + itemsPerPage).clamp(0, emojis.length);
      pages.add(emojis.sublist(index, end));
    }
    _emojiPages = pages.isEmpty ? const <List<String>>[] : pages;
    if (_currentEmojiPage > _lastEmojiPageIndex) {
      _currentEmojiPage = _lastEmojiPageIndex;
    }
  }

  bool _sameMentions(
    List<MessageInputMention> previous,
    List<MessageInputMention> next,
  ) {
    if (identical(previous, next)) {
      return true;
    }
    if (previous.length != next.length) {
      return false;
    }
    for (var i = 0; i < previous.length; i++) {
      if (previous[i].userId != next[i].userId ||
          previous[i].displayName != next[i].displayName) {
        return false;
      }
    }
    return true;
  }
}

const List<String> _fallbackEmojis = [
  '😀',
  '😃',
  '😄',
  '😁',
  '😆',
  '😊',
  '😍',
  '😘',
  '😎',
  '😭',
  '😡',
  '👍',
  '👏',
  '🙏',
  '💪',
  '🎉',
  '❤️',
  '🔥',
  '✅',
];
