// ДЛЯ ANDROID И iOS - пока заглушка, потом замените на реальный код
import 'payment_interface.dart';
import 'dart:io' show Platform;

class PaymentServiceInstance implements PaymentService {
  @override
  Future<void> purchase(String plan) async {
    if (Platform.isAndroid) {
      // TODO: Реализовать Google Play Billing
      throw Exception('Google Play покупки будут доступны в следующей версии');
    } else if (Platform.isIOS) {
      // TODO: Реализовать App Store покупки  
      throw Exception('App Store покупки будут доступны в следующей версии');
    } else {
      throw Exception('Платформа не поддерживается');
    }
  }
}