import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';

import '../../l10n/nexconn_chat_ui_l10n.dart';
import '../../providers/chat_provider.dart';
import '../../utils/chatui_asset.dart';
import 'chat_message_search_result_page.dart';

/// Search page for messages in a channel.
class ChatMessageSearchPage extends StatefulWidget {
  final ChatProvider provider;
  final BaseChannel channel;
  final String title;
  final ValueChanged<Message>? onMessageTap;

  const ChatMessageSearchPage({
    super.key,
    required this.provider,
    required this.channel,
    this.title = '',
    this.onMessageTap,
  });

  @override
  State<ChatMessageSearchPage> createState() => _ChatMessageSearchPageState();
}

class _ChatMessageSearchPageState extends State<ChatMessageSearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _sentTimeController = TextEditingController();
  final TextEditingController _beforeCountController = TextEditingController(
    text: '10',
  );
  final TextEditingController _afterCountController = TextEditingController(
    text: '10',
  );
  final TextEditingController _pageSizeController = TextEditingController(
    text: '20',
  );

  ChatMessageSearchMode _mode = ChatMessageSearchMode.keyword;
  String? _errorText;

  @override
  void dispose() {
    _keywordController.dispose();
    _userIdController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _sentTimeController.dispose();
    _beforeCountController.dispose();
    _afterCountController.dispose();
    _pageSizeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final request = ChatMessageSearchRequest(
      channel: widget.channel,
      mode: _mode,
      keyword: _trimOrNull(_keywordController.text),
      userId: _trimOrNull(_userIdController.text),
      startTime: int.tryParse(_startTimeController.text.trim()) ?? 0,
      endTime: int.tryParse(_endTimeController.text.trim()) ?? 0,
      sentTime: int.tryParse(_sentTimeController.text.trim()) ?? 0,
      beforeCount: int.tryParse(_beforeCountController.text.trim()) ?? 10,
      afterCount: int.tryParse(_afterCountController.text.trim()) ?? 10,
      pageSize: int.tryParse(_pageSizeController.text.trim()) ?? 20,
    );

    setState(() => _errorText = null);
    try {
      final messages = await widget.provider.searchMessages(request);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatMessageSearchResultPage(
            provider: widget.provider,
            request: request,
            messages: messages,
            onMessageTap: widget.onMessageTap,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final reason = error is NCError ? error.message : error.toString();
      setState(
        () => _errorText = reason ?? context.chatUIL10n.chatSearchFailed,
      );
    }
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _buildModeFields() {
    final l10n = context.chatUIL10n;
    switch (_mode) {
      case ChatMessageSearchMode.keyword:
        return _SearchTextField(
          controller: _keywordController,
          label: l10n.searchKeywordLabel,
          prefixIcon: Icons.search,
        );
      case ChatMessageSearchMode.user:
        return _SearchTextField(
          controller: _userIdController,
          label: l10n.searchUserIdLabel,
          prefixIcon: Icons.person_outline,
        );
      case ChatMessageSearchMode.timeRange:
        return Column(
          children: [
            _SearchTextField(
              controller: _keywordController,
              label: l10n.searchKeywordLabel,
              prefixIcon: Icons.search,
            ),
            const SizedBox(height: 12),
            _SearchTextField(
              controller: _startTimeController,
              label: l10n.searchStartTimeMsLabel,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.access_time,
            ),
            const SizedBox(height: 12),
            _SearchTextField(
              controller: _endTimeController,
              label: l10n.searchEndTimeMsLabel,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.access_time_filled,
            ),
          ],
        );
      case ChatMessageSearchMode.aroundTime:
        return Column(
          children: [
            _SearchTextField(
              controller: _sentTimeController,
              label: l10n.searchReferenceTimeMsLabel,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.schedule,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SearchTextField(
                    controller: _beforeCountController,
                    label: l10n.searchBeforeCountLabel,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SearchTextField(
                    controller: _afterCountController,
                    label: l10n.searchAfterCountLabel,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.chatUIL10n;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: ChatUIAsset.image(
            'NexconnLightIcon/Left-arrow.png',
            width: 22,
            height: 22,
            color: const Color(0xFF111111),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title.isEmpty ? l10n.chatSearchPageTitle : widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEAEAEA)),
        ),
      ),
      body: AnimatedBuilder(
        animation: widget.provider,
        builder: (context, _) {
          return Stack(
            children: [
              SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.searchModeLabel,
                            style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ChatMessageSearchMode.values.map((mode) {
                              final selected = mode == _mode;
                              return ChoiceChip(
                                label: Text(_modeLabel(mode)),
                                selected: selected,
                                showCheckmark: false,
                                selectedColor: const Color(0xFFEFF3FF),
                                labelStyle: TextStyle(
                                  color: selected
                                      ? const Color(0xFF3D6DCC)
                                      : const Color(0xFF666666),
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? const Color(0xFF3D6DCC)
                                      : const Color(0xFFE5E5E5),
                                ),
                                onSelected: (_) => setState(() => _mode = mode),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(child: _buildModeFields()),
                    const SizedBox(height: 12),
                    _SearchTextField(
                      controller: _pageSizeController,
                      label: l10n.searchPageSizeLabel,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.format_list_numbered,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      _InlineError(text: _errorText!),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF3D6DCC),
                          disabledBackgroundColor: const Color(0xFFD7DBE7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: widget.provider.isSearching ? null : _submit,
                        child: Text(
                          l10n.commonSearch,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.provider.isSearching)
                Container(
                  color: Colors.black.withValues(alpha: 0.1),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _modeLabel(ChatMessageSearchMode mode) {
    final l10n = context.chatUIL10n;
    switch (mode) {
      case ChatMessageSearchMode.keyword:
        return l10n.searchModeKeyword;
      case ChatMessageSearchMode.user:
        return l10n.searchModeUser;
      case ChatMessageSearchMode.timeRange:
        return l10n.searchModeTimeRange;
      case ChatMessageSearchMode.aroundTime:
        return l10n.searchModeAroundTime;
    }
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SearchTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const _SearchTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: _buildPrefixIcon(),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 42,
        ),
        filled: true,
        fillColor: const Color(0xFFF2F3F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget? _buildPrefixIcon() {
    if (prefixIcon == null) {
      return null;
    }
    final assetName = _prefixAssetName;
    if (assetName == null) {
      return Icon(prefixIcon, size: 20, color: const Color(0xFF999999));
    }
    return Center(
      child: ChatUIAsset.image(
        assetName,
        width: 20,
        height: 20,
        color: const Color(0xFF999999),
      ),
    );
  }

  String? get _prefixAssetName {
    return switch (prefixIcon) {
      Icons.search => 'NexconnLightIcon/Search.png',
      Icons.person_outline => 'NexconnLightIcon/Member.png',
      _ => null,
    };
  }
}

class _InlineError extends StatelessWidget {
  final String text;

  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
}
