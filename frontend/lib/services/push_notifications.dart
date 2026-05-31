import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_client.dart';

class PushNotificationsService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('Push notifications not authorized');
        return;
      }
      
      String? token = await _fcm.getToken();
      print('FCM Token: $token');
      
      if (token != null) {
        final api = ApiClient();
        await api.post('/chat/fcm-token', data: {'fcm_token': token});
        print('Token sent to server');
      }
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got message in foreground: ${message.notification?.title}');
      });
      
    } catch (e) {
      print('Push notifications init error: $e');
    }
  }
}