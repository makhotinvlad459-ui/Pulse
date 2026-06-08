import 'dart:typed_data';

abstract class FileDownloadHelperPlatform {
  Future<void> downloadFile(Uint8List bytes, String filename, {String? shareText});
}