import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:html' as html;
import '../l10n/app_localizations.dart';

class FileDownloadHelper {
  static Future<void> downloadFile(
    Uint8List bytes,
    String filename, {
    BuildContext? context,
  }) async {
    // fallback на случай отсутствия контекста или локализации
    String shareText = 'Save file: $filename';
    if (context != null) {
      final t = AppLocalizations.of(context);
      if (t != null) {
        // shareFileText — это метод, принимающий {filename}
        shareText = t.shareFileText(filename);
      }
    }

    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..download = filename;
      anchor.click();
      html.Url.revokeObjectUrl(url);
    } else {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, name: filename)],
        text: shareText,
      );
    }
  }
}