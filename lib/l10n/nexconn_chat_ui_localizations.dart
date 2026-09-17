import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'nexconn_chat_ui_localizations_en.dart';
import 'nexconn_chat_ui_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of NexconnChatUILocalizations
/// returned by `NexconnChatUILocalizations.of(context)`.
///
/// Applications need to include `NexconnChatUILocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/nexconn_chat_ui_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: NexconnChatUILocalizations.localizationsDelegates,
///   supportedLocales: NexconnChatUILocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the NexconnChatUILocalizations.supportedLocales
/// property.
abstract class NexconnChatUILocalizations {
  NexconnChatUILocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static NexconnChatUILocalizations of(BuildContext context) {
    return Localizations.of<NexconnChatUILocalizations>(
      context,
      NexconnChatUILocalizations,
    )!;
  }

  static const LocalizationsDelegate<NexconnChatUILocalizations> delegate =
      _NexconnChatUILocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @channelAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get channelAppBarTitle;

  /// No description provided for @channelLongPressCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get channelLongPressCancel;

  /// No description provided for @channelListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages here yet'**
  String get channelListEmpty;

  /// No description provided for @channelActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get channelActionPin;

  /// No description provided for @channelActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get channelActionUnpin;

  /// No description provided for @channelActionMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get channelActionMute;

  /// No description provided for @channelActionUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get channelActionUnmute;

  /// No description provided for @channelActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get channelActionDelete;

  /// No description provided for @channelActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed. Please try again.'**
  String get channelActionFailed;

  /// No description provided for @channelSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search chats'**
  String get channelSearchPlaceholder;

  /// No description provided for @channelNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable. Please check your network settings.'**
  String get channelNetworkUnavailable;

  /// No description provided for @channelGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Group {channelId}'**
  String channelGroupTitle(String channelId);

  /// No description provided for @channelOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Open channel {channelId}'**
  String channelOpenTitle(String channelId);

  /// No description provided for @channelCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community {channelId}'**
  String channelCommunityTitle(String channelId);

  /// No description provided for @channelSystemTitle.
  ///
  /// In en, this message translates to:
  /// **'System notifications'**
  String get channelSystemTitle;

  /// No description provided for @channelDraftPrefix.
  ///
  /// In en, this message translates to:
  /// **'[Draft] {draft}'**
  String channelDraftPrefix(String draft);

  /// No description provided for @channelUnreadMentionPrefix.
  ///
  /// In en, this message translates to:
  /// **'[@You]'**
  String get channelUnreadMentionPrefix;

  /// No description provided for @channelReadStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get channelReadStatusSending;

  /// No description provided for @channelReadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get channelReadStatusFailed;

  /// No description provided for @channelReadStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get channelReadStatusSent;

  /// No description provided for @channelReadStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get channelReadStatusDelivered;

  /// No description provided for @channelReadStatusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get channelReadStatusRead;

  /// No description provided for @chatSearchButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchButtonTooltip;

  /// No description provided for @chatSearchPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Message Search'**
  String get chatSearchPageTitle;

  /// No description provided for @chatMessageListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages here yet'**
  String get chatMessageListEmpty;

  /// No description provided for @chatNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable. Please check your network settings.'**
  String get chatNetworkUnavailable;

  /// No description provided for @chatUnreadHistoryTip.
  ///
  /// In en, this message translates to:
  /// **'Unread history'**
  String get chatUnreadHistoryTip;

  /// No description provided for @chatUnreadMentionedTip.
  ///
  /// In en, this message translates to:
  /// **'@You ({count})'**
  String chatUnreadMentionedTip(int count);

  /// No description provided for @chatNewMessageTip.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get chatNewMessageTip;

  /// No description provided for @chatTypingStatusTip.
  ///
  /// In en, this message translates to:
  /// **'Typing...'**
  String get chatTypingStatusTip;

  /// No description provided for @chatReadReceiptUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Read Receipt Users'**
  String get chatReadReceiptUsersTitle;

  /// No description provided for @chatReadReceiptUsersReadTab.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatReadReceiptUsersReadTab;

  /// No description provided for @chatReadReceiptUsersUnreadTab.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chatReadReceiptUsersUnreadTab;

  /// No description provided for @chatReadReceiptUsersLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading read receipt users'**
  String get chatReadReceiptUsersLoading;

  /// No description provided for @chatReadReceiptUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users'**
  String get chatReadReceiptUsersEmpty;

  /// No description provided for @chatReadReceiptUsersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load read receipt users'**
  String get chatReadReceiptUsersLoadFailed;

  /// No description provided for @chatLongPressCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatLongPressCopy;

  /// No description provided for @chatLongPressDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatLongPressDelete;

  /// No description provided for @chatLongPressDeleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get chatLongPressDeleteForMe;

  /// No description provided for @chatLongPressDeleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get chatLongPressDeleteForEveryone;

  /// No description provided for @chatLongPressDeleteForAll.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get chatLongPressDeleteForAll;

  /// No description provided for @chatLongPressReference.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatLongPressReference;

  /// No description provided for @chatLongPressMore.
  ///
  /// In en, this message translates to:
  /// **'Multi-select'**
  String get chatLongPressMore;

  /// No description provided for @chatLongPressForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatLongPressForward;

  /// No description provided for @chatMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'Message copied.'**
  String get chatMessageCopied;

  /// No description provided for @chatDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message.'**
  String get chatDeleteFailed;

  /// No description provided for @chatDeleteForAllFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete message.'**
  String get chatDeleteForAllFailed;

  /// No description provided for @chatDeleteForAllUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This message cannot be deleted for everyone right now.'**
  String get chatDeleteForAllUnavailable;

  /// No description provided for @chatReplyAdded.
  ///
  /// In en, this message translates to:
  /// **'Reply added.'**
  String get chatReplyAdded;

  /// No description provided for @chatSelectionLimit.
  ///
  /// In en, this message translates to:
  /// **'You can select up to {count} messages.'**
  String chatSelectionLimit(int count);

  /// No description provided for @chatNoMessagesToForward.
  ///
  /// In en, this message translates to:
  /// **'No messages to forward.'**
  String get chatNoMessagesToForward;

  /// No description provided for @chatReferenceMessageCombinedForwardUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reference messages cannot be forwarded as combined.'**
  String get chatReferenceMessageCombinedForwardUnsupported;

  /// No description provided for @chatCombinedForwardSelectionLimit.
  ///
  /// In en, this message translates to:
  /// **'Combined forwarding supports fewer than {count} messages.'**
  String chatCombinedForwardSelectionLimit(int count);

  /// No description provided for @chatForwardedCombined.
  ///
  /// In en, this message translates to:
  /// **'Forwarded {count} messages as combined.'**
  String chatForwardedCombined(int count);

  /// No description provided for @chatForwarded.
  ///
  /// In en, this message translates to:
  /// **'Forwarded {count} messages.'**
  String chatForwarded(int count);

  /// No description provided for @chatForwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to forward messages.'**
  String get chatForwardFailed;

  /// No description provided for @chatSelectedMessages.
  ///
  /// In en, this message translates to:
  /// **'{count} messages selected'**
  String chatSelectedMessages(int count);

  /// No description provided for @chatSelectedMessagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} messages'**
  String chatSelectedMessagesCount(int count);

  /// No description provided for @chatSelectedMentionsCount.
  ///
  /// In en, this message translates to:
  /// **'@{count}'**
  String chatSelectedMentionsCount(int count);

  /// No description provided for @messageInputPluginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This plugin is not available yet'**
  String get messageInputPluginUnavailable;

  /// No description provided for @messageInputPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get messageInputPhotosTitle;

  /// No description provided for @messageInputPhotoPickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo picker is not available yet'**
  String get messageInputPhotoPickerUnavailable;

  /// No description provided for @messageInputVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get messageInputVideoTitle;

  /// No description provided for @messageInputVideoPickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video picker is not available yet'**
  String get messageInputVideoPickerUnavailable;

  /// No description provided for @messageInputCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get messageInputCameraTitle;

  /// No description provided for @messageInputCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available yet'**
  String get messageInputCameraUnavailable;

  /// No description provided for @messageInputFilmingTitle.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get messageInputFilmingTitle;

  /// No description provided for @messageInputFilmingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Video recording is not available yet'**
  String get messageInputFilmingUnavailable;

  /// No description provided for @messageInputFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get messageInputFilesTitle;

  /// No description provided for @messageInputFilePickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File picker is not available yet'**
  String get messageInputFilePickerUnavailable;

  /// No description provided for @messageInputPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get messageInputPermissionDenied;

  /// No description provided for @messageInputVideoTooShort.
  ///
  /// In en, this message translates to:
  /// **'Video must be at least 1 second'**
  String get messageInputVideoTooShort;

  /// No description provided for @messageInputVideoTooLong.
  ///
  /// In en, this message translates to:
  /// **'Video must be 10 seconds or less'**
  String get messageInputVideoTooLong;

  /// No description provided for @messageInputLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get messageInputLocationTitle;

  /// No description provided for @messageInputLocationPickerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location picker is not available yet'**
  String get messageInputLocationPickerUnavailable;

  /// No description provided for @messageInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageInputHint;

  /// No description provided for @messageInputVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input is not available yet'**
  String get messageInputVoiceUnavailable;

  /// No description provided for @messageInputEmptyTextWarning.
  ///
  /// In en, this message translates to:
  /// **'Enter a message'**
  String get messageInputEmptyTextWarning;

  /// No description provided for @messageInputEmojiSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messageInputEmojiSendButton;

  /// No description provided for @messageInputDeleteEmojiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete emoji'**
  String get messageInputDeleteEmojiTooltip;

  /// No description provided for @messageInputEmptyExtensionPanel.
  ///
  /// In en, this message translates to:
  /// **'No plugins available'**
  String get messageInputEmptyExtensionPanel;

  /// No description provided for @messageInputEmptyMentionCandidates.
  ///
  /// In en, this message translates to:
  /// **'No members available'**
  String get messageInputEmptyMentionCandidates;

  /// No description provided for @messageInputVoiceAction.
  ///
  /// In en, this message translates to:
  /// **'Send voice'**
  String get messageInputVoiceAction;

  /// No description provided for @messageInputVoiceReleaseToSend.
  ///
  /// In en, this message translates to:
  /// **'Release to send  |  Swipe up to cancel'**
  String get messageInputVoiceReleaseToSend;

  /// No description provided for @messageInputVoiceReleaseToCancel.
  ///
  /// In en, this message translates to:
  /// **'Release to cancel'**
  String get messageInputVoiceReleaseToCancel;

  /// No description provided for @messageInputVoiceTooShort.
  ///
  /// In en, this message translates to:
  /// **'Recording time is too short'**
  String get messageInputVoiceTooShort;

  /// No description provided for @messageInputVoiceTooLong.
  ///
  /// In en, this message translates to:
  /// **'Recording time exceeds 60 seconds'**
  String get messageInputVoiceTooLong;

  /// No description provided for @messageInputVoicePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get messageInputVoicePermissionDenied;

  /// No description provided for @messageInputVoiceRecordFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed'**
  String get messageInputVoiceRecordFailed;

  /// No description provided for @friendAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendAppBarTitle;

  /// No description provided for @friendListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendListEmpty;

  /// No description provided for @friendSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a name, remark, or user ID'**
  String get friendSearchHint;

  /// No description provided for @friendSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get friendSearchEmpty;

  /// No description provided for @friendSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get friendSearchButton;

  /// No description provided for @friendAddUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Enter friend user ID'**
  String get friendAddUserIdHint;

  /// No description provided for @friendAddExtraHint.
  ///
  /// In en, this message translates to:
  /// **'Optional request message'**
  String get friendAddExtraHint;

  /// No description provided for @friendAddSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send friend request'**
  String get friendAddSubmit;

  /// No description provided for @friendAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get friendAddSuccess;

  /// No description provided for @friendAddEmptyUserId.
  ///
  /// In en, this message translates to:
  /// **'Enter a friend user ID'**
  String get friendAddEmptyUserId;

  /// No description provided for @friendApplicationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friend requests'**
  String get friendApplicationsEmpty;

  /// No description provided for @friendApplicationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load friend requests'**
  String get friendApplicationsLoadFailed;

  /// No description provided for @friendApplicationsLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Load more friend requests'**
  String get friendApplicationsLoadingMore;

  /// No description provided for @friendApplicationAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendApplicationAccept;

  /// No description provided for @friendApplicationDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendApplicationDecline;

  /// No description provided for @friendSearchPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get friendSearchPageTitle;

  /// No description provided for @friendAddPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get friendAddPageTitle;

  /// No description provided for @friendApplicationsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendApplicationsPageTitle;

  /// No description provided for @friendRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send friend request'**
  String get friendRequestFailed;

  /// No description provided for @friendUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Friend user ID'**
  String get friendUserIdLabel;

  /// No description provided for @friendRequestMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Request message'**
  String get friendRequestMessageLabel;

  /// No description provided for @friendUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed friend'**
  String get friendUnnamed;

  /// No description provided for @groupManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Group management'**
  String get groupManagementTitle;

  /// No description provided for @groupManagementLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load group management info'**
  String get groupManagementLoadFailed;

  /// No description provided for @groupNotFound.
  ///
  /// In en, this message translates to:
  /// **'Group not found'**
  String get groupNotFound;

  /// No description provided for @groupProfileManagementSection.
  ///
  /// In en, this message translates to:
  /// **'Group profile'**
  String get groupProfileManagementSection;

  /// No description provided for @groupEditProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Edit group profile'**
  String get groupEditProfileAction;

  /// No description provided for @groupLifecycleSection.
  ///
  /// In en, this message translates to:
  /// **'Group actions'**
  String get groupLifecycleSection;

  /// No description provided for @groupLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeaveAction;

  /// No description provided for @groupDismissAction.
  ///
  /// In en, this message translates to:
  /// **'Dismiss group'**
  String get groupDismissAction;

  /// No description provided for @groupLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeaveConfirmTitle;

  /// No description provided for @groupLeaveConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get groupLeaveConfirmMessage;

  /// No description provided for @groupDismissConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Dismiss group'**
  String get groupDismissConfirmTitle;

  /// No description provided for @groupDismissConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to dismiss this group?'**
  String get groupDismissConfirmMessage;

  /// No description provided for @groupLeaveSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Left group'**
  String get groupLeaveSucceeded;

  /// No description provided for @groupDismissSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Group dismissed'**
  String get groupDismissSucceeded;

  /// No description provided for @groupOperationUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This group operation is not supported'**
  String get groupOperationUnsupported;

  /// No description provided for @groupEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit group profile'**
  String get groupEditProfileTitle;

  /// No description provided for @groupAvatarUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Avatar URL'**
  String get groupAvatarUrlLabel;

  /// No description provided for @groupNoticeLabel.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get groupNoticeLabel;

  /// No description provided for @groupIntroductionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get groupIntroductionLabel;

  /// No description provided for @groupProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Group profile updated'**
  String get groupProfileUpdated;

  /// No description provided for @groupMemberManagement.
  ///
  /// In en, this message translates to:
  /// **'Member management'**
  String get groupMemberManagement;

  /// No description provided for @groupMembers.
  ///
  /// In en, this message translates to:
  /// **'Group members'**
  String get groupMembers;

  /// No description provided for @groupAddMembers.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get groupAddMembers;

  /// No description provided for @groupRemoveMembers.
  ///
  /// In en, this message translates to:
  /// **'Remove members'**
  String get groupRemoveMembers;

  /// No description provided for @groupAddAdmins.
  ///
  /// In en, this message translates to:
  /// **'Add admins'**
  String get groupAddAdmins;

  /// No description provided for @groupRemoveAdmins.
  ///
  /// In en, this message translates to:
  /// **'Remove admins'**
  String get groupRemoveAdmins;

  /// No description provided for @groupTransferOwnership.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get groupTransferOwnership;

  /// No description provided for @groupRequests.
  ///
  /// In en, this message translates to:
  /// **'Group requests'**
  String get groupRequests;

  /// No description provided for @groupCannotManage.
  ///
  /// In en, this message translates to:
  /// **'Your current role cannot manage this group'**
  String get groupCannotManage;

  /// No description provided for @groupRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get groupRetry;

  /// No description provided for @groupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreateTitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get groupNameHint;

  /// No description provided for @groupCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreateButton;

  /// No description provided for @groupCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create group'**
  String get groupCreateFailed;

  /// No description provided for @groupSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get groupSearchTitle;

  /// No description provided for @groupSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get groupSearchHint;

  /// No description provided for @groupSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No groups found'**
  String get groupSearchEmpty;

  /// No description provided for @groupApplicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group requests'**
  String get groupApplicationsTitle;

  /// No description provided for @groupApplicationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No group requests'**
  String get groupApplicationsEmpty;

  /// No description provided for @groupMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Group members'**
  String get groupMembersTitle;

  /// No description provided for @groupMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members'**
  String get groupMembersEmpty;

  /// No description provided for @groupSelectMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Select members'**
  String get groupSelectMembersTitle;

  /// No description provided for @groupSelectMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users available'**
  String get groupSelectMembersEmpty;

  /// No description provided for @groupDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Group details'**
  String get groupDetailTitle;

  /// No description provided for @groupFollowMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followed members'**
  String get groupFollowMembersTitle;

  /// No description provided for @groupFollowMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No followed members'**
  String get groupFollowMembersEmpty;

  /// No description provided for @forwardSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Forward Target ({count})'**
  String forwardSelectTitle(int count);

  /// No description provided for @forwardNoChannels.
  ///
  /// In en, this message translates to:
  /// **'No channels available'**
  String get forwardNoChannels;

  /// No description provided for @forwardIndividually.
  ///
  /// In en, this message translates to:
  /// **'Forward one by one'**
  String get forwardIndividually;

  /// No description provided for @forwardAsCombined.
  ///
  /// In en, this message translates to:
  /// **'Merge and forward'**
  String get forwardAsCombined;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get commonUnknownUser;

  /// No description provided for @photoImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get photoImageUnavailable;

  /// No description provided for @photoVideoPreview.
  ///
  /// In en, this message translates to:
  /// **'Video Preview'**
  String get photoVideoPreview;

  /// No description provided for @photoOpenVideo.
  ///
  /// In en, this message translates to:
  /// **'Open Video'**
  String get photoOpenVideo;

  /// No description provided for @filePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'File Preview'**
  String get filePreviewTitle;

  /// No description provided for @fileUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled file'**
  String get fileUntitled;

  /// No description provided for @fileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open File'**
  String get fileOpen;

  /// No description provided for @readReceiptCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get readReceiptCloseTooltip;

  /// No description provided for @readReceiptReadAt.
  ///
  /// In en, this message translates to:
  /// **'Read at {time}'**
  String readReceiptReadAt(String time);

  /// No description provided for @messageDeletedForEveryone.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted for everyone'**
  String get messageDeletedForEveryone;

  /// No description provided for @messageSummaryReply.
  ///
  /// In en, this message translates to:
  /// **'[Reply]'**
  String get messageSummaryReply;

  /// No description provided for @messageSummaryImage.
  ///
  /// In en, this message translates to:
  /// **'[Image]'**
  String get messageSummaryImage;

  /// No description provided for @messageSummaryGif.
  ///
  /// In en, this message translates to:
  /// **'[GIF]'**
  String get messageSummaryGif;

  /// No description provided for @messageSummaryVoice.
  ///
  /// In en, this message translates to:
  /// **'[Voice]'**
  String get messageSummaryVoice;

  /// No description provided for @messageSummaryVideo.
  ///
  /// In en, this message translates to:
  /// **'[Video]'**
  String get messageSummaryVideo;

  /// No description provided for @messageSummaryFile.
  ///
  /// In en, this message translates to:
  /// **'[File]'**
  String get messageSummaryFile;

  /// No description provided for @messageSummaryLocation.
  ///
  /// In en, this message translates to:
  /// **'[Location]'**
  String get messageSummaryLocation;

  /// No description provided for @messageSummaryCombinedForward.
  ///
  /// In en, this message translates to:
  /// **'[Combined Forward]'**
  String get messageSummaryCombinedForward;

  /// No description provided for @combineMessageChatHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get combineMessageChatHistoryLabel;

  /// No description provided for @combineMessageGroupChatHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Chat History'**
  String get combineMessageGroupChatHistoryTitle;

  /// No description provided for @combineMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'{names}\'s Chat History'**
  String combineMessageTitle(String names);

  /// No description provided for @combineMessageTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String combineMessageTimeYesterday(String time);

  /// No description provided for @combineMessageTimeWeekday.
  ///
  /// In en, this message translates to:
  /// **'{weekday} {time}'**
  String combineMessageTimeWeekday(String weekday, String time);

  /// No description provided for @combineMessageTimeDate.
  ///
  /// In en, this message translates to:
  /// **'{date} {time}'**
  String combineMessageTimeDate(String date, String time);

  /// No description provided for @combineMessageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load combined message'**
  String get combineMessageLoadFailed;

  /// No description provided for @messageSummaryGroupNotification.
  ///
  /// In en, this message translates to:
  /// **'[Group Notification]'**
  String get messageSummaryGroupNotification;

  /// No description provided for @messageSummaryUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Message'**
  String get messageSummaryUnknown;

  /// No description provided for @commonWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get commonWeekdayMonday;

  /// No description provided for @commonWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get commonWeekdayTuesday;

  /// No description provided for @commonWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get commonWeekdayWednesday;

  /// No description provided for @commonWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get commonWeekdayThursday;

  /// No description provided for @commonWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get commonWeekdayFriday;

  /// No description provided for @commonWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get commonWeekdaySaturday;

  /// No description provided for @commonWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get commonWeekdaySunday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @messageInputSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messageInputSendTooltip;

  /// No description provided for @messageInputReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {sender}: {summary}'**
  String messageInputReplyTo(String sender, String summary);

  /// No description provided for @messageInputCancelReplyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get messageInputCancelReplyTooltip;

  /// No description provided for @messageInputSwitchToTextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to text'**
  String get messageInputSwitchToTextTooltip;

  /// No description provided for @messageInputVoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get messageInputVoiceTooltip;

  /// No description provided for @messageInputHideEmojiPanelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide emoji panel'**
  String get messageInputHideEmojiPanelTooltip;

  /// No description provided for @messageInputEmojiPanelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Emoji panel'**
  String get messageInputEmojiPanelTooltip;

  /// No description provided for @messageInputHideExtensionPanelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide attachment panel'**
  String get messageInputHideExtensionPanelTooltip;

  /// No description provided for @messageInputExtensionPanelTooltip.
  ///
  /// In en, this message translates to:
  /// **'Attachment panel'**
  String get messageInputExtensionPanelTooltip;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get commonAccept;

  /// No description provided for @commonDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get commonDecline;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get commonOperationFailed;

  /// No description provided for @commonUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get commonUnsupported;

  /// No description provided for @groupPageTitle.
  ///
  /// In en, this message translates to:
  /// **'My groups'**
  String get groupPageTitle;

  /// No description provided for @groupCreateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreateTooltip;

  /// No description provided for @groupSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get groupSearchTooltip;

  /// No description provided for @groupLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load groups'**
  String get groupLoadFailed;

  /// No description provided for @groupEmptyJoined.
  ///
  /// In en, this message translates to:
  /// **'No joined groups'**
  String get groupEmptyJoined;

  /// No description provided for @groupMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String groupMemberCount(int count);

  /// No description provided for @groupSelectedMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String groupSelectedMembersCount(int count);

  /// No description provided for @groupFollowedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} followed'**
  String groupFollowedCount(int count);

  /// No description provided for @groupCreatePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreatePageTitle;

  /// No description provided for @groupIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Group ID'**
  String get groupIdLabel;

  /// No description provided for @groupIdAutoGenerateHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-generate'**
  String get groupIdAutoGenerateHint;

  /// No description provided for @groupSelectMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Select members'**
  String get groupSelectMembersLabel;

  /// No description provided for @groupSearchContactsHint.
  ///
  /// In en, this message translates to:
  /// **'Search contacts'**
  String get groupSearchContactsHint;

  /// No description provided for @groupLoadContactsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load contacts'**
  String get groupLoadContactsFailed;

  /// No description provided for @groupNoContactsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No contacts available'**
  String get groupNoContactsAvailable;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a group name'**
  String get groupNameRequired;

  /// No description provided for @groupSelectAtLeastOneMember.
  ///
  /// In en, this message translates to:
  /// **'Select at least one member'**
  String get groupSelectAtLeastOneMember;

  /// No description provided for @groupSearchPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Search groups'**
  String get groupSearchPageTitle;

  /// No description provided for @groupSearchNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get groupSearchNameHint;

  /// No description provided for @groupSearchKeywordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword to search groups'**
  String get groupSearchKeywordEmpty;

  /// No description provided for @groupSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get groupSearchFailed;

  /// No description provided for @groupDetailsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Group details'**
  String get groupDetailsPageTitle;

  /// No description provided for @groupDetailsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load group details'**
  String get groupDetailsLoadFailed;

  /// No description provided for @groupAnnouncementLabel.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get groupAnnouncementLabel;

  /// No description provided for @groupDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get groupDescriptionLabel;

  /// No description provided for @groupMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembersLabel;

  /// No description provided for @groupMyRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'My role'**
  String get groupMyRoleLabel;

  /// No description provided for @groupMembersPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Group members'**
  String get groupMembersPageTitle;

  /// No description provided for @groupFollowedMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followed members'**
  String get groupFollowedMembersTitle;

  /// No description provided for @groupAddMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Add members'**
  String get groupAddMembersTitle;

  /// No description provided for @groupRemoveMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove members'**
  String get groupRemoveMembersTitle;

  /// No description provided for @groupAddAdminsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add admins'**
  String get groupAddAdminsTitle;

  /// No description provided for @groupRemoveAdminsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove admins'**
  String get groupRemoveAdminsTitle;

  /// No description provided for @groupTransferOwnershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get groupTransferOwnershipTitle;

  /// No description provided for @groupRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group requests'**
  String get groupRequestsTitle;

  /// No description provided for @groupMemberManagementSection.
  ///
  /// In en, this message translates to:
  /// **'Member management'**
  String get groupMemberManagementSection;

  /// No description provided for @groupAdminManagementSection.
  ///
  /// In en, this message translates to:
  /// **'Admin management'**
  String get groupAdminManagementSection;

  /// No description provided for @groupRequestManagementSection.
  ///
  /// In en, this message translates to:
  /// **'Request management'**
  String get groupRequestManagementSection;

  /// No description provided for @groupCurrentRoleCannotManage.
  ///
  /// In en, this message translates to:
  /// **'Your current role cannot manage this group'**
  String get groupCurrentRoleCannotManage;

  /// No description provided for @groupMembersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load group members'**
  String get groupMembersLoadFailed;

  /// No description provided for @groupNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No group members'**
  String get groupNoMembers;

  /// No description provided for @groupFollowedMembersLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load followed members'**
  String get groupFollowedMembersLoadFailed;

  /// No description provided for @groupFollowedMembersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow key members for quick access'**
  String get groupFollowedMembersSubtitle;

  /// No description provided for @groupFollowAction.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get groupFollowAction;

  /// No description provided for @groupUnfollowAction.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get groupUnfollowAction;

  /// No description provided for @groupRequestsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load group requests'**
  String get groupRequestsLoadFailed;

  /// No description provided for @groupNoPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending group requests'**
  String get groupNoPendingRequests;

  /// No description provided for @groupApplicationGroupPrefix.
  ///
  /// In en, this message translates to:
  /// **'Group: {groupId}'**
  String groupApplicationGroupPrefix(String groupId);

  /// No description provided for @groupNoMembersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No members available'**
  String get groupNoMembersAvailable;

  /// No description provided for @groupMemberActionSucceeded.
  ///
  /// In en, this message translates to:
  /// **'{action} succeeded'**
  String groupMemberActionSucceeded(String action);

  /// No description provided for @friendLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load friends'**
  String get friendLoadFailed;

  /// No description provided for @friendSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search friends'**
  String get friendSearchTooltip;

  /// No description provided for @friendAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get friendAddTooltip;

  /// No description provided for @friendRequestsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get friendRequestsTooltip;

  /// No description provided for @friendSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to search friends'**
  String get friendSearchFailed;

  /// No description provided for @friendSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter a keyword, then tap Search'**
  String get friendSearchPrompt;

  /// No description provided for @friendRequestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Friend request accepted'**
  String get friendRequestAccepted;

  /// No description provided for @friendRequestDeclined.
  ///
  /// In en, this message translates to:
  /// **'Friend request declined'**
  String get friendRequestDeclined;

  /// No description provided for @friendRequestHandleFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to handle friend request'**
  String get friendRequestHandleFailed;

  /// No description provided for @friendApplicationUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed request'**
  String get friendApplicationUnnamed;

  /// No description provided for @friendApplicationSentRequest.
  ///
  /// In en, this message translates to:
  /// **'Sent request'**
  String get friendApplicationSentRequest;

  /// No description provided for @friendApplicationReceivedRequest.
  ///
  /// In en, this message translates to:
  /// **'Received request'**
  String get friendApplicationReceivedRequest;

  /// No description provided for @friendApplicationFriendRequest.
  ///
  /// In en, this message translates to:
  /// **'Friend request'**
  String get friendApplicationFriendRequest;

  /// No description provided for @friendApplicationPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get friendApplicationPending;

  /// No description provided for @friendApplicationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get friendApplicationAccepted;

  /// No description provided for @friendApplicationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get friendApplicationDeclined;

  /// No description provided for @friendApplicationExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get friendApplicationExpired;

  /// No description provided for @friendApplicationHandledAt.
  ///
  /// In en, this message translates to:
  /// **'Handled {time}'**
  String friendApplicationHandledAt(String time);

  /// No description provided for @userProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get userProfileTitle;

  /// No description provided for @userProfileEmpty.
  ///
  /// In en, this message translates to:
  /// **'No profile information'**
  String get userProfileEmpty;

  /// No description provided for @userProfileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load user profile'**
  String get userProfileLoadFailed;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @userProfileUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userProfileUserIdLabel;

  /// No description provided for @userProfileUniqueIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Unique ID'**
  String get userProfileUniqueIdLabel;

  /// No description provided for @userProfileEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get userProfileEmailLabel;

  /// No description provided for @userProfileBirthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get userProfileBirthdayLabel;

  /// No description provided for @userProfileGenderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get userProfileGenderLabel;

  /// No description provided for @userProfileLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get userProfileLocationLabel;

  /// No description provided for @userProfileRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get userProfileRoleLabel;

  /// No description provided for @userProfileLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get userProfileLevelLabel;

  /// No description provided for @userProfileExtProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Extended profile'**
  String get userProfileExtProfileLabel;

  /// No description provided for @userProfileActionStartChat.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get userProfileActionStartChat;

  /// No description provided for @userProfileActionAddFriend.
  ///
  /// In en, this message translates to:
  /// **'Add friend'**
  String get userProfileActionAddFriend;

  /// No description provided for @userProfileActionDeleteFriend.
  ///
  /// In en, this message translates to:
  /// **'Delete friend'**
  String get userProfileActionDeleteFriend;

  /// No description provided for @userProfileActionUpdateRemark.
  ///
  /// In en, this message translates to:
  /// **'Edit remark'**
  String get userProfileActionUpdateRemark;

  /// No description provided for @userProfileActionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This action is not available'**
  String get userProfileActionUnsupported;

  /// No description provided for @userProfileActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed. Please try again.'**
  String get userProfileActionFailed;

  /// No description provided for @userProfileAddFriendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent'**
  String get userProfileAddFriendSuccess;

  /// No description provided for @userProfileDeleteFriendSuccess.
  ///
  /// In en, this message translates to:
  /// **'Friend deleted'**
  String get userProfileDeleteFriendSuccess;

  /// No description provided for @userProfileRemarkSuccess.
  ///
  /// In en, this message translates to:
  /// **'Remark updated'**
  String get userProfileRemarkSuccess;

  /// No description provided for @userProfileDeleteFriendConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete friend'**
  String get userProfileDeleteFriendConfirmTitle;

  /// No description provided for @userProfileDeleteFriendConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this friend?'**
  String get userProfileDeleteFriendConfirmMessage;

  /// No description provided for @userProfileRemarkDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit friend remark'**
  String get userProfileRemarkDialogTitle;

  /// No description provided for @userProfileRemarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Remark'**
  String get userProfileRemarkLabel;

  /// No description provided for @searchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResultsTitle;

  /// No description provided for @searchNoMatchingMessages.
  ///
  /// In en, this message translates to:
  /// **'No matching messages'**
  String get searchNoMatchingMessages;

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'Results: {count}'**
  String searchResultsCount(int count);

  /// No description provided for @chatSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get chatSearchFailed;

  /// No description provided for @searchKeywordLabel.
  ///
  /// In en, this message translates to:
  /// **'Keyword'**
  String get searchKeywordLabel;

  /// No description provided for @searchUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get searchUserIdLabel;

  /// No description provided for @searchStartTimeMsLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time (ms)'**
  String get searchStartTimeMsLabel;

  /// No description provided for @searchEndTimeMsLabel.
  ///
  /// In en, this message translates to:
  /// **'End time (ms)'**
  String get searchEndTimeMsLabel;

  /// No description provided for @searchReferenceTimeMsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference time (ms)'**
  String get searchReferenceTimeMsLabel;

  /// No description provided for @searchBeforeCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Before count'**
  String get searchBeforeCountLabel;

  /// No description provided for @searchAfterCountLabel.
  ///
  /// In en, this message translates to:
  /// **'After count'**
  String get searchAfterCountLabel;

  /// No description provided for @searchModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Search mode'**
  String get searchModeLabel;

  /// No description provided for @searchPageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get searchPageSizeLabel;

  /// No description provided for @searchModeKeyword.
  ///
  /// In en, this message translates to:
  /// **'Keyword search'**
  String get searchModeKeyword;

  /// No description provided for @searchModeUser.
  ///
  /// In en, this message translates to:
  /// **'Search by user'**
  String get searchModeUser;

  /// No description provided for @searchModeTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Search by time range'**
  String get searchModeTimeRange;

  /// No description provided for @searchModeAroundTime.
  ///
  /// In en, this message translates to:
  /// **'Search around time'**
  String get searchModeAroundTime;

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} bytes'**
  String fileSizeBytes(int size);

  /// No description provided for @fileDownload.
  ///
  /// In en, this message translates to:
  /// **'Download File'**
  String get fileDownload;

  /// No description provided for @fileDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get fileDownloaded;

  /// No description provided for @fileDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading {progress}%'**
  String fileDownloadProgress(int progress);

  /// No description provided for @filePathUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File path unavailable'**
  String get filePathUnavailable;

  /// No description provided for @fileOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open file'**
  String get fileOpenFailed;

  /// No description provided for @fileDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to download file'**
  String get fileDownloadFailed;

  /// No description provided for @fileSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get fileSizeUnknown;

  /// No description provided for @photoVideoDuration.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String photoVideoDuration(int seconds);

  /// No description provided for @photoOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open video'**
  String get photoOpenFailed;

  /// No description provided for @photoSaveSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Saved to album'**
  String get photoSaveSucceeded;

  /// No description provided for @photoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get photoSaveFailed;

  /// No description provided for @photoSaveUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Saving to the album is not available yet'**
  String get photoSaveUnsupported;

  /// No description provided for @forwardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Forward'**
  String get forwardConfirmTitle;

  /// No description provided for @forwardConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Forward {count} message(s) to {target} as {mode}?'**
  String forwardConfirmMessage(int count, String target, String mode);

  /// No description provided for @searchUnsupportedMessagePreview.
  ///
  /// In en, this message translates to:
  /// **'[Unsupported message]'**
  String get searchUnsupportedMessagePreview;
}

class _NexconnChatUILocalizationsDelegate
    extends LocalizationsDelegate<NexconnChatUILocalizations> {
  const _NexconnChatUILocalizationsDelegate();

  @override
  Future<NexconnChatUILocalizations> load(Locale locale) {
    return SynchronousFuture<NexconnChatUILocalizations>(
      lookupNexconnChatUILocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_NexconnChatUILocalizationsDelegate old) => false;
}

NexconnChatUILocalizations lookupNexconnChatUILocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return NexconnChatUILocalizationsEn();
    case 'zh':
      return NexconnChatUILocalizationsZh();
  }

  throw FlutterError(
    'NexconnChatUILocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
