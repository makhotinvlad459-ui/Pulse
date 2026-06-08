import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'file_download_helper_interface.dart';
import 'file_download_helper_factory.dart';
import '../l10n/app_localizations.dart';

class FileDownloadHelper {
  static final FileDownloadHelperPlatform _platform = createFileDownloadHelper();

  static Future<void> downloadFile(
    Uint8List bytes,
    String filename, {
    BuildContext? context,
  }) async {
    String? shareText;
    if (context != null) {
      final t = AppLocalizations.of(context);
      if (t != null) {
        // t.shareFileText — это метод, принимающий {filename}
        shareText = t.shareFileText(filename);
      }
    }
    shareText ??= 'Save file: $filename';
    await _platform.downloadFile(bytes, filename, shareText: shareText);
  }
}