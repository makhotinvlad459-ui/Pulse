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
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      transferToAccountId: json['transfer_to_account_id'],
      creatorName: json['creator_name'],
      updaterName: json['updater_name'],
    );
  }
}
