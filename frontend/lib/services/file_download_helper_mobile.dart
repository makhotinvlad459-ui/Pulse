import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'file_download_helper_interface.dart';

class FileDownloadHelperPlatformImpl implements FileDownloadHelperPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename, {String? shareText}) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, name: filename)],
      text: shareText ?? 'Save file: $filename',
    );
  }
}