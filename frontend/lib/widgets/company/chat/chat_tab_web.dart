import 'dart:html' as html;
import 'dart:typed_data';
import 'chat_tab_platform_interface.dart';

class ChatTabWeb implements ChatTabPlatform {
  @override
  Future<void> downloadFile(Uint8List bytes, String filename) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }
  
  // Добавим метод для открытия файла в новой вкладке
  Future<void> openFile(Uint8List bytes, String filename) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}