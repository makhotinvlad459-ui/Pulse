// Интерфейс для всех платежных сервисов

abstract class PaymentService {
  Future<void> purchase(String plan);
}