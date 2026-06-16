import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationsService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Только слушатели сообщений, без запроса токена
  static Future<void> initListeners() async {
    try {
      // Слушатель для сообщений в foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 [FCM] Сообщение в foreground: ${message.notification?.title}');
      });

      // Слушатель для открытия приложения из уведомления
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📲 [FCM] Приложение открыто из уведомления: ${message.notification?.title}');
      });

      print('✅ [FCM] Слушатели уведомлений инициализированы');
    } catch (e) {
      print('❌ [FCM] Ошибка инициализации слушателей: $e');
    }
  }
}