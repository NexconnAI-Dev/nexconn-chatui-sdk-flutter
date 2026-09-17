## 26.2.9

* Update Nexconn Chat SDK dependency to 26.2.9, including the Android compileSdk 36 compatibility fix.

* Align read-receipt V5 with the IMKit design: the status icon now renders beside the bubble (bottom aligned) in a unified slot shared with the sending/failed indicators; the text status line below the bubble was removed and `MessageListConfig.showSentStatus` is deprecated.
* Replace the read-receipt users bottom sheet with a pushed "message read status" page featuring a message summary card, `Read(N)/Unread(N)` tabs, per-member read times, and paged member loading (`ReadReceiptUsersPage.push`).
* Align the conversation list read status with the V5 spec: icon-only (grey circle / green check), direct channels only, group channels no longer show it.
* Align message editing with the IMKit composer: quote preview header, prefilled text field with expand button, and dedicated cancel/confirm action buttons; confirm is disabled when the message is no longer editable.
* Add the full-screen message editor overlay (slide-up transition) via the edit composer expand/collapse buttons.
* Keep the soft keyboard open while the message long-press menu is shown (`showMenu(requestFocus: false)`) and account for keyboard height when placing the menu.

## 26.2.8

* Update Nexconn Chat SDK dependency to 26.2.8.
* Adapt message type handling for `MessageType.combine` and SDK-only custom messages mapped to `MessageType.unknown`.
* Keep delete-for-all placeholder rendering compatible after `MessageType.recall` was removed from the public Chat SDK API.

## 26.2.7

* Align Chat UI package version with the Nexconn Chat Flutter SDK 26.2.7 release.
