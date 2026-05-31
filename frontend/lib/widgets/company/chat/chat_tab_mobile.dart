import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'chat_tab_platform_interface.dart';

class ChatTabPlatformImpl implements ChatTabPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename) async {
    // Сохраняем во временную директорию
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$filename');
    await tempFile.writeAsBytes(bytes);
    
    // Вызываем системный диалог "Поделиться" / "Сохранить"
    await Share.shareXFiles(
      [XFile(tempFile.path, name: filename)],
      text: 'Сохраните файл: $filename',
    );
  }
}