import 'package:flutter/material.dart';

/// Default scaffold background used by built-in ChatUI pages.
const Color scaffoldBackgroundColor = Colors.white;

/// Default chat page background color.
const Color chatPageBackgroundColor = Color(0xFFF2F2F2);

/// Default input field background color.
const Color textfieldBackgroundColor = Color(0xFFF5F6F9);

/// Default filled input field color.
const Color textfieldFilledColor = Colors.white;

/// Default input field color while sending.
const Color textfieldFilledSendingColor = Color(0xFFE0E2E3);

/// Default input field border color.
const Color textfieldBorderColor = Color(0xFFE3E5E6);

/// Default input field hint color.
const Color textfieldHintColor = Colors.grey;

/// Default outgoing message bubble color.
const Color meBubbleColor = Color(0xFF4679FF);

/// Default incoming message bubble color.
const Color othersBubbleColor = Colors.white;

/// Default system message bubble color.
const Color systemBubbleColor = Colors.grey;

/// Default file message bubble color.
const Color fileBubbleColor = Colors.white;

/// Default app bar title font size.
const double appbarFontSize = 20;

/// Default app bar title font weight.
const FontWeight appbarFontWeight = FontWeight.w500;

/// Default app bar height.
const double appbarHeight = 50;

/// Default channel avatar size.
const double channelAvatarSize = 52;

/// Default SDK query page size for ChannelPage.
const int defaultChannelPageSize = 50;

/// Default channel row height.
const double channelItemHeight = 76;

/// Maximum fraction of row width used by a message bubble.
const double messageBubbleMaxWidthFactor = 0.86;

/// Default message avatar size.
const double messageAvatarSize = 42;

/// Channel unread font size.
const double convoUnreadFontSize = 14;

/// Channel unread font weight.
const FontWeight convoUnreadFontWeight = FontWeight.bold;

/// Channel secondary text font size.
const double convoAuxiliaryFontSize = 12;

/// Channel title font size.
const double convoTitleFontSize = 16;

/// Channel last-message font size.
const double convoLastFontSize = 14;

/// Default unread badge width.
const double unreadBubbleWidth = 42;

/// Default message bubble corner radius.
const double kBubbleBorderRadius = 12;

/// Default sender-name font size in message bubbles.
const double kBubbleNameFontSize = 12;

/// Default avatar size inside message bubbles.
const double kBubbleAvatarSize = 42.0;

/// Default spacing between avatar and bubble.
const double kBubbleAvatarPadding = 8.0;

/// Default top margin between message bubbles.
const double kBubbleMarginTop = 6.0;

/// Default vertical padding inside text bubbles.
const double kBubblePaddingVertical = 5.0;

/// Extra spacing around system-channel messages.
const double kSystemChannelMessageSpacingIncrease = 10.0;

/// Default text message font size.
const double kBubbleTextFontSize = 16.0;

/// Default message time font size.
const double kBubbleTimeFontSize = 12;

/// Default vertical padding around message time text.
const double kBubbleTimeVerticalPadding = 20.0;

/// Default spacing between bubble and send status.
const double kBubbleStatusPadding = 6.0;

/// Default send-status icon size.
const double kBubbleStatusSize = 16.0;

/// Default message menu icon size.
const double kMessageMenuIconSize = 20.0;

/// Default message menu text size.
const double kMessageMenuFontSize = 14.0;

/// Default message menu text color.
const Color kMessageMenuTextColor = Color(0xFF1F2329);

/// Default file bubble width.
const double kBubbleFileWidth = 181.0;

/// Default file bubble height.
const double kBubbleFileHeight = 64.0;

/// Default file icon size in message bubbles.
const double kBubbleFileIconSize = 36.0;

/// Default file name font size.
const double kBubbleFileNameFontSize = 16.0;

/// Default file size font size.
const double kBubbleFileSizeFontSize = 10.0;

/// Default short-video play icon size.
const double kBubbleSightIconSize = 44.0;

/// Default voice message icon size.
const double kBubbleVoiceIconSize = 20.0;

/// Default spacing around voice duration text.
const double kBubbleVoiceDurationPadding = 6.0;

/// Default voice duration font size.
const double kBubbleVoiceDurationFontSize = 16.0;

/// Default reference summary font size.
const double kBubbleRefTextFontSize = 12.0;

/// Default reference summary padding.
const double kBubbleRefTextPadding = 10.0;

/// Default multi-select checkbox size.
const double kBubbleMultiSelectIconSize = 24.0;

/// Default left padding before multi-select checkbox.
const double kBubbleMultiSelectIconPaddingLeft = 12.5;

/// Default right padding after multi-select checkbox.
const double kBubbleMultiSelectIconPaddingRight = 8.5;

/// Maximum input text field height.
const double kInputFieldMaxHeight = 154.0;

/// Minimum input text field height.
const double kInputFieldMinHeight = 56.0;

/// Height of the multi-select input action bar.
const double kInputMultiSelectHeight = 61.0;

/// Height of a multi-select action button.
const double kInputMultiSelectButtonHeight = 22.0;

/// Font size for multi-select action buttons.
const double kInputMultiSelectButtonFontSize = 10.0;

/// Default input toolbar icon size.
const double kInputFieldIconSize = 28.0;

/// Default spacing between input toolbar buttons.
const double kInputFieldButtonSpace = 12.0;

/// Bottom padding for input toolbar icons.
const double kInputFieldIconPaddingBottom = 14.0;

/// Vertical content padding for the input field.
const double kInputFieldContentPaddingV = 9.0;

/// Horizontal content padding for the input field.
const double kInputFieldContentPaddingH = 11.0;

/// Vertical padding for the extension button.
const double kInputFieldMorePaddingV = 6.0;

/// Default input field corner radius.
const double kInputFieldBorderRadius = 6.0;

/// Default input field font size.
const double kInputFieldFontSize = 14.0;

/// Default input field line height.
const double kInputFieldFontHeight = 20.0;

/// Default voice input button font size.
const double kInputFieldVoiceFontSize = 12.0;

/// Default voice input icon size.
const double kInputFieldVoiceIconSize = 18.0;

/// Default spacing inside the voice input button.
const double kInputFieldVoiceSpace = 7.0;

/// Height of the voice recording overlay.
const double kVoiceRecordingBackgroundHeight = 250.0;

/// Close icon size in the voice recording overlay.
const double kVoiceRecordingCloseIconSize = 40.0;

/// Spacing around the voice recording icon.
const double kVoiceRecordingIconSpace = 40.0;

/// Width of the voice recording icon.
const double kVoiceRecordingVoiceIconWidth = 83.0;

/// Height of the voice recording icon.
const double kVoiceRecordingVoiceIconHeight = 31.0;

/// Bottom spacing for the voice recording overlay.
const double kVoiceRecordingBottomSpace = 160.0;

/// Font size used by voice recording feedback text.
const double kVoiceRecordingFontSize = 16.0;

/// Height of the input extension panel.
const double kInputExtentionHeight = 224.0;

/// Icon size in the input extension panel.
const double kInputExtentionIconSize = 29.0;

/// Item size in the input extension panel.
const double kInputExtentionItemSize = 60.0;

/// Corner radius for extension panel items.
const double kInputExtentionItemRadius = 6;

/// Top padding for the extension panel.
const double kInputExtentionPanelPaddingTop = 16;

/// Horizontal padding for the extension panel.
const double kInputExtentionPanelPaddingH = 26;

/// Bottom padding for the extension panel.
const double kInputExtentionPanelPaddingBottom = 42;

/// Horizontal spacing between extension panel items.
const double kInputExtentionItemSpaceH = 28;

/// Vertical spacing between extension panel items.
const double kInputExtentionItemSpaceV = 24;

/// Font size for extension panel item titles.
const double kInputExtentionItemFontSize = 12;

/// Height of the reference preview above the input.
const double kInputQuotePreviewHeight = 40;

/// Horizontal padding inside the reference preview.
const double kInputQuotePreviewPaddingH = 10;

/// Close icon size inside the reference preview.
const double kInputQuotePreviewCloseIconSize = 20;

/// Default padding for channel rows.
const EdgeInsets channelItemPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 0,
);

/// Default padding around chat message bubbles.
const EdgeInsets chatPagePadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: kBubbleMarginTop,
);
