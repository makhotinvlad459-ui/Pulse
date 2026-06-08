import 'dart:html' as html;
import 'dart:typed_data';
import 'file_download_helper_interface.dart';

class FileDownloadHelperPlatformImpl implements FileDownloadHelperPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename, {String? shareText}) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }
}