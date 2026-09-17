import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';

const String _recallNotificationObjectName = 'RC:RcNtf';

bool isDeleteForAllPlaceholderMessage(Message message) {
  final messageTypeName = message.runtimeType.toString();
  if (messageTypeName == '_RecalledPlaceholderMessage') {
    return true;
  }
  if (message is UnknownMessage) {
    return message.objectName == _recallNotificationObjectName;
  }
  try {
    return message.toJson(filterEmpty: false)['objectName'] ==
        _recallNotificationObjectName;
  } catch (_) {
    // Continue with raw type detection below.
  }
  try {
    final rawTypeName = message.raw.runtimeType.toString();
    return rawTypeName == 'RCIMIWRecallNotificationMessage';
  } catch (_) {
    return false;
  }
}
