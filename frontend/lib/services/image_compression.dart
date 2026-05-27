import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompression {
  static const int maxSizeBytes = 1024 * 1024; // 1 МБ
  static const int initialQuality = 70;

  /// Основной универсальный метод сжатия для чата и транзакций.
  /// Принимает Uint8List (байты) и возвращает сжатый Uint8List.
  /// Отлично работает и на Web, и на мобилках!
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    // На Web-платформе нативное сжатие через flutter_image_compress не поддерживается напрямую,
    // поэтому если файл пролазит по лимитам или это Web — отдаем как есть.
    if (kIsWeb || bytes.length <= maxSizeBytes) return bytes;

    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: initialQuality,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result.length > maxSizeBytes) {
        return await _compressBytesRecursively(result, initialQuality - 20);
      }
      return result;
    } catch (e) {
      print('Ошибка сжатия байт: $e');
      return bytes;
    }
  }

  /// Рекурсивное сжатие байт без создания промежуточных файлов на диске!
  static Future<Uint8List> _compressBytesRecursively(Uint8List bytes, int newQuality) async {
    if (newQuality < 10 || bytes.length <= maxSizeBytes) return bytes;
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: newQuality,
      );
      if (result.length > maxSizeBytes) {
        return await _compressBytesRecursively(result, newQuality - 15);
      }
      return result;
    } catch (e) {
      print('Ошибка рекурсивного сжатия байт: $e');
      return bytes;
    }
  }

  /// Дополнительный метод: если тебе всё еще нужно сжимать XFile (например, для Камеры на мобилке)
  /// С ОЧИСТКОЙ промежуточных образов!
  static Future<XFile> compressXFile(XFile file) async {
    if (kIsWeb) return file;

    try {
      final size = await file.length();
      if (size <= maxSizeBytes) return file;

      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: initialQuality,
        minWidth: 1024,
        minHeight: 1024,
      );
      
      if (result != null) {
        final resultSize = await result.length();
        if (resultSize > maxSizeBytes) {
          return await _compressXFileRecursively(result, initialQuality - 20);
        }
        return result;
      }
    } catch (e) {
      print('Image XFile compression error: $e');
    }
    return file;
  }

  /// Рекурсивное сжатие файлов на диске с УДАЛЕНИЕМ промежуточных шагов
  static Future<XFile> _compressXFileRecursively(XFile file, int newQuality) async {
    if (newQuality < 10) return file;
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: newQuality,
      );
      
      // Ключевой момент: удаляем предыдущий промежуточный файл, чтобы не копить мусор
      try {
        final previousFile = File(file.path);
        if (await previousFile.exists()) {
          await previousFile.delete();
        }
      } catch (e) {
        print('Не удалось удалить промежуточный файл: $e');
      }

      if (result != null) {
        final size = await result.length();
        if (size > maxSizeBytes) {
          return await _compressXFileRecursively(result, newQuality - 15);
        }
        return result;
      }
    } catch (e) {
      print('Recursive XFile compression error: $e');
    }
    return file;
  }
}