import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';

const String _recallNotificationObjectName = 'RC:RcNtf';

bool isDeleteForAllPlaceholderMessage(Message message) {
  final messageTypeName = message.runtimeType.toString();
  if (messageTypeName == '_RecalledPlaceholderMessage') {
    return true;
  }
  if (message is UnknownMessage &&
      message.objectName == _recallNotificationObjectName) {
    return true;
  }
  try {
    if (message.toJson(filterEmpty: false)['objectName'] ==
        _recallNotificationObjectName) {
      return true;
    }
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
