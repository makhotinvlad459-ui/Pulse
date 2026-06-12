// ТОЛЬКО ДЛЯ ВЕБА - код с ЮKassa
import 'payment_interface.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_client.dart';

class PaymentServiceInstance implements PaymentService {
  @override
  Future<void> purchase(String plan) async {
    final api = ApiClient();
    
    final res = await api.post(
      '/subscription/create-payment',
      data: {'plan': plan},
    );
    
    final url = res.data['confirmation_url'];
    if (url != null && url is String && url.isNotEmpty) {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Невозможно открыть ссылку для оплаты');
      }
    } else {
      throw Exception('Ссылка для оплаты не найдена');
    }
  }
}