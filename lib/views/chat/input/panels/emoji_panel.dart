part of '../message_input_widget.dart';

extension _MessageInputEmojiPanel on _MessageInputWidgetState {
  void _handleEmojiPageChanged() {
    if (!_emojiPageController.hasClients) {
      return;
    }
    final page = _emojiPageController.page?.round();
    if (page == null) {
      return;
    }
    _inputProvider.setCurrentEmojiPage(page);
  }

  void _scheduleEmojiPageLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadEmojiPages());
    });
  }

  Future<void> _loadEmojiPages() async {
    final input = _inputProvider;
    await input.loadEmojis(
      rowCount: widget.config.emojiPanelConfig.rowCount,
      columnCount: widget.config.emojiPanelConfig.columnCount,
      customEmojis: widget.config.emojiItems,
    );
  }

  Widget _buildActivePanel(BuildContext context, MessageInputProvider input) {
    return switch (input.mode) {
      MessageInputMode.emoji => _buildEmojiPanel(input),
      MessageInputMode.extension => _buildExtensionPanel(context, input),
      MessageInputMode.initial ||
      MessageInputMode.text ||
      MessageInputMode.voice => const SizedBox.shrink(
        key: ValueKey('message-input-empty-panel'),
      ),
    };
  }

  Widget _buildEmojiPanel(MessageInputProvider input) {
    final config = widget.config.emojiPanelConfig;
    final theme = NexconnThemeProvider.resolveTokens(context);
    final pages = input.emojiPages.isEmpty
        ? [widget.config.emojiItems]
        : input.emojiPages;
    return Container(
      key: const ValueKey('message-input-emoji-panel'),
      height: config.height,
      color: config.backgroundColor ?? theme.panelColor,
      child: Stack(
        children: [
          PageView.builder(
            controller: _emojiPageController,
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return _buildEmojiGridPage(context, input, pages[index], config);
            },
          ),
          if (pages.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: config.pageIndicatorConfig.bottomPadding,
              child: _buildPageIndicator(
                count: pages.length,
                currentIndex: input.currentEmojiPage,
                config: config.pageIndicatorConfig,
              ),
            ),
          if (config.height < kInputExtentionHeight)
            _buildFloatingEmojiDeleteButton(context, input, config),
          _buildEmojiSendButton(context, input, config),
        ],
      ),
    );
  }

  Widget _buildEmojiGridPage(
    BuildContext context,
    MessageInputProvider input,
    List<String> pageEmojis,
    MessageInputEmojiPanelConfig config,
  ) {
    final itemCount = config.rowCount * config.columnCount;
    final visibleEmojis = pageEmojis.take(itemCount).toList(growable: false);
    final blankCount = (itemCount - visibleEmojis.length - 1).clamp(
      0,
      itemCount,
    );
    final gridItems = <Widget>[
      ...visibleEmojis.map(
        (emoji) => _buildEmojiItem(context, input, emoji, config),
      ),
      ...List.generate(blankCount, (_) => const SizedBox.shrink()),
      _buildEmojiDeleteButton(context, input, config),
    ];
    return GridView.count(
      crossAxisCount: config.columnCount,
      mainAxisSpacing: config.rowSpacing,
      crossAxisSpacing: config.columnSpacing,
      padding: config.padding,
      physics: const NeverScrollableScrollPhysics(),
      children: gridItems,
    );
  }

  Widget _buildEmojiItem(
    BuildContext context,
    MessageInputProvider input,
    String emoji,
    MessageInputEmojiPanelConfig config,
  ) {
    void onTap() => _insertText(context, emoji, input);
    final builder = config.emojiItemBuilder;
    if (builder != null) {
      return builder(context, emoji, onTap);
    }
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: config.emojiSize)),
      ),
    );
  }
}
