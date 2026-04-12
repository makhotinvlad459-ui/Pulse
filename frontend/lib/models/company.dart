class Company {
  final int id;
  final String inn;
  final String name;
  final String bankAccount;
  final String managerFullName;
  final String managerPhone;
  final double totalBalance;

  Company({
    required this.id,
    required this.inn,
    required this.name,
    required this.bankAccount,
    required this.managerFullName,
    required this.managerPhone,
    required this.totalBalance,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      inn: json['inn'],
      name: json['name'],
      bankAccount: json['bank_account'],
      managerFullName: json['manager_full_name'],
      managerPhone: json['manager_phone'],
      totalBalance: (json['total_balance'] as num).toDouble(),
    );
  }
}
