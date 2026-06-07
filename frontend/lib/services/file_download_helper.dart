import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:html' as html;

class FileDownloadHelper {
  static Future<void> downloadFile(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      // Web: создаём Blob и эмулируем скачивание через AnchorElement
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..download = filename;
      anchor.click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Мобильные: сохраняем во временную папку и вызываем Share
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, name: filename)],
        text: 'Сохраните файл: $filename',
      );
    }
  }
}