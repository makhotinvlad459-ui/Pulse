import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_client.dart';

class PushNotificationsService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      // Инициализация Firebase с твоей конфигурацией
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBXoRO7sp49PotOrUEPmTsbRxCpcDpdyZ0",
          authDomain: "pulse-yourmoney.firebaseapp.com",
          projectId: "pulse-yourmoney",
          storageBucket: "pulse-yourmoney.firebasestorage.app",
          messagingSenderId: "267395124760",
          appId: "1:267395124760:web:93231e40b80650ccf9bd6d",
        ),
      );
      
      // Запрашиваем разрешение
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('Push notifications not authorized');
        return;
      }
      
      // Получаем токен
      String? token = await _fcm.getToken();
      print('FCM Token: $token');
      
      if (token != null) {
        final api = ApiClient();
        await api.post('/chat/fcm-token', data: {'fcm_token': token});
        print('Token sent to server');
      }
      
      // Обработка уведомлений когда приложение открыто
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got message in foreground: ${message.notification?.title}');
      });
      
    } catch (e) {
      print('Push notifications init error: $e');
    }
  }
}