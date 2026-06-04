class JournalEntry {
  final int id;
  final int companyId;
  final DateTime datetimeStart;
  final DateTime datetimeEnd;
  final String? description;
  final String? counterparty;
  final String status;
  final int? transactionId;
  final int? showcaseItemId;
  final int quantity;
  final double totalAmount;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? creatorName;
  final String? showcaseItemName;

  JournalEntry({
    required this.id,
    required this.companyId,
    required this.datetimeStart,
    required this.datetimeEnd,
    this.description,
    this.counterparty,
    required this.status,
    this.transactionId,
    this.showcaseItemId,
    this.quantity = 1,
    this.totalAmount = 0.0,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
    this.showcaseItemName,
  });

  // Вспомогательный метод для парсинга UTC-строк в локальное время
  static DateTime _parseUtc(String str) {
    var normalized = str.trim();
    if (!normalized.endsWith('Z') && !normalized.contains('+') && !normalized.contains('-')) {
      normalized += 'Z';
    }
    return DateTime.parse(normalized).toLocal();
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      companyId: json['company_id'],
      datetimeStart: _parseUtc(json['datetime_start']),
      datetimeEnd: _parseUtc(json['datetime_end']),
      description: json['description'],
      counterparty: json['counterparty'],
      status: json['status'],
      transactionId: json['transaction_id'],
      showcaseItemId: json['showcase_item_id'],
      quantity: json['quantity'] ?? 1,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdBy: json['created_by'],
      createdAt: _parseUtc(json['created_at']),
      updatedAt: _parseUtc(json['updated_at']),
      creatorName: json['creator_name'],
      showcaseItemName: json['showcase_item_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'datetime_start': datetimeStart.toUtc().toIso8601String(),
      'datetime_end': datetimeEnd.toUtc().toIso8601String(),
      'description': description,
      'counterparty': counterparty,
      'status': status,
      'transaction_id': transactionId,
      'showcase_item_id': showcaseItemId,
      'quantity': quantity,
      'total_amount': totalAmount,
      'created_by': createdBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}