class TransactionItem {
  final int productId;
  final String productName;
  final double quantity;
  final double? pricePerUnit;

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.pricePerUnit,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      productId: json['product_id'] ?? 0,
      productName: json['product_name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      pricePerUnit: json['price_per_unit'] != null ? (json['price_per_unit'] as num).toDouble() : null,
    );
  }
}

class Transaction {
  final int id;
  final String type;
  final double amount;
  final DateTime date;
  final int accountId;
  final int? categoryId;
  final String? description;
  final String? attachmentUrl;
  final int createdBy;
  final int? updatedBy;
  final bool isDeleted;
  final int? deletedBy;
  final DateTime? deletedAt;
  final int? transferToAccountId;
  final String? creatorName;
  final String? updaterName;
  final int number;
  final List<TransactionItem> items;
  final String? counterparty;  // <-- добавлено

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.accountId,
    this.categoryId,
    this.description,
    this.attachmentUrl,
    required this.createdBy,
    this.updatedBy,
    required this.isDeleted,
    this.deletedBy,
    this.deletedAt,
    this.transferToAccountId,
    this.creatorName,
    this.updaterName,
    required this.number,
    required this.items,
    this.counterparty,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      type: json['type'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      accountId: json['account_id'],
      categoryId: json['category_id'],
      description: json['description'],
      attachmentUrl: json['attachment_url'],
      createdBy: json['created_by'],
      updatedBy: json['updated_by'],
      isDeleted: json['is_deleted'],
      deletedBy: json['deleted_by'],
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      transferToAccountId: json['transfer_to_account_id'],
      creatorName: json['creator_name'],
      updaterName: json['updater_name'],
      number: json['number'],
      items: (json['items'] as List?)?.map((i) => TransactionItem.fromJson(i)).toList() ?? [],
      counterparty: json['counterparty'],
    );
  }
}