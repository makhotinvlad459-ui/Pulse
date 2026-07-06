// lib/services/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'secure_storage.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final SecureStorage _storage = SecureStorage();

  /// Получение и отправка FCM токена на сервер
  Future<void> updateFcmToken() async {
    try {
      // 1. Получаем токен
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        print('⚠️ [FCM] Токен пустой, пропускаем');
        return;
      }
      
      print('📱 [FCM] Токен получен: $token');

      // 2. Получаем access token пользователя
      final accessToken = await _storage.read(key: 'access_token');
      if (accessToken == null || accessToken.isEmpty) {
        print('⚠️ [FCM] Пользователь не авторизован');
        return;
      }

      // 3. Отправляем на сервер
      final response = await http.post(
        Uri.parse('https://pulse-yourmoney.com/api/chat/fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcm_token': token}),
      );

      if (response.statusCode == 200) {
        print('✅ [FCM] Токен сохранен на сервере');
      } else {
        print('❌ [FCM] Ошибка сохранения токена: ${response.statusCode}');
        print('❌ [FCM] Ответ: ${response.body}');
      }
    } catch (e) {
      print('❌ [FCM] Ошибка: $e');
    }
  }

  /// Слушаем обновление токена
  void listenTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 [FCM] Токен обновлен: $newToken');
      updateFcmToken();
    });
  }
}