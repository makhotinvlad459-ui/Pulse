enum UserRole { founder, employee, superadmin }

class User {
  final int id;
  final String email;
  final String? phone;
  final String fullName;
  final UserRole role;
  final DateTime? subscriptionUntil;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    this.subscriptionUntil,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.employee,
      ),
      subscriptionUntil: json['subscription_until'] != null
          ? DateTime.tryParse(json['subscription_until'].toString())
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
    );
  }
}