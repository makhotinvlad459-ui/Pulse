import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'chat_tab_platform_interface.dart';

class ChatTabMobile implements ChatTabPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
  }
  
  @override
  Future<void> openFile(Uint8List bytes, String filename) async {
    // На мобильных проще сохранить и открыть
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    // Можно открыть через open_file пакет, но пока просто сохраняем
  }
}