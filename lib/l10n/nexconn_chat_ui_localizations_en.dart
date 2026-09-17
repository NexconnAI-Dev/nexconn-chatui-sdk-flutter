// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'nexconn_chat_ui_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class NexconnChatUILocalizationsEn extends NexconnChatUILocalizations {
  NexconnChatUILocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get channelAppBarTitle => 'Chats';

  @override
  String get channelLongPressCancel => 'Cancel';

  @override
  String get channelListEmpty => 'No messages here yet';

  @override
  String get channelActionPin => 'Pin';

  @override
  String get channelActionUnpin => 'Unpin';

  @override
  String get channelActionMute => 'Mute';

  @override
  String get channelActionUnmute => 'Unmute';

  @override
  String get channelActionDelete => 'Delete';

  @override
  String get channelActionFailed => 'Action failed. Please try again.';

  @override
  String get channelSearchPlaceholder => 'Search chats';

  @override
  String get channelNetworkUnavailable =>
      'Network unavailable. Please check your network settings.';

  @override
  String channelGroupTitle(String channelId) {
    return 'Group $channelId';
  }

  @override
  String channelOpenTitle(String channelId) {
    return 'Open channel $channelId';
  }

  @override
  String channelCommunityTitle(String channelId) {
    return 'Community $channelId';
  }

  @override
  String get channelSystemTitle => 'System notifications';

  @override
  String channelDraftPrefix(String draft) {
    return '[Draft] $draft';
  }

  @override
  String get channelUnreadMentionPrefix => '[@You]';

  @override
  String get channelReadStatusSending => 'Sending';

  @override
  String get channelReadStatusFailed => 'Failed';

  @override
  String get channelReadStatusSent => 'Sent';

  @override
  String get channelReadStatusDelivered => 'Delivered';

  @override
  String get channelReadStatusRead => 'Read';

  @override
  String get chatSearchButtonTooltip => 'Search messages';

  @override
  String get chatSearchPageTitle => 'Message Search';

  @override
  String get chatMessageListEmpty => 'No messages here yet';

  @override
  String get chatNetworkUnavailable =>
      'Network unavailable. Please check your network settings.';

  @override
  String get chatUnreadHistoryTip => 'Unread history';

  @override
  String chatUnreadMentionedTip(int count) {
    return '@You ($count)';
  }

  @override
  String get chatNewMessageTip => 'New messages';

  @override
  String get chatTypingStatusTip => 'Typing...';

  @override
  String get chatReadReceiptUsersTitle => 'Read Receipt Users';

  @override
  String get chatReadReceiptUsersReadTab => 'Read';

  @override
  String get chatReadReceiptUsersUnreadTab => 'Unread';

  @override
  String get chatReadReceiptUsersLoading => 'Loading read receipt users';

  @override
  String get chatReadReceiptUsersEmpty => 'No users';

  @override
  String get chatReadReceiptUsersLoadFailed =>
      'Failed to load read receipt users';

  @override
  String get chatLongPressCopy => 'Copy';

  @override
  String get chatLongPressDelete => 'Delete';

  @override
  String get chatLongPressDeleteForMe => 'Delete for me';

  @override
  String get chatLongPressDeleteForEveryone => 'Delete for everyone';

  @override
  String get chatLongPressDeleteForAll => 'Delete for everyone';

  @override
  String get chatLongPressReference => 'Reply';

  @override
  String get chatLongPressMore => 'Multi-select';

  @override
  String get chatLongPressForward => 'Forward';

  @override
  String get chatMessageCopied => 'Message copied.';

  @override
  String get chatDeleteFailed => 'Failed to delete message.';

  @override
  String get chatDeleteForAllFailed => 'Failed to delete message.';

  @override
  String get chatDeleteForAllUnavailable =>
      'This message cannot be deleted for everyone right now.';

  @override
  String get chatReplyAdded => 'Reply added.';

  @override
  String chatSelectionLimit(int count) {
    return 'You can select up to $count messages.';
  }

  @override
  String get chatNoMessagesToForward => 'No messages to forward.';

  @override
  String get chatReferenceMessageCombinedForwardUnsupported =>
      'Reference messages cannot be forwarded as combined.';

  @override
  String chatCombinedForwardSelectionLimit(int count) {
    return 'Combined forwarding supports fewer than $count messages.';
  }

  @override
  String chatForwardedCombined(int count) {
    return 'Forwarded $count messages as combined.';
  }

  @override
  String chatForwarded(int count) {
    return 'Forwarded $count messages.';
  }

  @override
  String get chatForwardFailed => 'Failed to forward messages.';

  @override
  String chatSelectedMessages(int count) {
    return '$count messages selected';
  }

  @override
  String chatSelectedMessagesCount(int count) {
    return '$count messages';
  }

  @override
  String chatSelectedMentionsCount(int count) {
    return '@$count';
  }

  @override
  String get messageInputPluginUnavailable =>
      'This plugin is not available yet';

  @override
  String get messageInputPhotosTitle => 'Photos';

  @override
  String get messageInputPhotoPickerUnavailable =>
      'Photo picker is not available yet';

  @override
  String get messageInputVideoTitle => 'Video';

  @override
  String get messageInputVideoPickerUnavailable =>
      'Video picker is not available yet';

  @override
  String get messageInputCameraTitle => 'Camera';

  @override
  String get messageInputCameraUnavailable => 'Camera is not available yet';

  @override
  String get messageInputFilmingTitle => 'Record';

  @override
  String get messageInputFilmingUnavailable =>
      'Video recording is not available yet';

  @override
  String get messageInputFilesTitle => 'Files';

  @override
  String get messageInputFilePickerUnavailable =>
      'File picker is not available yet';

  @override
  String get messageInputPermissionDenied => 'Permission denied';

  @override
  String get messageInputVideoTooShort => 'Video must be at least 1 second';

  @override
  String get messageInputVideoTooLong => 'Video must be 10 seconds or less';

  @override
  String get messageInputLocationTitle => 'Location';

  @override
  String get messageInputLocationPickerUnavailable =>
      'Location picker is not available yet';

  @override
  String get messageInputHint => 'Message';

  @override
  String get messageInputVoiceUnavailable => 'Voice input is not available yet';

  @override
  String get messageInputEmptyTextWarning => 'Enter a message';

  @override
  String get messageInputEmojiSendButton => 'Send';

  @override
  String get messageInputDeleteEmojiTooltip => 'Delete emoji';

  @override
  String get messageInputEmptyExtensionPanel => 'No plugins available';

  @override
  String get messageInputEmptyMentionCandidates => 'No members available';

  @override
  String get messageInputVoiceAction => 'Send voice';

  @override
  String get messageInputVoiceReleaseToSend =>
      'Release to send  |  Swipe up to cancel';

  @override
  String get messageInputVoiceReleaseToCancel => 'Release to cancel';

  @override
  String get messageInputVoiceTooShort => 'Recording time is too short';

  @override
  String get messageInputVoiceTooLong => 'Recording time exceeds 60 seconds';

  @override
  String get messageInputVoicePermissionDenied =>
      'Microphone permission denied';

  @override
  String get messageInputVoiceRecordFailed => 'Recording failed';

  @override
  String get friendAppBarTitle => 'Friends';

  @override
  String get friendListEmpty => 'No friends yet';

  @override
  String get friendSearchHint => 'Enter a name, remark, or user ID';

  @override
  String get friendSearchEmpty => 'No results';

  @override
  String get friendSearchButton => 'Search';

  @override
  String get friendAddUserIdHint => 'Enter friend user ID';

  @override
  String get friendAddExtraHint => 'Optional request message';

  @override
  String get friendAddSubmit => 'Send friend request';

  @override
  String get friendAddSuccess => 'Friend request sent';

  @override
  String get friendAddEmptyUserId => 'Enter a friend user ID';

  @override
  String get friendApplicationsEmpty => 'No friend requests';

  @override
  String get friendApplicationsLoadFailed => 'Failed to load friend requests';

  @override
  String get friendApplicationsLoadingMore => 'Load more friend requests';

  @override
  String get friendApplicationAccept => 'Accept';

  @override
  String get friendApplicationDecline => 'Decline';

  @override
  String get friendSearchPageTitle => 'Search friends';

  @override
  String get friendAddPageTitle => 'Add friend';

  @override
  String get friendApplicationsPageTitle => 'Friend requests';

  @override
  String get friendRequestFailed => 'Failed to send friend request';

  @override
  String get friendUserIdLabel => 'Friend user ID';

  @override
  String get friendRequestMessageLabel => 'Request message';

  @override
  String get friendUnnamed => 'Unnamed friend';

  @override
  String get groupManagementTitle => 'Group management';

  @override
  String get groupManagementLoadFailed =>
      'Failed to load group management info';

  @override
  String get groupNotFound => 'Group not found';

  @override
  String get groupProfileManagementSection => 'Group profile';

  @override
  String get groupEditProfileAction => 'Edit group profile';

  @override
  String get groupLifecycleSection => 'Group actions';

  @override
  String get groupLeaveAction => 'Leave group';

  @override
  String get groupDismissAction => 'Dismiss group';

  @override
  String get groupLeaveConfirmTitle => 'Leave group';

  @override
  String get groupLeaveConfirmMessage =>
      'Are you sure you want to leave this group?';

  @override
  String get groupDismissConfirmTitle => 'Dismiss group';

  @override
  String get groupDismissConfirmMessage =>
      'Are you sure you want to dismiss this group?';

  @override
  String get groupLeaveSucceeded => 'Left group';

  @override
  String get groupDismissSucceeded => 'Group dismissed';

  @override
  String get groupOperationUnsupported =>
      'This group operation is not supported';

  @override
  String get groupEditProfileTitle => 'Edit group profile';

  @override
  String get groupAvatarUrlLabel => 'Avatar URL';

  @override
  String get groupNoticeLabel => 'Announcement';

  @override
  String get groupIntroductionLabel => 'Description';

  @override
  String get groupProfileUpdated => 'Group profile updated';

  @override
  String get groupMemberManagement => 'Member management';

  @override
  String get groupMembers => 'Group members';

  @override
  String get groupAddMembers => 'Add members';

  @override
  String get groupRemoveMembers => 'Remove members';

  @override
  String get groupAddAdmins => 'Add admins';

  @override
  String get groupRemoveAdmins => 'Remove admins';

  @override
  String get groupTransferOwnership => 'Transfer ownership';

  @override
  String get groupRequests => 'Group requests';

  @override
  String get groupCannotManage => 'Your current role cannot manage this group';

  @override
  String get groupRetry => 'Retry';

  @override
  String get groupCreateTitle => 'Create group';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupNameHint => 'Enter group name';

  @override
  String get groupCreateButton => 'Create group';

  @override
  String get groupCreateFailed => 'Failed to create group';

  @override
  String get groupSearchTitle => 'Search groups';

  @override
  String get groupSearchHint => 'Search groups';

  @override
  String get groupSearchEmpty => 'No groups found';

  @override
  String get groupApplicationsTitle => 'Group requests';

  @override
  String get groupApplicationsEmpty => 'No group requests';

  @override
  String get groupMembersTitle => 'Group members';

  @override
  String get groupMembersEmpty => 'No members';

  @override
  String get groupSelectMembersTitle => 'Select members';

  @override
  String get groupSelectMembersEmpty => 'No users available';

  @override
  String get groupDetailTitle => 'Group details';

  @override
  String get groupFollowMembersTitle => 'Followed members';

  @override
  String get groupFollowMembersEmpty => 'No followed members';

  @override
  String forwardSelectTitle(int count) {
    return 'Select Forward Target ($count)';
  }

  @override
  String get forwardNoChannels => 'No channels available';

  @override
  String get forwardIndividually => 'Forward one by one';

  @override
  String get forwardAsCombined => 'Merge and forward';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonUnknownUser => 'Unknown user';

  @override
  String get photoImageUnavailable => 'Image unavailable';

  @override
  String get photoVideoPreview => 'Video Preview';

  @override
  String get photoOpenVideo => 'Open Video';

  @override
  String get filePreviewTitle => 'File Preview';

  @override
  String get fileUntitled => 'Untitled file';

  @override
  String get fileOpen => 'Open File';

  @override
  String get readReceiptCloseTooltip => 'Close';

  @override
  String readReceiptReadAt(String time) {
    return 'Read at $time';
  }

  @override
  String get messageDeletedForEveryone =>
      'This message was deleted for everyone';

  @override
  String get messageSummaryReply => '[Reply]';

  @override
  String get messageSummaryImage => '[Image]';

  @override
  String get messageSummaryGif => '[GIF]';

  @override
  String get messageSummaryVoice => '[Voice]';

  @override
  String get messageSummaryVideo => '[Video]';

  @override
  String get messageSummaryFile => '[File]';

  @override
  String get messageSummaryLocation => '[Location]';

  @override
  String get messageSummaryCombinedForward => '[Combined Forward]';

  @override
  String get combineMessageChatHistoryLabel => 'Chat History';

  @override
  String get combineMessageGroupChatHistoryTitle => 'Group Chat History';

  @override
  String combineMessageTitle(String names) {
    return '$names\'s Chat History';
  }

  @override
  String combineMessageTimeYesterday(String time) {
    return 'Yesterday $time';
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
  String get combineMessageLoadFailed => 'Failed to load combined message';

  @override
  String get messageSummaryGroupNotification => '[Group Notification]';

  @override
  String get messageSummaryUnknown => 'Unknown Message';

  @override
  String get commonWeekdayMonday => 'Mon';

  @override
  String get commonWeekdayTuesday => 'Tue';

  @override
  String get commonWeekdayWednesday => 'Wed';

  @override
  String get commonWeekdayThursday => 'Thu';

  @override
  String get commonWeekdayFriday => 'Fri';

  @override
  String get commonWeekdaySaturday => 'Sat';

  @override
  String get commonWeekdaySunday => 'Sun';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get messageInputSendTooltip => 'Send';

  @override
  String messageInputReplyTo(String sender, String summary) {
    return 'Reply to $sender: $summary';
  }

  @override
  String get messageInputCancelReplyTooltip => 'Cancel reply';

  @override
  String get messageInputSwitchToTextTooltip => 'Switch to text';

  @override
  String get messageInputVoiceTooltip => 'Voice input';

  @override
  String get messageInputHideEmojiPanelTooltip => 'Hide emoji panel';

  @override
  String get messageInputEmojiPanelTooltip => 'Emoji panel';

  @override
  String get messageInputHideExtensionPanelTooltip => 'Hide attachment panel';

  @override
  String get messageInputExtensionPanelTooltip => 'Attachment panel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonDecline => 'Decline';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonOperationFailed => 'Operation failed';

  @override
  String get commonUnsupported => 'Unsupported';

  @override
  String get groupPageTitle => 'My groups';

  @override
  String get groupCreateTooltip => 'Create group';

  @override
  String get groupSearchTooltip => 'Search groups';

  @override
  String get groupLoadFailed => 'Failed to load groups';

  @override
  String get groupEmptyJoined => 'No joined groups';

  @override
  String groupMemberCount(int count) {
    return '$count members';
  }

  @override
  String groupSelectedMembersCount(int count) {
    return '$count selected';
  }

  @override
  String groupFollowedCount(int count) {
    return '$count followed';
  }

  @override
  String get groupCreatePageTitle => 'Create group';

  @override
  String get groupIdLabel => 'Group ID';

  @override
  String get groupIdAutoGenerateHint => 'Leave blank to auto-generate';

  @override
  String get groupSelectMembersLabel => 'Select members';

  @override
  String get groupSearchContactsHint => 'Search contacts';

  @override
  String get groupLoadContactsFailed => 'Failed to load contacts';

  @override
  String get groupNoContactsAvailable => 'No contacts available';

  @override
  String get groupNameRequired => 'Enter a group name';

  @override
  String get groupSelectAtLeastOneMember => 'Select at least one member';

  @override
  String get groupSearchPageTitle => 'Search groups';

  @override
  String get groupSearchNameHint => 'Enter group name';

  @override
  String get groupSearchKeywordEmpty => 'Enter a keyword to search groups';

  @override
  String get groupSearchFailed => 'Search failed';

  @override
  String get groupDetailsPageTitle => 'Group details';

  @override
  String get groupDetailsLoadFailed => 'Failed to load group details';

  @override
  String get groupAnnouncementLabel => 'Announcement';

  @override
  String get groupDescriptionLabel => 'Description';

  @override
  String get groupMembersLabel => 'Members';

  @override
  String get groupMyRoleLabel => 'My role';

  @override
  String get groupMembersPageTitle => 'Group members';

  @override
  String get groupFollowedMembersTitle => 'Followed members';

  @override
  String get groupAddMembersTitle => 'Add members';

  @override
  String get groupRemoveMembersTitle => 'Remove members';

  @override
  String get groupAddAdminsTitle => 'Add admins';

  @override
  String get groupRemoveAdminsTitle => 'Remove admins';

  @override
  String get groupTransferOwnershipTitle => 'Transfer ownership';

  @override
  String get groupRequestsTitle => 'Group requests';

  @override
  String get groupMemberManagementSection => 'Member management';

  @override
  String get groupAdminManagementSection => 'Admin management';

  @override
  String get groupRequestManagementSection => 'Request management';

  @override
  String get groupCurrentRoleCannotManage =>
      'Your current role cannot manage this group';

  @override
  String get groupMembersLoadFailed => 'Failed to load group members';

  @override
  String get groupNoMembers => 'No group members';

  @override
  String get groupFollowedMembersLoadFailed =>
      'Failed to load followed members';

  @override
  String get groupFollowedMembersSubtitle =>
      'Follow key members for quick access';

  @override
  String get groupFollowAction => 'Follow';

  @override
  String get groupUnfollowAction => 'Unfollow';

  @override
  String get groupRequestsLoadFailed => 'Failed to load group requests';

  @override
  String get groupNoPendingRequests => 'No pending group requests';

  @override
  String groupApplicationGroupPrefix(String groupId) {
    return 'Group: $groupId';
  }

  @override
  String get groupNoMembersAvailable => 'No members available';

  @override
  String groupMemberActionSucceeded(String action) {
    return '$action succeeded';
  }

  @override
  String get friendLoadFailed => 'Failed to load friends';

  @override
  String get friendSearchTooltip => 'Search friends';

  @override
  String get friendAddTooltip => 'Add friend';

  @override
  String get friendRequestsTooltip => 'Friend requests';

  @override
  String get friendSearchFailed => 'Failed to search friends';

  @override
  String get friendSearchPrompt => 'Enter a keyword, then tap Search';

  @override
  String get friendRequestAccepted => 'Friend request accepted';

  @override
  String get friendRequestDeclined => 'Friend request declined';

  @override
  String get friendRequestHandleFailed => 'Failed to handle friend request';

  @override
  String get friendApplicationUnnamed => 'Unnamed request';

  @override
  String get friendApplicationSentRequest => 'Sent request';

  @override
  String get friendApplicationReceivedRequest => 'Received request';

  @override
  String get friendApplicationFriendRequest => 'Friend request';

  @override
  String get friendApplicationPending => 'Pending';

  @override
  String get friendApplicationAccepted => 'Accepted';

  @override
  String get friendApplicationDeclined => 'Declined';

  @override
  String get friendApplicationExpired => 'Expired';

  @override
  String friendApplicationHandledAt(String time) {
    return 'Handled $time';
  }

  @override
  String get userProfileTitle => 'User Profile';

  @override
  String get userProfileEmpty => 'No profile information';

  @override
  String get userProfileLoadFailed => 'Failed to load user profile';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get userProfileUserIdLabel => 'User ID';

  @override
  String get userProfileUniqueIdLabel => 'Unique ID';

  @override
  String get userProfileEmailLabel => 'Email';

  @override
  String get userProfileBirthdayLabel => 'Birthday';

  @override
  String get userProfileGenderLabel => 'Gender';

  @override
  String get userProfileLocationLabel => 'Location';

  @override
  String get userProfileRoleLabel => 'Role';

  @override
  String get userProfileLevelLabel => 'Level';

  @override
  String get userProfileExtProfileLabel => 'Extended profile';

  @override
  String get userProfileActionStartChat => 'Message';

  @override
  String get userProfileActionAddFriend => 'Add friend';

  @override
  String get userProfileActionDeleteFriend => 'Delete friend';

  @override
  String get userProfileActionUpdateRemark => 'Edit remark';

  @override
  String get userProfileActionUnsupported => 'This action is not available';

  @override
  String get userProfileActionFailed => 'Action failed. Please try again.';

  @override
  String get userProfileAddFriendSuccess => 'Friend request sent';

  @override
  String get userProfileDeleteFriendSuccess => 'Friend deleted';

  @override
  String get userProfileRemarkSuccess => 'Remark updated';

  @override
  String get userProfileDeleteFriendConfirmTitle => 'Delete friend';

  @override
  String get userProfileDeleteFriendConfirmMessage =>
      'Are you sure you want to delete this friend?';

  @override
  String get userProfileRemarkDialogTitle => 'Edit friend remark';

  @override
  String get userProfileRemarkLabel => 'Remark';

  @override
  String get searchResultsTitle => 'Search Results';

  @override
  String get searchNoMatchingMessages => 'No matching messages';

  @override
  String searchResultsCount(int count) {
    return 'Results: $count';
  }

  @override
  String get chatSearchFailed => 'Search failed';

  @override
  String get searchKeywordLabel => 'Keyword';

  @override
  String get searchUserIdLabel => 'User ID';

  @override
  String get searchStartTimeMsLabel => 'Start time (ms)';

  @override
  String get searchEndTimeMsLabel => 'End time (ms)';

  @override
  String get searchReferenceTimeMsLabel => 'Reference time (ms)';

  @override
  String get searchBeforeCountLabel => 'Before count';

  @override
  String get searchAfterCountLabel => 'After count';

  @override
  String get searchModeLabel => 'Search mode';

  @override
  String get searchPageSizeLabel => 'Page size';

  @override
  String get searchModeKeyword => 'Keyword search';

  @override
  String get searchModeUser => 'Search by user';

  @override
  String get searchModeTimeRange => 'Search by time range';

  @override
  String get searchModeAroundTime => 'Search around time';

  @override
  String fileSizeBytes(int size) {
    return '$size bytes';
  }

  @override
  String get fileDownload => 'Download File';

  @override
  String get fileDownloaded => 'Downloaded';

  @override
  String fileDownloadProgress(int progress) {
    return 'Downloading $progress%';
  }

  @override
  String get filePathUnavailable => 'File path unavailable';

  @override
  String get fileOpenFailed => 'Failed to open file';

  @override
  String get fileDownloadFailed => 'Failed to download file';

  @override
  String get fileSizeUnknown => 'Unknown size';

  @override
  String photoVideoDuration(int seconds) {
    return '$seconds s';
  }

  @override
  String get photoOpenFailed => 'Failed to open video';

  @override
  String get photoSaveSucceeded => 'Saved to album';

  @override
  String get photoSaveFailed => 'Failed to save';

  @override
  String get photoSaveUnsupported => 'Saving to the album is not available yet';

  @override
  String get forwardConfirmTitle => 'Confirm Forward';

  @override
  String forwardConfirmMessage(int count, String target, String mode) {
    return 'Forward $count message(s) to $target as $mode?';
  }

  @override
  String get searchUnsupportedMessagePreview => '[Unsupported message]';
}
