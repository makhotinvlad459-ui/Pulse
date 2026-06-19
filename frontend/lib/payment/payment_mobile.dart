// lib/payment/payment_mobile.dart

import 'payment_interface.dart';
import 'dart:io' show Platform;
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/api_client.dart';

class PaymentServiceInstance implements PaymentService {
  bool _initialized = false;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  PurchaseDetails? _purchaseDetails;

  Future<void> _initialize() async {
    if (_initialized) return;
    
    final isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      throw Exception('In-app purchases not available on this device');
    }
    
    _inAppPurchase.purchaseStream.listen((purchaseDetailsList) {
      for (final purchaseDetails in purchaseDetailsList) {
        _handlePurchaseUpdate(purchaseDetails);
      }
    });
    
    _initialized = true;
  }

  void _handlePurchaseUpdate(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.status == PurchaseStatus.purchased) {
      _purchaseDetails = purchaseDetails;
      print('✅ Purchase successful: ${purchaseDetails.purchaseID}');
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print('❌ Purchase error: ${purchaseDetails.error}');
    }
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
    final productId = _getProductId(plan);
    await _purchaseProduct(productId, 'google');
  }

  Future<void> _purchaseOnIOS(String plan) async {
    final productId = _getProductId(plan);
    await _purchaseProduct(productId, 'apple');
  }

  Future<void> _purchaseProduct(String productId, String store) async {
    final productDetailsResponse = await _inAppPurchase.queryProductDetails({productId});
    
    if (productDetailsResponse.productDetails.isEmpty) {
      throw Exception('Product not found: $productId');
    }

    final productDetails = productDetailsResponse.productDetails.first;
    
    final purchaseParam = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: null,
    );

    // 👇 В новой версии buyNonConsumable работает для всего
    final bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    
    if (!success) {
      throw Exception('Failed to start purchase');
    }

    int attempts = 0;
    while (_purchaseDetails == null && attempts < 30) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }

    if (_purchaseDetails == null) {
      throw Exception('Purchase timeout');
    }

    if (_purchaseDetails!.status == PurchaseStatus.purchased) {
      final token = _purchaseDetails!.purchaseID ?? '';
      await _verifyOnBackend(token, productId, store);
      _purchaseDetails = null;
    } else if (_purchaseDetails!.status == PurchaseStatus.error) {
      final error = _purchaseDetails!.error;
      _purchaseDetails = null;
      throw Exception('Purchase failed: ${error?.message ?? 'Unknown error'}');
    } else {
      _purchaseDetails = null;
      throw Exception('Purchase cancelled or pending');
    }
  }

  String _getProductId(String plan) {
    switch (plan) {
      case 'monthly':
        return 'monthly_subscription';
      case 'half_year':
        return 'half_year_subscription';
      case 'extra_company':
        return 'extra_company_addon_2';
      default:
        throw Exception('Unknown plan: $plan');
    }
  }

  Future<void> _verifyOnBackend(String token, String plan, String store) async {
    final api = ApiClient();
    await api.post('/subscription/verify-mobile', data: {
      'token': token,
      'plan': plan,
      'store': store,
    });
  }
}