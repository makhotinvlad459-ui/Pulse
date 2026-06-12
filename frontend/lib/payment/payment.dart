// Главный файл с условным импортом
// В зависимости от платформы подставится нужная реализация

export 'payment_interface.dart';

// КЛЮЧЕВОЙ МОМЕНТ:
// - dart.library.js = Web → подставится payment_web.dart
// - dart.library.io = Android/iOS → подставится payment_mobile.dart
// - остальное → payment_stub.dart
import 'payment_stub.dart' 
    if (dart.library.js) 'payment_web.dart'
    if (dart.library.io) 'payment_mobile.dart';

// Глобальный экземпляр платежного сервиса
final paymentService = PaymentServiceInstance();