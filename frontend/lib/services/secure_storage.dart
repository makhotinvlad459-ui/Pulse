import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:universal_html/html.dart' as html;

class SecureStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // ===== WRITE =====
  Future<void> write({required String key, required String value}) async {
    try {
      if (kIsWeb) {
        html.window.localStorage[key] = value;
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (e) {
      print('❌ Error writing "$key": $e');
      // Не бросаем ошибку, чтобы приложение не падало
    }
  }

  // ===== READ (С ОБРАБОТКОЙ ОШИБОК) =====
  Future<String?> read({required String key}) async {
    try {
      if (kIsWeb) {
        return html.window.localStorage[key];
      } else {
        // Проверяем, существует ли ключ (чтобы избежать BadPaddingError)
        final bool exists = await _secureStorage.containsKey(key: key);
        if (!exists) {
          print('🔑 Key "$key" not found, returning null');
          return null;
        }
        return await _secureStorage.read(key: key);
      }
    } catch (e) {
      print('❌ Error reading "$key": $e');
      
      // Если ошибка шифрования - удаляем повреждённый ключ
      if (e.toString().contains('BadPaddingError') ||
          e.toString().contains('BadPadding') ||
          e.toString().contains('BAD_DECRYPT')) {
        print('🔑 BadPadding, deleting "$key"...');
        await delete(key: key);  // удаляем битый ключ
        return null;
      }
      return null;
    }
  }

  // ===== DELETE =====
  Future<void> delete({required String key}) async {
    try {
      if (kIsWeb) {
        html.window.localStorage.remove(key);
      } else {
        await _secureStorage.delete(key: key);
      }
    } catch (e) {
      print('❌ Error deleting "$key": $e');
    }
  }

  // ===== HAS KEY (ПРОВЕРКА СУЩЕСТВОВАНИЯ) =====
  Future<bool> hasKey(String key) async {
    try {
      if (kIsWeb) {
        return html.window.localStorage.containsKey(key);
      } else {
        return await _secureStorage.containsKey(key: key);
      }
    } catch (e) {
      return false;
    }
  }

  // ===== CLEAR ALL =====
  Future<void> clearAll() async {
    try {
      if (kIsWeb) {
        html.window.localStorage.clear();
      } else {
        await _secureStorage.deleteAll();
      }
    } catch (e) {
      print('❌ Error clearing all: $e');
    }
  }

  // ===== TOKENS =====
  Future<void> setRefreshToken(String token) async {
    await write(key: 'refresh_token', value: token);
  }

  Future<String?> getRefreshToken() async {
    return await read(key: 'refresh_token');
  }

  Future<void> clearTokens() async {
    await delete(key: 'access_token');
    await delete(key: 'refresh_token');
  }
}