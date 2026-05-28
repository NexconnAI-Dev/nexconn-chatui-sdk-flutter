// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nexconn_user_profile.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../ui_config/user/user_profile_page_config.dart';
import '../../utils/chatui_asset.dart';
import '../common/im_kit_profile_widgets.dart';
import '../../l10n/nexconn_chat_ui_l10n.dart';

/// Builds custom content for NexconnUserProfilePage.
typedef NexconnUserProfileBuilder =
    Widget Function(BuildContext context, NexconnUserProfile profile);

/// Page that displays a Nexconn user profile and optional actions.
class NexconnUserProfilePage extends StatefulWidget {
  final String? userId;
  final NexconnUserProfilePageConfig config;
  final NexconnUserProfileProvider? provider;
  final NexconnUserProfileBuilder? profileBuilder;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;

  const NexconnUserProfilePage({
    super.key,
    this.userId,
    this.config = const NexconnUserProfilePageConfig(),
    this.provider,
    this.profileBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<NexconnUserProfilePage> createState() => _NexconnUserProfilePageState();
}

class _NexconnUserProfilePageState extends State<NexconnUserProfilePage> {
  NexconnUserProfileProvider? _ownedProvider;

  NexconnUserProfileProvider get _provider =>
      widget.provider ?? _ownedProvider!;

  @override
  void initState() {
    super.initState();
    if (widget.provider == null) {
      final config = widget.config.providerConfig;
      _ownedProvider = NexconnUserProfileProvider(
        userId: widget.userId,
        profileResolver: config.profileResolver,
        currentUserProfileResolver: config.currentUserProfileResolver,
        autoLoad: config.autoLoad,
      );
      if (!config.autoLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _ownedProvider?.refresh();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _ownedProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NexconnThemeProvider.resolveTokens(context);
    return ChangeNotifierProvider<NexconnUserProfileProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor:
            widget.config.backgroundColor ?? theme.pageBackgroundColor,
        appBar: imKitAppBar(
          context,
          title: widget.config.title ?? context.chatUIL10n.userProfileTitle,
          actions: [
            IconButton(
              tooltip:
                  widget.config.refreshTooltip ??
                  context.chatUIL10n.commonRefresh,
              onPressed: () {
                _provider.refresh();
              },
              icon: ChatUIAsset.image(
                'NexconnLightIcon/Refresh.png',
                width: 24,
                height: 24,
                color: theme.primaryTextColor,
              ),
            ),
          ],
        ),
        body: Consumer<NexconnUserProfileProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && !provider.hasProfile) {
              return widget.loadingBuilder?.call(context) ??
                  Center(
                    child: Text(
                      widget.config.loadingText ??
                          context.chatUIL10n.commonLoading,
                    ),
                  );
            }
            if (provider.lastErrorMessage != null && !provider.hasProfile) {
              return _buildError(context, provider);
            }
            if (!provider.hasProfile) {
              return widget.emptyBuilder?.call(context) ??
                  Center(
                    child: Text(
                      widget.config.emptyText ??
                          context.chatUIL10n.userProfileEmpty,
                    ),
                  );
            }
            final profile = provider.profile!;
            return RefreshIndicator(
              onRefresh: () => provider.refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _header(context, profile),
                  const SizedBox(height: 20),
                  _buildActions(context, profile),
                  if (widget.config.actionConfig.showActions)
                    const SizedBox(height: 20),
                  if (widget.profileBuilder != null)
                    widget.profileBuilder!(context, profile)
                  else
                    _buildDefaultProfile(context, profile),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    NexconnUserProfileProvider provider,
  ) {
    return widget.errorBuilder?.call(context) ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.config.errorText ??
                      context.chatUIL10n.userProfileLoadFailed,
                ),
                const SizedBox(height: 8),
                Text(
                  provider.lastErrorMessage ?? '',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: imKitPrimaryButtonStyle(context),
                  onPressed: () {
                    provider.refresh();
                  },
                  child: Text(context.chatUIL10n.commonRetry),
                ),
              ],
            ),
          ),
        );
  }

  Widget _header(BuildContext context, NexconnUserProfile profile) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    return ImKitInfoCard(
      child: Row(
        children: [
          ImKitAvatar(
            label: profile.displayName,
            imageUrl: profile.avatarUrl,
            size: widget.config.avatarSize,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      widget.config.titleTextStyle ??
                      Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (widget.config.showUserId && profile.userId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.userId!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.secondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultProfile(
    BuildContext context,
    NexconnUserProfile profile,
  ) {
    final sections = <_FieldTile>[
      if (widget.config.showUserId && profile.userId != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileUserIdLabel,
          value: profile.userId!,
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showUniqueId && profile.uniqueId != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileUniqueIdLabel,
          value: profile.uniqueId!,
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showEmail && profile.email != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileEmailLabel,
          value: profile.email!,
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showBirthday && profile.birthday != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileBirthdayLabel,
          value: profile.birthday!,
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showGender && profile.gender != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileGenderLabel,
          value: profile.gender!.name,
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showLocation && profile.location != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileLocationLabel,
          value: profile.location!,
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showRole && profile.role != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileRoleLabel,
          value: profile.role.toString(),
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showLevel && profile.level != null)
        _FieldTile(
          label: context.chatUIL10n.userProfileLevelLabel,
          value: profile.level.toString(),
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
        ),
      if (widget.config.showExtProfile &&
          profile.extProfile != null &&
          profile.extProfile!.isNotEmpty)
        _FieldTile(
          label: context.chatUIL10n.userProfileExtProfileLabel,
          value: profile.extProfile.toString(),
          labelStyle: widget.config.labelTextStyle,
          valueStyle: widget.config.valueTextStyle,
          multiline: true,
        ),
    ];

    if (sections.isEmpty) {
      return Center(
        child: Text(
          widget.config.emptyText ?? context.chatUIL10n.userProfileEmpty,
        ),
      );
    }

    return ImKitInfoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < sections.length; index++)
            _FieldCell(
              field: sections[index],
              showDivider: index != sections.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, NexconnUserProfile profile) {
    final actionConfig = widget.config.actionConfig;
    if (!actionConfig.showActions) {
      return const SizedBox.shrink();
    }
    final customBuilder = actionConfig.actionBuilder;
    if (customBuilder != null) {
      return customBuilder(context, profile);
    }
    final hasUserId = profile.userId?.trim().isNotEmpty ?? false;
    final actions = <Widget>[
      if (actionConfig.showStartChat)
        _ProfileActionCell(
          assetName: 'NexconnLightIcon/Chat.png',
          title:
              actionConfig.startChatText ??
              context.chatUIL10n.userProfileActionStartChat,
          supported: actionConfig.onStartChat != null,
          onTap: () => _handleStartChat(context, profile),
        ),
      if (actionConfig.showAddFriend)
        _ProfileActionCell(
          assetName: 'NexconnLightIcon/Add.png',
          title:
              actionConfig.addFriendText ??
              context.chatUIL10n.userProfileActionAddFriend,
          supported: actionConfig.onAddFriend != null || hasUserId,
          onTap: () => _handleAddFriend(context, profile),
        ),
      if (actionConfig.showUpdateRemark)
        _ProfileActionCell(
          assetName: 'NexconnLightIcon/Edit.png',
          title:
              actionConfig.updateRemarkText ??
              context.chatUIL10n.userProfileActionUpdateRemark,
          supported: actionConfig.onUpdateRemark != null || hasUserId,
          onTap: () => _handleUpdateRemark(context, profile),
        ),
      if (actionConfig.showDeleteFriend)
        _ProfileActionCell(
          assetName: 'NexconnLightIcon/Delete.png',
          title:
              actionConfig.deleteFriendText ??
              context.chatUIL10n.userProfileActionDeleteFriend,
          supported: actionConfig.onDeleteFriend != null || hasUserId,
          destructive: true,
          onTap: () => _handleDeleteFriend(context, profile),
        ),
    ];
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return ImKitInfoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < actions.length; index++)
            _ActionCellHost(
              showDivider: index != actions.length - 1,
              child: actions[index],
            ),
        ],
      ),
    );
  }

  Future<void> _handleStartChat(
    BuildContext context,
    NexconnUserProfile profile,
  ) async {
    final callback = widget.config.actionConfig.onStartChat;
    if (callback == null) {
      _showUnsupported(context);
      return;
    }
    await callback(context, profile);
  }

  Future<void> _handleAddFriend(
    BuildContext context,
    NexconnUserProfile profile,
  ) async {
    final callback = widget.config.actionConfig.onAddFriend;
    if (callback != null) {
      await callback(context, profile);
      return;
    }
    final userId = profile.userId?.trim();
    if (userId == null || userId.isEmpty) {
      _showUnsupported(context);
      return;
    }
    await _handleAddFriendWithDefault(context, userId);
  }

  Future<NCError?> _addFriend(String userId, {String extra = ''}) async {
    final completer = Completer<NCError?>();
    try {
      NCEngine.user.addFriend(AddFriendParams(userId: userId, extra: extra), (
        _,
        error,
      ) {
        if (!completer.isCompleted) {
          completer.complete(_normalizeError(error));
        }
      });
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(_toNCError(error));
      }
    }
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () =>
          NCError(message: 'Adding friend timed out. Try again later.'),
    );
  }

  Future<void> _handleAddFriendWithDefault(
    BuildContext context,
    String userId,
  ) async {
    final error = await _addFriend(userId);
    if (!mounted) {
      return;
    }
    _showOperationResult(
      context,
      error,
      context.chatUIL10n.userProfileAddFriendSuccess,
    );
  }

  Future<void> _handleDeleteFriend(
    BuildContext context,
    NexconnUserProfile profile,
  ) async {
    final callback = widget.config.actionConfig.onDeleteFriend;
    if (callback != null) {
      await callback(context, profile);
      return;
    }
    final userId = profile.userId?.trim();
    if (userId == null || userId.isEmpty) {
      _showUnsupported(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.chatUIL10n.userProfileDeleteFriendConfirmTitle),
        content: Text(context.chatUIL10n.userProfileDeleteFriendConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.chatUIL10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.chatUIL10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _handleDeleteFriendWithDefault(context, userId);
  }

  Future<NCError?> _deleteFriend(String userId) async {
    final completer = Completer<NCError?>();
    try {
      await NCEngine.user.removeFriends([userId], (error) {
        if (!completer.isCompleted) {
          completer.complete(_normalizeError(error));
        }
      });
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(_toNCError(error));
      }
    }
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () =>
          NCError(message: 'Deleting friend timed out. Try again later.'),
    );
  }

  Future<void> _handleDeleteFriendWithDefault(
    BuildContext context,
    String userId,
  ) async {
    final error = await _deleteFriend(userId);
    if (!mounted) {
      return;
    }
    _showOperationResult(
      context,
      error,
      context.chatUIL10n.userProfileDeleteFriendSuccess,
    );
  }

  Future<void> _handleUpdateRemark(
    BuildContext context,
    NexconnUserProfile profile,
  ) async {
    final callback = widget.config.actionConfig.onUpdateRemark;
    if (callback != null) {
      await callback(context, profile);
      return;
    }
    final userId = profile.userId?.trim();
    if (userId == null || userId.isEmpty) {
      _showUnsupported(context);
      return;
    }
    final controller = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.chatUIL10n.userProfileRemarkDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.chatUIL10n.userProfileRemarkLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.chatUIL10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.chatUIL10n.commonSave),
          ),
        ],
      ),
    );
    if (remark == null || !mounted) {
      return;
    }
    final error = await _updateFriendRemark(userId, remark.trim());
    if (!mounted) {
      return;
    }
    _showOperationResult(
      context,
      error,
      context.chatUIL10n.userProfileRemarkSuccess,
    );
  }

  Future<NCError?> _updateFriendRemark(String userId, String? remark) async {
    final completer = Completer<NCError?>();
    try {
      await NCEngine.user.setFriendInfo(
        SetFriendInfoParams(userId: userId, remark: remark),
        (error) {
          if (!completer.isCompleted) {
            completer.complete(_normalizeError(error));
          }
        },
      );
    } catch (error) {
      if (!completer.isCompleted) {
        completer.complete(_toNCError(error));
      }
    }
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => NCError(
        message: 'Updating friend remark timed out. Try again later.',
      ),
    );
  }

  NCError? _normalizeError(NCError? error) {
    if (error == null || error.code == null || error.code == 0) {
      return null;
    }
    return error;
  }

  NCError _toNCError(Object error) {
    return error is NCError ? error : NCError(message: error.toString());
  }

  void _showUnsupported(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.config.actionConfig.unsupportedText ??
              context.chatUIL10n.userProfileActionUnsupported,
        ),
      ),
    );
  }

  void _showOperationResult(
    BuildContext context,
    Object? error,
    String successText,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? successText
              : error is NCError
              ? error.message ?? context.chatUIL10n.userProfileActionFailed
              : error.toString(),
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool multiline;

  const _FieldTile({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle ?? theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(
          value,
          maxLines: multiline ? null : 1,
          style: valueStyle ?? theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _FieldCell extends StatelessWidget {
  final _FieldTile field;
  final bool showDivider;

  const _FieldCell({required this.field, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return ImKitCell(
      title: field.label,
      subtitle: field.value,
      showDivider: showDivider,
    );
  }
}

class _ActionCellHost extends StatelessWidget {
  final Widget child;
  final bool showDivider;

  const _ActionCellHost({required this.child, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: NexconnThemeProvider.resolveTokens(
                    context,
                  ).dividerColor,
                ),
              )
            : null,
      ),
      child: child,
    );
  }
}

class _ProfileActionCell extends StatelessWidget {
  final String assetName;
  final String title;
  final bool supported;
  final bool destructive;
  final VoidCallback onTap;

  const _ProfileActionCell({
    required this.assetName,
    required this.title,
    required this.supported,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = NexconnThemeProvider.resolveTokens(context);
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ImKitCell(
      leading: ChatUIAsset.image(
        assetName,
        width: 24,
        height: 24,
        color: supported
            ? color ?? tokens.primaryTextColor
            : tokens.secondaryTextColor.withValues(alpha: 0.55),
      ),
      title: title,
      enabled: supported,
      destructive: destructive && supported,
      trailing: supported
          ? ChatUIAsset.image(
              'NexconnLightIcon/Right-arrow.png',
              width: 20,
              height: 20,
              color: tokens.secondaryTextColor,
            )
          : ImKitUnsupportedBadge(context.chatUIL10n.commonUnsupported),
      onTap: supported ? onTap : null,
      showDivider: false,
    );
  }
}
