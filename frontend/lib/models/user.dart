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
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => UserRole.employee,
      ),
      subscriptionUntil: json['subscription_until'] != null
          ? DateTime.parse(json['subscription_until'] as String)
          : null,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }
}