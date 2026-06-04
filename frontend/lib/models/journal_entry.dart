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
  final List<Map<String, dynamic>>? items;

  const JournalEntry({
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
    this.items,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'],
      companyId: json['company_id'],
      datetimeStart: DateTime.parse(json['datetime_start']),
      datetimeEnd: DateTime.parse(json['datetime_end']),
      description: json['description'],
      counterparty: json['counterparty'],
      status: json['status'],
      transactionId: json['transaction_id'],
      showcaseItemId: json['showcase_item_id'],
      quantity: json['quantity'] ?? 1,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      creatorName: json['creator_name'],
      showcaseItemName: json['showcase_item_name'],
      items: json['items'] != null ? List<Map<String, dynamic>>.from(json['items']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_id': companyId,
      'datetime_start': datetimeStart.toIso8601String(),
      'datetime_end': datetimeEnd.toIso8601String(),
      'description': description,
      'counterparty': counterparty,
      'status': status,
      'transaction_id': transactionId,
      'showcase_item_id': showcaseItemId,
      'quantity': quantity,
      'total_amount': totalAmount,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items,
    };
  }
}