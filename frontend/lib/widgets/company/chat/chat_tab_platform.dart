import 'package:flutter/foundation.dart' show kIsWeb;
import 'chat_tab_platform_interface.dart';
import 'chat_tab_web.dart';
import 'chat_tab_mobile.dart';

void registerChatTabPlatform() {
  if (kIsWeb) {
    ChatTabPlatformSingleton.register(ChatTabWeb());
  } else {
    ChatTabPlatformSingleton.register(ChatTabMobile());
  }
}