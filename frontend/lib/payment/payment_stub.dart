// Заглушка для неподдерживаемых платформ
import 'payment_interface.dart';

class PaymentServiceInstance implements PaymentService {
  @override
  Future<void> purchase(String plan) async {
    throw UnsupportedError('Платежи на этой платформе не поддерживаются');
  }
}