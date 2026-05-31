import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'chat_tab_platform_interface.dart';

class ChatTabMobile implements ChatTabPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    // Здесь можно добавить уведомление об успехе
  }
}