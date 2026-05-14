import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:universal_html/html.dart' as html;

class SecureStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> write({required String key, required String value}) async {
    if (kIsWeb) {
      html.window.localStorage[key] = value;
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  Future<String?> read({required String key}) async {
    if (kIsWeb) {
      return html.window.localStorage[key];
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  Future<void> delete({required String key}) async {
    if (kIsWeb) {
      html.window.localStorage.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      html.window.localStorage.clear();
    } else {
      await _secureStorage.deleteAll();
    }
  }
}