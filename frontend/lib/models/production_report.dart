// lib/models/production_report.dart
class ProductionReportItem {
  final String productName;
  final String unit;
  final double producedQuantity;
  final double soldQuantity;
  final double currentStock;
  final double sellThroughPercent;
  
  ProductionReportItem({
    required this.productName,
    required this.unit,
    required this.producedQuantity,
    required this.soldQuantity,
    required this.currentStock,
    required this.sellThroughPercent,
  });
  
  factory ProductionReportItem.fromJson(Map<String, dynamic> json) {
    return ProductionReportItem(
      productName: json['product_name'],
      unit: json['unit'] ?? 'шт',
      producedQuantity: (json['produced_quantity'] as num?)?.toDouble() ?? 0,
      soldQuantity: (json['sold_quantity'] as num?)?.toDouble() ?? 0,
      currentStock: (json['current_stock'] as num?)?.toDouble() ?? 0,
      sellThroughPercent: (json['sell_through_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProductionJournalReportItem {
  final DateTime productionDate;
  final String productName;
  final String unit;
  final double quantity;
  final String shift;
  final String? workerName;
  final String creatorName;
  final String? notes;
  
  ProductionJournalReportItem({
    required this.productionDate,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.shift,
    this.workerName,
    required this.creatorName,
    this.notes,
  });
  
  factory ProductionJournalReportItem.fromJson(Map<String, dynamic> json) {
    return ProductionJournalReportItem(
      productionDate: DateTime.parse(json['production_date']),
      productName: json['product_name'],
      unit: json['unit'] ?? 'шт',
      quantity: (json['quantity'] as num).toDouble(),
      shift: json['shift'] == 'day' ? 'Дневная' : 'Ночная',
      workerName: json['worker_name'],
      creatorName: json['creator_name'] ?? '',
      notes: json['notes'],
    );
  }
}

class ProductionSaleReportItem {
  final DateTime date;
  final String productName;
  final double quantity;
  final double amount;
  final String accountName;
  final String? counterparty;
  final bool isPaid;
  final DateTime? paidAt;
  final int transactionId;
  
  ProductionSaleReportItem({
    required this.date,
    required this.productName,
    required this.quantity,
    required this.amount,
    required this.accountName,
    this.counterparty,
    required this.isPaid,
    this.paidAt,
    required this.transactionId,
  });
  
  factory ProductionSaleReportItem.fromJson(Map<String, dynamic> json) {
    return ProductionSaleReportItem(
      date: DateTime.parse(json['date']),
      productName: json['product_name'],
      quantity: (json['quantity'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      accountName: json['account_name'] ?? '',
      counterparty: json['counterparty'],
      isPaid: json['is_paid'] ?? false,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      transactionId: json['transaction_id'],
    );
  }
}