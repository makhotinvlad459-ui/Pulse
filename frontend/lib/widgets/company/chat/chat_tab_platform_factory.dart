import 'chat_tab_platform_interface.dart';
import 'chat_tab_mobile.dart'
    if (dart.library.html) 'chat_tab_web.dart';

ChatTabPlatform createChatTabPlatform() {
  return ChatTabPlatformImpl();
}