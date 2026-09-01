# Nexconn Chat UI SDK for Flutter

`ai_nexconn_chatui_plugin` provides ready-to-use Flutter UI for Nexconn Chat:
channel list, chat page, message list, input bar, message bubbles, and
preview pages.

<!-- Chat Growth Credit campaign banner -->
<p align="center">
  <a href="https://www.nexconn.ai/activity/chat-growth-credit?utm_source=github&utm_medium=readme&utm_campaign=chat-growth-credit&utm_repo=nexconn-chatui-sdk-flutter">
    <img src="./assets/chat-growth-credit-hero.jpg" alt="Build your app with 10,000 free MAU and full Chat Pro capabilities" width="100%" />
  </a>
</p>

> **Chat Growth Credit** — Build with Nexconn Chat and explore full capabilities free up to **10,000 MAU**. [View the offer details →](https://www.nexconn.ai/activity/chat-growth-credit?utm_source=github&utm_medium=readme&utm_campaign=chat-growth-credit&utm_repo=nexconn-chatui-sdk-flutter)


The package exposes Nexconn SDK objects directly. Public APIs use
`BaseChannel`, `Message`, `MessageType`, `ChannelType`, `NCEngine`, and other
types from `ai_nexconn_chat_plugin` as the customer-facing API.

User profile features are exposed through the Nexconn-named UI layer:
`NexconnUserProfilePage`, `NexconnUserProfileProvider`, and
`NexconnUserProfilePageConfig`.

## Quick Start

```dart
import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';

final engineProvider = EngineProvider();

await engineProvider.initialize(InitParams(appKey: 'YOUR_APP_KEY'));
await engineProvider.connect(
  ConnectParams(token: 'USER_TOKEN'),
);

runApp(
  ChatUIProviders(
    engineProvider: engineProvider,
    child: const MaterialApp(
      home: ChannelPage(),
    ),
  ),
);
```

Open a chat page with any Nexconn channel:

```dart
ChannelPage(
  onItemTap: (channel, index, context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(channel: channel),
      ),
    );
  },
);
```

## Channel List Customization

```dart
ChannelPage(
  config: ChannelConfig(
    listConfig: const ChannelListConfig(
      pageSize: 30,
      showNetworkStatusTip: true,
    ),
    itemConfig: ChannelItemConfig(
      avatarShape: ChannelAvatarShape.circle,
      showDirectChannelOnlineStatus: true,
      onlineStatusProvider: (channel) => ChannelOnlineStatus.online,
    ),
    longPressMenuConfig: const ChannelLongPressMenuConfig(
      cancelText: 'Close',
    ),
  ),
  headerBuilder: (_) => const Text('Channel Header'),
  footerBuilder: (_) => const Text('Channel Footer'),
  emptyBuilder: (_) => const Text('No channels'),
);
```

## Chat Page Customization

```dart
ChatPage(
  channel: channel,
  config: const ChatPageConfig(
    messageListConfig: MessageListConfig(
      historyMessageCount: 30,
      maxSelectedMessages: 20,
      showSenderName: false,
      showNetworkStatusTip: true,
    ),
    bubbleConfig: BubbleConfig(
      avatarConfig: ChatAvatarConfig(
        size: 44,
        shape: ChatAvatarShape.roundedRectangle,
      ),
    ),
    longPressMenuConfig: ChatMessageLongPressMenuConfig(
      showMoreButton: false,
      deleteBehavior: ChatMessageDeleteBehavior.forAll,
    ),
  ),
  headerBuilder: (_) => const Text('Chat Header'),
  footerBuilder: (_) => const Text('Chat Footer'),
  emptyBuilder: (_) => const Text('No messages'),
  onMessageTap: (message) {},
  onMessageLongPress: (message) {},
  onMessageAvatarTap: (message) {},
  onMessageAvatarLongPress: (message) {},
);
```

## Input Area

Configure the input bar controls and extension panel from `ChatPageConfig`.
Controls can be reordered or hidden, and extension plugins can be replaced at
runtime by rebuilding with a new `MessageInputConfig`.

```dart
ChatPage(
  channel: channel,
  config: ChatPageConfig(
    inputConfig: MessageInputConfig(
      enableEmojiPanel: false,
      toolbarControls: [
        MessageInputBarControl.extension,
        MessageInputBarControl.voice,
      ],
      extensionPlugins: [
        const MessageInputExtensionPlugin.voiceToText(),
        MessageInputExtensionPlugin(
          id: 'scan',
          title: 'Scan',
          icon: Icons.qr_code_scanner,
          onTap: (context, plugin) {
            // Connect your own Nexconn business flow here.
          },
        ),
      ],
    ),
  ),
);
```

`MessageInputExtensionPlugin.voiceToText()` is a configurable entry point only.
It is disabled by default until the app wires a real speech-to-text capability
and explicitly enables it.

Built-in media entries such as `photo`, `camera`, `file`, and `location` are
also callback entry points only. They stay disabled until your app supplies the
real picker or capture flow and enables them explicitly.

## Media Send Helpers

`ChatProvider` now exposes a generic media sending entry point plus
type-specific helpers. The UI layer only forwards message params, so your app
can plug in any real picker or recorder before calling these helpers.
For image messages, the helper currently accepts the selected file path only;
original-image switching should still be handled by your picker layer when the
underlying SDK exposes it.

```dart
context.read<ChatProvider>().sendImageMessage('/tmp/photo.jpg');
context.read<ChatProvider>().sendGifMessage('/tmp/anim.gif');
context.read<ChatProvider>().sendVoiceMessage('/tmp/voice.aac', 12);
context.read<ChatProvider>().sendShortVideoMessage('/tmp/video.mp4', 30);
context.read<ChatProvider>().sendFileMessage('/tmp/report.pdf');
```

If you want to keep the input UI fully custom, use the extension panel builder
or `onTap` callback to bridge your picker into the helper:

```dart
MessageInputExtensionPlugin.photo(
  enabled: true,
  onTap: (context, plugin) async {
    final provider = context.read<ChatProvider>();
    await provider.sendImageMessage('/tmp/photo.jpg');
  },
);
```

## User Profile

Use the built-in page to display the current user or any other user profile.
By default it resolves data through `NCEngine.user.getMyUserProfile` and
`NCEngine.user.getUserProfiles`, but you can inject your own resolver through
`NexconnUserProfileProviderConfig`.

```dart
NexconnUserProfilePage(
  userId: 'target-user-id',
  config: NexconnUserProfilePageConfig(
    providerConfig: NexconnUserProfileProviderConfig(
      profileResolver: (userId) async {
        // Return a NexconnUserProfile from your own cache or backend.
        return null;
      },
    ),
  ),
);
```

## Migration Notes

The public naming strategy intentionally uses generic UI names such as
`ChannelPage` and `ChatPage`, while the data and event objects remain the
Nexconn SDK types.
