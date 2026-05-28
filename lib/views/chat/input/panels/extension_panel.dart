part of '../message_input_widget.dart';

extension _MessageInputExtensionPanel on _MessageInputWidgetState {
  Widget _buildExtensionPanel(
    BuildContext context,
    MessageInputProvider input,
  ) {
    final plugins = widget.config.extensionPlugins;
    if (plugins.isEmpty) {
      return SizedBox(
        key: const ValueKey('message-input-empty-extension-panel'),
        height: 128,
        child: Center(
          child: Text(
            widget.config.emptyExtensionPanelText ??
                context.chatUIL10n.messageInputEmptyExtensionPanel,
          ),
        ),
      );
    }

    final panelConfig = widget.config.extensionPanelConfig;
    final pageCount = (plugins.length / panelConfig.itemsPerPage).ceil();
    final showsPageIndicator = pageCount > 1;
    return Container(
      key: const ValueKey('message-input-extension-panel'),
      height: panelConfig.height,
      color:
          panelConfig.backgroundColor ??
          NexconnThemeProvider.resolveTokens(context).panelColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final panelPadding = _resolveExtensionPanelPadding(
            panelConfig,
            showsPageIndicator,
          );
          return Stack(
            children: [
              PageView.builder(
                controller: _extensionPageController,
                itemCount: pageCount,
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * panelConfig.itemsPerPage;
                  final end = (start + panelConfig.itemsPerPage).clamp(
                    0,
                    plugins.length,
                  );
                  final itemCount = end - start;
                  final itemMetrics = _resolveExtensionItemMetrics(
                    panelConfig,
                    panelPadding,
                    constraints,
                    itemCount,
                  );
                  return GridView.builder(
                    padding: panelPadding,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: panelConfig.crossAxisCount,
                      mainAxisSpacing: panelConfig.mainAxisSpacing,
                      crossAxisSpacing: panelConfig.crossAxisSpacing,
                      mainAxisExtent: itemMetrics.tileHeight,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      final plugin = plugins[start + index];
                      return _buildExtensionPlugin(
                        context,
                        input,
                        plugin,
                        metrics: itemMetrics,
                      );
                    },
                  );
                },
              ),
              if (showsPageIndicator)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: panelConfig.pageIndicatorConfig.bottomPadding,
                  child: AnimatedBuilder(
                    animation: _extensionPageController,
                    builder: (context, _) => _buildPageIndicator(
                      count: pageCount,
                      currentIndex: _extensionPageController.hasClients
                          ? (_extensionPageController.page?.round() ?? 0)
                          : 0,
                      config: panelConfig.pageIndicatorConfig,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExtensionPlugin(
    BuildContext context,
    MessageInputProvider input,
    MessageInputExtensionPlugin plugin, {
    required _MessageInputExtensionItemMetrics metrics,
  }) {
    final isActionReady = plugin.enabled && _canHandlePluginTap(plugin);
    final title = _pluginTitle(context, plugin);
    final theme = NexconnThemeProvider.resolveTokens(context);
    final content = plugin.builder != null
        ? KeyedSubtree(
            key: ValueKey('message-input-extension-${plugin.id}'),
            child: plugin.builder!(context, plugin),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(
                    widget.config.extensionPanelConfig.itemRadius,
                  ),
                ),
                child: SizedBox.square(
                  dimension: metrics.iconBoxSize,
                  child: Center(
                    child: plugin.assetName == null
                        ? Icon(
                            plugin.icon,
                            color: const Color(0xFF2F6BFF),
                            size: kInputExtentionIconSize,
                          )
                        : ChatUIAsset.image(
                            plugin.assetName!,
                            width: kInputExtentionIconSize,
                            height: kInputExtentionIconSize,
                          ),
                  ),
                ),
              ),
              SizedBox(height: metrics.titleTopSpacing),
              SizedBox(
                height: metrics.titleHeight,
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    strutStyle: const StrutStyle(
                      forceStrutHeight: true,
                      height: 1.0,
                      leading: 0,
                    ),
                    style: const TextStyle(
                      fontSize: kInputExtentionItemFontSize,
                      height: 1.0,
                    ).copyWith(color: theme.secondaryTextColor),
                  ),
                ),
              ),
            ],
          );

    return Tooltip(
      key: ValueKey('message-input-extension-${plugin.id}'),
      message: plugin.tooltip ?? title,
      child: Opacity(
        opacity: isActionReady ? 1 : 0.48,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => isActionReady
              ? _handlePluginTap(context, input, plugin)
              : _showUnavailablePlugin(context, plugin),
          child: Center(
            child: SizedBox(
              width: metrics.tileWidth,
              height: metrics.tileHeight,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  EdgeInsets _resolveExtensionPanelPadding(
    MessageInputExtensionPanelConfig panelConfig,
    bool showsPageIndicator,
  ) {
    if (!showsPageIndicator) {
      return panelConfig.padding.copyWith(
        bottom: panelConfig.padding.bottom.clamp(8.0, 8.0),
      );
    }
    final indicator = panelConfig.pageIndicatorConfig;
    final reservedBottom = (indicator.size + indicator.bottomPadding + 4.0)
        .clamp(8.0, panelConfig.padding.bottom.toDouble());
    return panelConfig.padding.copyWith(bottom: reservedBottom);
  }

  _MessageInputExtensionItemMetrics _resolveExtensionItemMetrics(
    MessageInputExtensionPanelConfig panelConfig,
    EdgeInsets panelPadding,
    BoxConstraints constraints,
    int itemCount,
  ) {
    final rowCount = itemCount == 0
        ? 1
        : ((itemCount - 1) ~/ panelConfig.crossAxisCount) + 1;
    final availableWidth =
        constraints.maxWidth -
        panelPadding.left -
        panelPadding.right -
        panelConfig.crossAxisSpacing * (panelConfig.crossAxisCount - 1);
    final tileWidth = (availableWidth / panelConfig.crossAxisCount).clamp(
      0.0,
      double.infinity,
    );
    final availableHeight =
        constraints.maxHeight -
        panelPadding.top -
        panelPadding.bottom -
        panelConfig.mainAxisSpacing * (rowCount - 1);
    final defaultTileHeight =
        kInputExtentionItemSize + panelConfig.titleAreaHeight;
    final tileHeight = (availableHeight / rowCount).clamp(
      56.0,
      defaultTileHeight,
    );
    final titleHeight = (tileHeight * 0.22).clamp(16.0, 20.0);
    final titleTopSpacing = tileHeight >= defaultTileHeight ? 8.0 : 4.0;
    final iconBoxSize = (tileHeight - titleHeight - titleTopSpacing).clamp(
      36.0,
      tileWidth.clamp(36.0, kInputExtentionItemSize),
    );
    return (
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      iconBoxSize: iconBoxSize,
      titleHeight: titleHeight,
      titleTopSpacing: titleTopSpacing,
    );
  }
}

typedef _MessageInputExtensionItemMetrics = ({
  double tileWidth,
  double tileHeight,
  double iconBoxSize,
  double titleHeight,
  double titleTopSpacing,
});
