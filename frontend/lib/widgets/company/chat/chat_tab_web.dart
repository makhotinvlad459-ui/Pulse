import 'dart:html' as html;
import 'dart:typed_data';
import 'chat_tab_platform_interface.dart';

class ChatTabWeb implements ChatTabPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = 'blank'
      ..download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }
}
