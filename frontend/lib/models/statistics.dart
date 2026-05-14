class FounderOverview {
  final double totalCash;
  final double totalBank;
  final double totalAll;
  final bool hasAnyAccountsPermission;

  FounderOverview({
    required this.totalCash,
    required this.totalBank,
    required this.totalAll,
    required this.hasAnyAccountsPermission,
  });

  factory FounderOverview.fromJson(Map<String, dynamic> json) {
    return FounderOverview(
      totalCash: (json['total_cash'] as num?)?.toDouble() ?? 0.0,
      totalBank: (json['total_bank'] as num?)?.toDouble() ?? 0.0,
      totalAll: (json['total_all'] as num?)?.toDouble() ?? 0.0,
      hasAnyAccountsPermission: json['has_any_accounts_permission'] ?? false,
    );
  }
}