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
      totalCash: (json['total_cash'] as num).toDouble(),
      totalBank: (json['total_bank'] as num).toDouble(),
      totalAll: (json['total_all'] as num).toDouble(),
      hasAnyAccountsPermission: json['has_any_accounts_permission'] ?? false,
    );
  }
}