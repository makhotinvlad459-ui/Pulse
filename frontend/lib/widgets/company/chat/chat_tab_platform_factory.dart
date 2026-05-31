import 'chat_tab_platform_interface.dart';
import 'chat_tab_mobile.dart'
    if (dart.library.html) 'chat_tab_web.dart';

ChatTabPlatform createChatTabPlatform() {
  // На мобильных платформах (dart.library.io) импортируется ChatTabMobile
  // На вебе (dart.library.html) импортируется ChatTabWeb
  // Этот вызов создаст экземпляр правильного класса
  return ChatTabMobile();
}