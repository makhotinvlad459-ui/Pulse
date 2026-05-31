import 'chat_tab_platform_interface.dart';
import 'chat_tab_mobile.dart'
    if (dart.library.html) 'chat_tab_web.dart';

ChatTabPlatform createChatTabPlatform() {
  // Используем единое имя класса ChatTabPlatformImpl, определённое в обоих файлах
  return ChatTabPlatformImpl();
}