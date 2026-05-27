import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompression {
  /// Принимает сырые байты (Uint8List), сжимает их и возвращает сжатые байты (Uint8List).
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    // 1. Декодируем изображение из байтов
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // 2. Изменяем размер, если оно слишком большое (например, макс. ширина 1200px)
    img.Image resized = img.copyResize(image, width: 1200);

    // 3. Кодируем обратно в JPEG с качеством 80%
    final compressedBytes = img.encodeJpg(resized, quality: 80);
    
    // Возвращаем как Uint8List
    return Uint8List.fromList(compressedBytes);
  }
}