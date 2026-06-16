// lib/payment/payment_mobile.dart - полная версия с комментариями

import 'payment_interface.dart';
import 'dart:io' show Platform;
import 'package:purchase/purchase.dart';
import '../services/api_client.dart';

class PaymentServiceInstance implements PaymentService {
  bool _initialized = false;
  
  Future<void> _initialize() async {
    if (_initialized) return;
    
    // Инициализация покупок (один раз при первом использовании)
    final purchases = Purchases.instance;
    await purchases.setup(
      // В Android это будет работать сразу после добавления в Google Play Console
      // В iOS потребуется настройка в App Store Connect
    );
    _initialized = true;
  }
  
  @override
  Future<void> purchase(String plan) async {
    await _initialize();
    
    if (Platform.isAndroid) {
      await _purchaseOnAndroid(plan);
    } else if (Platform.isIOS) {
      await _purchaseOnIOS(plan);
    } else {
      throw Exception('Platform not supported');
    }
  }
  
  Future<void> _purchaseOnAndroid(String plan) async {
    // Преобразуем plan в Google Play Product ID
    final productId = _getProductId(plan);
    
    final purchases = Purchases.instance;
    final purchase = await purchases.purchaseProduct(productId);
    
    if (purchase.status == PurchaseStatus.purchased) {
      final token = purchase.verificationData.serverVerificationData;
      await _verifyOnBackend(token, plan, 'google');
    } else if (purchase.status == PurchaseStatus.error) {
      throw Exception('Purchase failed: ${purchase.error}');
    }
  }
  
  Future<void> _purchaseOnIOS(String plan) async {
    // Аналогично для iOS, но с другими Product ID
    final productId = _getProductId(plan);
    
    final purchases = Purchases.instance;
    final purchase = await purchases.purchaseProduct(productId);
    
    if (purchase.status == PurchaseStatus.purchased) {
      // Для iOS нужен receipt
      final receipt = purchase.verificationData.serverVerificationData;
      await _verifyOnBackend(receipt, plan, 'apple');
    }
  }
  
  String _getProductId(String plan) {
    switch (plan) {
      case 'monthly':
        return 'monthly_subscription';
      case 'extra_company':
        return 'extra_company';
      default:
        throw Exception('Unknown plan: $plan');
    }
  }
  
  Future<void> _verifyOnBackend(String token, String plan, String store) async {
    final api = ApiClient();
    await api.post('/subscription/verify-mobile', data: {
      'token': token,
      'plan': plan,
      'store': store, // 'google' или 'apple'
    });
  }
}