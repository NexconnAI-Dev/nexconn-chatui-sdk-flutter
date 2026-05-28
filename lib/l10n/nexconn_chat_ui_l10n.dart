import 'package:flutter/widgets.dart';

import 'nexconn_chat_ui_localizations.dart';
import 'nexconn_chat_ui_localizations_en.dart';

export 'nexconn_chat_ui_localizations.dart';

const Locale nexconnChatUIDefaultLocale = Locale('en');

extension NexconnChatUILocalizationsX on BuildContext {
  NexconnChatUILocalizations get chatUIL10n =>
      Localizations.of<NexconnChatUILocalizations>(
        this,
        NexconnChatUILocalizations,
      ) ??
      NexconnChatUILocalizationsEn();
}
