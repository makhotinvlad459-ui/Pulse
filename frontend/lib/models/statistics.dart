class FounderOverview {
  final double totalCash;
  final double totalBank;
  final double totalAll;

  FounderOverview(
      {required this.totalCash,
      required this.totalBank,
      required this.totalAll});

  factory FounderOverview.fromJson(Map<String, dynamic> json) {
    return FounderOverview(
      totalCash: (json['total_cash'] as num).toDouble(),
      totalBank: (json['total_bank'] as num).toDouble(),
      totalAll: (json['total_all'] as num).toDouble(),
    );
  }
}
