import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class ImageCompression {
  // Максимальный размер файла после сжатия (в байтах) – 1 МБ
  static const int maxSizeBytes = 1024 * 1024;
  // Качество сжатия (0-100)
  static const int quality = 70;

  /// Сжимает XFile (с мобильного устройства) и возвращает новый XFile во временной директории.
  /// Если сжатие не удалось или платформа Web, возвращает исходный файл.
  static Future<XFile> compressImage(XFile file) async {
    if (kIsWeb) return file; // на вебе не сжимаем (можно позже реализовать)

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality,
        minWidth: 1024, // опционально: ограничить ширину
        minHeight: 1024,
      );
      
      if (result != null) {
        // Проверим размер, если всё ещё больше лимита – уменьшаем качество рекурсивно
        final size = await result.length();
        if (size > maxSizeBytes) {
          return await _compressRecursively(result, quality - 20);
        }
        return result;
      }
    } catch (e) {
      print('Image compression error: $e');
    }
    return file;
  }

  static Future<XFile> _compressRecursively(XFile file, int newQuality) async {
    if (newQuality < 10) return file;
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: newQuality,
      );
      if (result != null) {
        final size = await result.length();
        if (size > maxSizeBytes) {
          return await _compressRecursively(result, newQuality - 15);
        }
        return result;
      }
    } catch (e) {
      print('Recursive compression error: $e');
    }
    return file;
  }
}