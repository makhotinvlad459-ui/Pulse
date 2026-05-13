enum UserRole { founder, employee, superadmin }

class User {
  final int id;
  final String email;
  final String? phone;  // теперь может быть null
  final String fullName;
  final UserRole role;
  final DateTime? subscriptionUntil;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    this.phone,           // не required, может быть null
    required this.fullName,
    required this.role,
    this.subscriptionUntil,
    this.lastLogin,
  });


  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        email: json['email'],
        phone: json['phone'],
        fullName: json['full_name'],
        role: UserRole.values
            .firstWhere((e) => e.toString().split('.').last == json['role']),
        subscriptionUntil: json['subscription_until'] != null
            ? DateTime.parse(json['subscription_until'])
            : null,
        lastLogin: json['last_login'] != null
            ? DateTime.parse(json['last_login'])
            : null,
      );
}
