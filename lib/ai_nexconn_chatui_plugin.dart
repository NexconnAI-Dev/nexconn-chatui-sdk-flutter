/// Unified export entry for the Nexconn Chat UI SDK.
///
/// The UI package exposes channel, chat, provider, configuration, and
/// utility APIs, including media send helpers and extension-panel callback
/// entry points, while re-exporting the Nexconn Flutter SDK symbols that the
/// UI layer intentionally accepts or returns.
library;

export 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart'
    show
        AppSettings,
        BaseChannel,
        ChannelIdentifier,
        ChannelNoDisturbLevel,
        ChannelType,
        ChannelsQuery,
        ChannelsQueryParams,
        CombineMessage,
        CombineMessageInfo,
        CombineMessageParams,
        CommunityChannel,
        CommunitySubChannel,
        ConnectParams,
        ConnectionStatus,
        ConnectionStatusChangedEvent,
        CustomMediaMessage,
        CustomMediaMessageParams,
        CustomMessage,
        CustomMessageParams,
        CustomMessagePersistentFlag,
        DirectChannel,
        EditedMessageDraft,
        ErrorHandler,
        FavoriteInfo,
        FileMessage,
        FileMessageParams,
        GIFMessage,
        GIFMessageParams,
        GroupChannel,
        GroupApplicationDirection,
        GroupApplicationInfo,
        GroupApplicationStatus,
        GroupInfo,
        GroupMemberInfo,
        GroupMemberRole,
        HDVoiceMessage,
        HDVoiceMessageParams,
        ImageMessage,
        ImageMessageParams,
        InformationNotificationMessage,
        InitParams,
        MediaMessage,
        MentionedInfo,
        MentionedInfoParams,
        MentionedType,
        Message,
        MessageDirection,
        MessageHandler,
        MessageModifyInfo,
        MessageModifyStatus,
        MessageOperationPolicy,
        MessageParams,
        MessageIdentifier,
        MessageReadReceiptResponse,
        MessageReadReceiptStatus,
        MessageType,
        MessagesQuery,
        MessagesQueryParams,
        NCError,
        NCEngine,
        OpenChannel,
        OperationHandler,
        PageData,
        PageResult,
        LocationMessage,
        LocationMessageParams,
        ReceivedStatus,
        ReadReceiptInfo,
        ReadReceiptVersion,
        ReferenceMessage,
        ReferenceMessageParams,
        ReferenceMessageStatus,
        FriendApplicationInfo,
        FriendApplicationStatus,
        FriendApplicationType,
        FriendInfo,
        FriendRelationInfo,
        SendMediaMessageHandler,
        SendMediaMessageParams,
        SendMessageCallback,
        SendMessageParams,
        SentStatus,
        ShortVideoMessage,
        ShortVideoMessageParams,
        SystemChannel,
        TextMessage,
        TextMessageParams,
        UserInfo;

export 'app_providers.dart';
export 'l10n/nexconn_chat_ui_l10n.dart';

export 'models/chat_profile_info.dart';
export 'models/nexconn_user_profile.dart';
export 'models/user_at_info.dart';

export 'providers/chat_provider.dart';
export 'providers/audio_player_provider.dart';
export 'providers/channel_provider.dart';
export 'providers/engine_provider.dart';
export 'providers/message_input_provider.dart';
export 'providers/read_receipt_repository.dart';
export 'providers/user_profile_provider.dart';
export 'providers/theme_provider.dart';

export 'routes/nexconn_chat_ui_routes.dart';

export 'ui_config/chat/bubble/bubble_config.dart';
export 'ui_config/chat/bubble/message_style_config.dart';
export 'ui_config/chat/input/input_config_exports.dart';
export 'ui_config/chat/page/chat_page_config.dart';
export 'ui_config/channel/channel_app_bar_config.dart';
export 'ui_config/channel/channel_config.dart';
export 'ui_config/user/user_profile_page_config.dart';
export 'ui_config/user/user_profile_provider_config.dart';

export 'utils/constants.dart';
export 'utils/message_content_util.dart';
export 'utils/time_util.dart';
export 'utils/video_playback_backend.dart';
export 'utils/video_duration_util.dart';

export 'views/chat/bubble/message_bubble.dart';
export 'views/chat/bubble/read_receipt_indicator.dart';
export 'views/chat/input/message_input_widget.dart'
    hide messageInputPluginNeedsPhotoLibraryPermission;
export 'views/chat/page/chat_page.dart';
export 'views/chat/page/message_list_widget.dart';
export 'views/chat_extras/combine_message_detail_page.dart';
export 'views/chat_extras/file_preview_page.dart';
export 'views/chat_extras/forward_select_page.dart';
export 'views/chat_extras/chat_message_search_page.dart';
export 'views/chat_extras/chat_message_search_result_page.dart';
export 'views/chat_extras/photo_preview_page.dart';
export 'views/chat_extras/read_receipt_detail_page.dart';
export 'views/chat_extras/short_video_preview_page.dart';
export 'views/channel/item/channel_item.dart';
export 'views/channel/page/channel_page.dart';
export 'views/user/user_profile_page.dart';
