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
  final String? showcaseItemName;  
  final int quantity;
  final double totalAmount;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<dynamic>? items;
  final List<dynamic>? attachments;  
  final int? assignedToId;
  final String? assignedToName;

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
    this.showcaseItemName,           
    required this.quantity,
    required this.totalAmount,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.items,
    this.attachments,
    this.assignedToId,      
    this.assignedToName,
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
      showcaseItemName: json['showcase_item_name'], // <-- добавьте
      quantity: json['quantity'] ?? 1,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      items: json['items'] as List?,
      attachments: json['attachments'] as List?,
      assignedToId: json['assigned_to_id'],      
      assignedToName: json['assigned_to_name'],
    );
  }
}