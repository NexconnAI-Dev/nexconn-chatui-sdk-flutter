// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'nexconn_chat_ui_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class NexconnChatUILocalizationsZh extends NexconnChatUILocalizations {
  NexconnChatUILocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get channelAppBarTitle => '聊天';

  @override
  String get channelLongPressCancel => '取消';

  @override
  String get channelListEmpty => '暂无聊天';

  @override
  String get channelActionPin => '置顶';

  @override
  String get channelActionUnpin => '取消置顶';

  @override
  String get channelActionMute => '免打扰';

  @override
  String get channelActionUnmute => '取消免打扰';

  @override
  String get channelActionDelete => '删除';

  @override
  String get channelActionFailed => '操作失败，请重试。';

  @override
  String get channelSearchPlaceholder => '搜索聊天';

  @override
  String get channelNetworkUnavailable => '网络不可用，聊天列表可能不是最新。';

  @override
  String channelGroupTitle(String channelId) {
    return '群组 $channelId';
  }

  @override
  String channelOpenTitle(String channelId) {
    return '开放频道 $channelId';
  }

  @override
  String channelCommunityTitle(String channelId) {
    return '社区 $channelId';
  }

  @override
  String get channelSystemTitle => '系统通知';

  @override
  String channelDraftPrefix(String draft) {
    return '[草稿] $draft';
  }

  @override
  String get channelUnreadMentionPrefix => '[有人@你]';

  @override
  String get channelReadStatusSending => '发送中';

  @override
  String get channelReadStatusFailed => '发送失败';

  @override
  String get channelReadStatusSent => '已发送';

  @override
  String get channelReadStatusDelivered => '已送达';

  @override
  String get channelReadStatusRead => '已读';

  @override
  String get chatSearchButtonTooltip => '搜索消息';

  @override
  String get chatSearchPageTitle => '消息搜索';

  @override
  String get chatMessageListEmpty => '暂无消息';

  @override
  String get chatNetworkUnavailable => '网络不可用，消息可能不是最新。';

  @override
  String get chatUnreadHistoryTip => '未读历史';

  @override
  String chatUnreadMentionedTip(int count) {
    return '有人@你($count)';
  }

  @override
  String get chatNewMessageTip => '新消息';

  @override
  String get chatTypingStatusTip => '正在输入...';

  @override
  String get chatReadReceiptUsersTitle => '已读回执用户';

  @override
  String get chatReadReceiptUsersReadTab => '已读';

  @override
  String get chatReadReceiptUsersUnreadTab => '未读';

  @override
  String get chatReadReceiptUsersLoading => '正在加载已读回执用户';

  @override
  String get chatReadReceiptUsersEmpty => '暂无用户';

  @override
  String get chatReadReceiptUsersLoadFailed => '加载已读回执用户失败';

  @override
  String get chatReadReceiptPending => '已读状态待获取';

  @override
  String get chatReadReceiptNotRead => '未读';

  @override
  String get chatReadReceiptFullyRead => '已读';

  @override
  String chatReadReceiptPartiallyRead(int readCount, int totalCount) {
    return '已读 $readCount/$totalCount';
  }

  @override
  String get chatLongPressCopy => '复制';

  @override
  String get chatLongPressDelete => '删除';

  @override
  String get chatLongPressDeleteForMe => 'Delete for me';

  @override
  String get chatLongPressDeleteForEveryone => 'Delete for everyone';

  @override
  String get chatLongPressDeleteForAll => 'Delete for everyone';

  @override
  String get chatLongPressReference => '回复';

  @override
  String get chatLongPressEdit => '编辑';

  @override
  String get chatLongPressMore => '多选';

  @override
  String get chatLongPressForward => '转发';

  @override
  String get chatMessageCopied => '消息已复制。';

  @override
  String get chatDeleteFailed => '删除消息失败。';

  @override
  String get chatDeleteForAllFailed => '为所有人删除消息失败。';

  @override
  String get chatDeleteForAllUnavailable => '当前消息状态不支持为所有人删除。';

  @override
  String get chatReplyAdded => '已添加回复。';

  @override
  String chatSelectionLimit(int count) {
    return '最多可选择 $count 条消息。';
  }

  @override
  String get chatNoMessagesToForward => '没有可转发的消息。';

  @override
  String get chatReferenceMessageCombinedForwardUnsupported => '引用消息不支持合并转发。';

  @override
  String chatCombinedForwardSelectionLimit(int count) {
    return '合并转发不能选择 $count 条及以上消息。';
  }

  @override
  String chatForwardedCombined(int count) {
    return '已合并转发 $count 条消息。';
  }

  @override
  String chatForwarded(int count) {
    return '已转发 $count 条消息。';
  }

  @override
  String get chatForwardFailed => '转发消息失败。';

  @override
  String get chatForwardMediaDownloadFailed => '媒体下载失败，请检查网络后重试。';

  @override
  String chatSelectedMessages(int count) {
    return '已选择 $count 条消息';
  }

  @override
  String chatSelectedMessagesCount(int count) {
    return '$count 条消息';
  }

  @override
  String chatSelectedMentionsCount(int count) {
    return '@$count';
  }

  @override
  String get messageInputPluginUnavailable => '该插件暂不可用';

  @override
  String get messageInputPhotosTitle => '照片';

  @override
  String get messageInputPhotoPickerUnavailable => '照片选择器暂不可用';

  @override
  String get messageInputVideoTitle => '视频';

  @override
  String get messageInputVideoPickerUnavailable => '视频选择器暂不可用';

  @override
  String get messageInputCameraTitle => '相机';

  @override
  String get messageInputCameraUnavailable => '相机暂不可用';

  @override
  String get messageInputFilmingTitle => '拍摄';

  @override
  String get messageInputFilmingUnavailable => '拍摄暂不可用';

  @override
  String get messageInputFilesTitle => '文件';

  @override
  String get messageInputFilePickerUnavailable => '文件选择器暂不可用';

  @override
  String get messageInputPermissionDenied => '权限已拒绝';

  @override
  String get messageInputVideoTooShort => '视频时长不能小于 1 秒';

  @override
  String get messageInputVideoTooLong => '视频时长不能超过 10 秒';

  @override
  String get messageInputLocationTitle => '位置';

  @override
  String get messageInputLocationPickerUnavailable => '位置选择器暂不可用';

  @override
  String get messageInputHint => '消息';

  @override
  String get messageInputVoiceUnavailable => '语音输入暂不可用';

  @override
  String get messageInputEmptyTextWarning => '请输入消息内容';

  @override
  String get messageInputEmojiSendButton => '发送';

  @override
  String get messageInputDeleteEmojiTooltip => '删除表情';

  @override
  String get messageInputEmptyExtensionPanel => '暂无可用插件';

  @override
  String get messageInputEmptyMentionCandidates => '暂无成员';

  @override
  String get messageInputVoiceAction => '发送语音';

  @override
  String get messageInputVoiceReleaseToSend => '松开发送  |  上划取消';

  @override
  String get messageInputVoiceReleaseToCancel => '松开取消';

  @override
  String get messageInputVoiceTooShort => '录音时间太短';

  @override
  String get messageInputVoiceTooLong => '录音时间超过60秒';

  @override
  String get messageInputVoicePermissionDenied => '麦克风权限被拒绝';

  @override
  String get messageInputVoiceRecordFailed => '录音失败';

  @override
  String get friendAppBarTitle => '好友';

  @override
  String get friendListEmpty => '暂无好友';

  @override
  String get friendSearchHint => '输入名称、备注或用户 ID';

  @override
  String get friendSearchEmpty => '暂无结果';

  @override
  String get friendSearchButton => '搜索';

  @override
  String get friendAddUserIdHint => '输入好友用户 ID';

  @override
  String get friendAddExtraHint => '可选申请消息';

  @override
  String get friendAddSubmit => '发送好友申请';

  @override
  String get friendAddSuccess => '好友申请已发送';

  @override
  String get friendAddEmptyUserId => '请输入好友用户 ID';

  @override
  String get friendApplicationsEmpty => '暂无好友申请';

  @override
  String get friendApplicationsLoadFailed => '加载好友申请失败';

  @override
  String get friendApplicationsLoadingMore => '加载更多好友申请';

  @override
  String get friendApplicationAccept => '接受';

  @override
  String get friendApplicationDecline => '拒绝';

  @override
  String get friendSearchPageTitle => '搜索好友';

  @override
  String get friendAddPageTitle => '添加好友';

  @override
  String get friendApplicationsPageTitle => '好友申请';

  @override
  String get friendRequestFailed => '发送好友申请失败';

  @override
  String get friendUserIdLabel => '好友用户 ID';

  @override
  String get friendRequestMessageLabel => '申请消息';

  @override
  String get friendUnnamed => '未命名好友';

  @override
  String get groupManagementTitle => '群管理';

  @override
  String get groupManagementLoadFailed => '加载群管理信息失败';

  @override
  String get groupNotFound => '未找到群组';

  @override
  String get groupProfileManagementSection => '群资料';

  @override
  String get groupEditProfileAction => '编辑群资料';

  @override
  String get groupLifecycleSection => '群操作';

  @override
  String get groupLeaveAction => '退出群组';

  @override
  String get groupDismissAction => '解散群组';

  @override
  String get groupLeaveConfirmTitle => '退出群组';

  @override
  String get groupLeaveConfirmMessage => '确定要退出该群组吗？';

  @override
  String get groupDismissConfirmTitle => '解散群组';

  @override
  String get groupDismissConfirmMessage => '确定要解散该群组吗？';

  @override
  String get groupLeaveSucceeded => '已退出群组';

  @override
  String get groupDismissSucceeded => '群组已解散';

  @override
  String get groupOperationUnsupported => '当前不支持该群组操作';

  @override
  String get groupEditProfileTitle => '编辑群资料';

  @override
  String get groupAvatarUrlLabel => '头像 URL';

  @override
  String get groupNoticeLabel => '群公告';

  @override
  String get groupIntroductionLabel => '群描述';

  @override
  String get groupProfileUpdated => '群资料已更新';

  @override
  String get groupMemberManagement => '成员管理';

  @override
  String get groupMembers => '群成员';

  @override
  String get groupAddMembers => '添加成员';

  @override
  String get groupRemoveMembers => '移除成员';

  @override
  String get groupAddAdmins => '添加管理员';

  @override
  String get groupRemoveAdmins => '移除管理员';

  @override
  String get groupTransferOwnership => '转让群主';

  @override
  String get groupRequests => '群申请';

  @override
  String get groupCannotManage => '你当前的角色不能管理该群';

  @override
  String get groupRetry => '重试';

  @override
  String get groupCreateTitle => '创建群组';

  @override
  String get groupNameLabel => '群名称';

  @override
  String get groupNameHint => '输入群名称';

  @override
  String get groupCreateButton => '创建群组';

  @override
  String get groupCreateFailed => '创建群组失败';

  @override
  String get groupSearchTitle => '搜索群组';

  @override
  String get groupSearchHint => '搜索群组';

  @override
  String get groupSearchEmpty => '未找到群组';

  @override
  String get groupApplicationsTitle => '群申请';

  @override
  String get groupApplicationsEmpty => '暂无群申请';

  @override
  String get groupMembersTitle => '群成员';

  @override
  String get groupMembersEmpty => '暂无成员';

  @override
  String get groupSelectMembersTitle => '选择成员';

  @override
  String get groupSelectMembersEmpty => '暂无可用用户';

  @override
  String get groupDetailTitle => '群详情';

  @override
  String get groupFollowMembersTitle => '关注成员';

  @override
  String get groupFollowMembersEmpty => '暂无关注成员';

  @override
  String forwardSelectTitle(int count) {
    return '选择转发目标（$count）';
  }

  @override
  String get forwardNoChannels => '暂无可用频道';

  @override
  String get forwardIndividually => '逐条转发';

  @override
  String get forwardAsCombined => '合并转发';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSave => '保存';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonLoading => '加载中...';

  @override
  String get commonUnknownUser => '未知用户';

  @override
  String get photoImageUnavailable => '图片不可用';

  @override
  String get photoImageLoadFailed => '图片加载失败';

  @override
  String get photoVideoPreview => '视频预览';

  @override
  String get photoOpenVideo => '打开视频';

  @override
  String get filePreviewTitle => '文件预览';

  @override
  String get fileUntitled => '未命名文件';

  @override
  String get fileOpen => '打开文件';

  @override
  String get readReceiptCloseTooltip => '关闭';

  @override
  String readReceiptReadAt(String time) {
    return '读取时间 $time';
  }

  @override
  String get messageDeletedForEveryone => '消息已为所有人删除';

  @override
  String get messageSummaryReply => '[回复]';

  @override
  String get messageSummaryImage => '[图片]';

  @override
  String get messageSummaryGif => '[GIF]';

  @override
  String get messageSummaryVoice => '[语音]';

  @override
  String get messageSummaryVideo => '[视频]';

  @override
  String get messageSummaryFile => '[文件]';

  @override
  String get messageSummaryLocation => '[位置]';

  @override
  String get messageSummaryCombinedForward => '[合并转发]';

  @override
  String get combineMessageChatHistoryLabel => '聊天记录';

  @override
  String get combineMessageGroupChatHistoryTitle => 'Group Chat History';

  @override
  String combineMessageTitle(String names) {
    return '$names的聊天记录';
  }

  @override
  String combineMessageTimeYesterday(String time) {
    return '昨天 $time';
  }

  @override
  String combineMessageTimeWeekday(String weekday, String time) {
    return '$weekday $time';
  }

  @override
  String combineMessageTimeDate(String date, String time) {
    return '$date $time';
  }

  @override
  String get combineMessageLoadFailed => '合并转发消息加载失败';

  @override
  String get messageSummaryGroupNotification => '[群通知]';

  @override
  String get messageSummaryInformationNotification => '[系统通知]';

  @override
  String get messageInputEditing => '编辑消息';

  @override
  String get messageInputCancelEditing => '取消编辑';

  @override
  String get messageEditSwitchTitle => '切换编辑消息？';

  @override
  String get messageEditSwitchMessage => '当前未提交的编辑内容将被丢弃。';

  @override
  String get messageEditUnavailable => '该消息已不可编辑';

  @override
  String get messageEditFailed => '消息编辑失败';

  @override
  String get messageEdited => '已编辑';

  @override
  String get messageEditUpdating => '更新中';

  @override
  String get messageEditRetry => '更新失败，点击重试';

  @override
  String get messageEditExpandTooltip => '展开编辑';

  @override
  String get messageInputEmojiTooltip => '表情';

  @override
  String get referenceMessageDeleted => '此消息已删除';

  @override
  String get referenceMessageRecalled => '此消息已撤回';

  @override
  String get messageSummaryUnknown => '未知消息';

  @override
  String get commonWeekdayMonday => '周一';

  @override
  String get commonWeekdayTuesday => '周二';

  @override
  String get commonWeekdayWednesday => '周三';

  @override
  String get commonWeekdayThursday => '周四';

  @override
  String get commonWeekdayFriday => '周五';

  @override
  String get commonWeekdaySaturday => '周六';

  @override
  String get commonWeekdaySunday => '周日';

  @override
  String get commonYesterday => '昨天';

  @override
  String get messageInputSendTooltip => '发送';

  @override
  String messageInputReplyTo(String sender, String summary) {
    return '回复 $sender：$summary';
  }

  @override
  String get messageInputCancelReplyTooltip => '取消回复';

  @override
  String get messageInputSwitchToTextTooltip => '切换到文本';

  @override
  String get messageInputVoiceTooltip => '语音输入';

  @override
  String get messageInputHideEmojiPanelTooltip => '隐藏表情面板';

  @override
  String get messageInputEmojiPanelTooltip => '表情面板';

  @override
  String get messageInputHideExtensionPanelTooltip => '隐藏附件面板';

  @override
  String get messageInputExtensionPanelTooltip => '附件面板';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonCreate => '创建';

  @override
  String get commonAccept => '接受';

  @override
  String get commonDecline => '拒绝';

  @override
  String get commonClear => '清除';

  @override
  String get commonOperationFailed => '操作失败';

  @override
  String get commonUnsupported => '不支持';

  @override
  String get groupPageTitle => '我的群组';

  @override
  String get groupCreateTooltip => '创建群组';

  @override
  String get groupSearchTooltip => '搜索群组';

  @override
  String get groupLoadFailed => '加载群组失败';

  @override
  String get groupEmptyJoined => '暂无已加入的群组';

  @override
  String groupMemberCount(int count) {
    return '$count 个成员';
  }

  @override
  String groupSelectedMembersCount(int count) {
    return '已选择 $count 人';
  }

  @override
  String groupFollowedCount(int count) {
    return '已关注 $count 人';
  }

  @override
  String get groupCreatePageTitle => '创建群组';

  @override
  String get groupIdLabel => '群组 ID';

  @override
  String get groupIdAutoGenerateHint => '留空则自动生成';

  @override
  String get groupSelectMembersLabel => '选择成员';

  @override
  String get groupSearchContactsHint => '搜索联系人';

  @override
  String get groupLoadContactsFailed => '加载联系人失败';

  @override
  String get groupNoContactsAvailable => '暂无可选联系人';

  @override
  String get groupNameRequired => '请输入群组名称';

  @override
  String get groupSelectAtLeastOneMember => '请至少选择一名成员';

  @override
  String get groupSearchPageTitle => '搜索群组';

  @override
  String get groupSearchNameHint => '请输入群组名称';

  @override
  String get groupSearchKeywordEmpty => '请输入关键词搜索群组';

  @override
  String get groupSearchFailed => '搜索失败';

  @override
  String get groupDetailsPageTitle => '群组详情';

  @override
  String get groupDetailsLoadFailed => '加载群组详情失败';

  @override
  String get groupAnnouncementLabel => '群公告';

  @override
  String get groupDescriptionLabel => '群描述';

  @override
  String get groupMembersLabel => '成员';

  @override
  String get groupMyRoleLabel => '我的角色';

  @override
  String get groupMembersPageTitle => '群成员';

  @override
  String get groupFollowedMembersTitle => '关注成员';

  @override
  String get groupAddMembersTitle => '添加成员';

  @override
  String get groupRemoveMembersTitle => '移除成员';

  @override
  String get groupAddAdminsTitle => '添加管理员';

  @override
  String get groupRemoveAdminsTitle => '移除管理员';

  @override
  String get groupTransferOwnershipTitle => '转让群主';

  @override
  String get groupRequestsTitle => '群申请';

  @override
  String get groupMemberManagementSection => '成员管理';

  @override
  String get groupAdminManagementSection => '管理员管理';

  @override
  String get groupRequestManagementSection => '申请管理';

  @override
  String get groupCurrentRoleCannotManage => '当前角色无法管理该群组';

  @override
  String get groupMembersLoadFailed => '加载群成员失败';

  @override
  String get groupNoMembers => '暂无群成员';

  @override
  String get groupFollowedMembersLoadFailed => '加载关注成员失败';

  @override
  String get groupFollowedMembersSubtitle => '关注重要成员以便快速访问';

  @override
  String get groupFollowAction => '关注';

  @override
  String get groupUnfollowAction => '取消关注';

  @override
  String get groupRequestsLoadFailed => '加载群申请失败';

  @override
  String get groupNoPendingRequests => '暂无待处理群申请';

  @override
  String groupApplicationGroupPrefix(String groupId) {
    return '群组：$groupId';
  }

  @override
  String get groupNoMembersAvailable => '暂无可选成员';

  @override
  String groupMemberActionSucceeded(String action) {
    return '$action成功';
  }

  @override
  String get friendLoadFailed => '加载好友失败';

  @override
  String get friendSearchTooltip => '搜索好友';

  @override
  String get friendAddTooltip => '添加好友';

  @override
  String get friendRequestsTooltip => '好友申请';

  @override
  String get friendSearchFailed => '搜索好友失败';

  @override
  String get friendSearchPrompt => '输入关键词后点击搜索';

  @override
  String get friendRequestAccepted => '已接受好友申请';

  @override
  String get friendRequestDeclined => '已拒绝好友申请';

  @override
  String get friendRequestHandleFailed => '处理好友申请失败';

  @override
  String get friendApplicationUnnamed => '未命名申请';

  @override
  String get friendApplicationSentRequest => '已发送申请';

  @override
  String get friendApplicationReceivedRequest => '收到的申请';

  @override
  String get friendApplicationFriendRequest => '好友申请';

  @override
  String get friendApplicationPending => '待处理';

  @override
  String get friendApplicationAccepted => '已接受';

  @override
  String get friendApplicationDeclined => '已拒绝';

  @override
  String get friendApplicationExpired => '已过期';

  @override
  String friendApplicationHandledAt(String time) {
    return '处理时间 $time';
  }

  @override
  String get userProfileTitle => '用户资料';

  @override
  String get userProfileEmpty => '暂无资料信息';

  @override
  String get userProfileLoadFailed => '加载用户资料失败';

  @override
  String get commonRefresh => '刷新';

  @override
  String get userProfileUserIdLabel => '用户 ID';

  @override
  String get userProfileUniqueIdLabel => '唯一 ID';

  @override
  String get userProfileEmailLabel => '邮箱';

  @override
  String get userProfileBirthdayLabel => '生日';

  @override
  String get userProfileGenderLabel => '性别';

  @override
  String get userProfileLocationLabel => '位置';

  @override
  String get userProfileRoleLabel => '角色';

  @override
  String get userProfileLevelLabel => '等级';

  @override
  String get userProfileExtProfileLabel => '扩展资料';

  @override
  String get userProfileActionStartChat => '发起聊天';

  @override
  String get userProfileActionAddFriend => '添加好友';

  @override
  String get userProfileActionDeleteFriend => '删除好友';

  @override
  String get userProfileActionUpdateRemark => '编辑备注';

  @override
  String get userProfileActionUnsupported => '当前操作不可用';

  @override
  String get userProfileActionFailed => '操作失败，请重试';

  @override
  String get userProfileAddFriendSuccess => '好友申请已发送';

  @override
  String get userProfileDeleteFriendSuccess => '好友已删除';

  @override
  String get userProfileRemarkSuccess => '备注已更新';

  @override
  String get userProfileDeleteFriendConfirmTitle => '删除好友';

  @override
  String get userProfileDeleteFriendConfirmMessage => '确定要删除该好友吗？';

  @override
  String get userProfileRemarkDialogTitle => '编辑好友备注';

  @override
  String get userProfileRemarkLabel => '备注';

  @override
  String get searchResultsTitle => '搜索结果';

  @override
  String get searchNoMatchingMessages => '没有匹配的消息';

  @override
  String searchResultsCount(int count) {
    return '结果：$count';
  }

  @override
  String get chatSearchFailed => '搜索失败';

  @override
  String get searchKeywordLabel => '关键词';

  @override
  String get searchUserIdLabel => '用户 ID';

  @override
  String get searchStartTimeMsLabel => '开始时间（毫秒）';

  @override
  String get searchEndTimeMsLabel => '结束时间（毫秒）';

  @override
  String get searchReferenceTimeMsLabel => '参考时间（毫秒）';

  @override
  String get searchBeforeCountLabel => '之前数量';

  @override
  String get searchAfterCountLabel => '之后数量';

  @override
  String get searchModeLabel => '搜索模式';

  @override
  String get searchPageSizeLabel => '分页大小';

  @override
  String get searchModeKeyword => '关键词搜索';

  @override
  String get searchModeUser => '按用户搜索';

  @override
  String get searchModeTimeRange => '按时间范围搜索';

  @override
  String get searchModeAroundTime => '按时间点前后搜索';

  @override
  String fileSizeBytes(int size) {
    return '$size 字节';
  }

  @override
  String get fileDownload => '下载文件';

  @override
  String get fileDownloaded => '已下载';

  @override
  String fileDownloadProgress(int progress) {
    return '下载中 $progress%';
  }

  @override
  String get filePathUnavailable => '文件地址不可用';

  @override
  String get fileOpenFailed => '文件打开失败';

  @override
  String get fileDownloadFailed => '文件下载失败';

  @override
  String get fileSizeUnknown => '未知大小';

  @override
  String photoVideoDuration(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get photoOpenFailed => '视频打开失败';

  @override
  String get photoSaveSucceeded => '已保存到相册';

  @override
  String get photoSaveFailed => '保存失败';

  @override
  String get photoSaveUnsupported => '暂不支持保存到相册';

  @override
  String get forwardConfirmTitle => '确认转发';

  @override
  String forwardConfirmMessage(int count, String target, String mode) {
    return '确定以“$mode”方式转发 $count 条消息给 $target？';
  }

  @override
  String get searchUnsupportedMessagePreview => '[不支持预览的消息]';
}
