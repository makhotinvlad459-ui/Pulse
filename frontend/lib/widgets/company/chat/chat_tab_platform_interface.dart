import 'dart:typed_data';

abstract class ChatTabPlatform {
  Future<void> downloadFile(Uint8List bytes, String filename);
  Future<void> openFile(Uint8List bytes, String filename);  // добавили
}

class ChatTabPlatformSingleton {
  static ChatTabPlatform? _instance;

  static void register(ChatTabPlatform instance) {
    _instance = instance;
  }

  static ChatTabPlatform get instance {
    if (_instance == null) {
      throw Exception('ChatTabPlatform not registered');
    }
    return _instance!;
  }
}