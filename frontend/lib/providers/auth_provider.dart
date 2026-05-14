import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/user.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  AuthState({this.user, this.isLoading = false, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  final ApiClient _api = ApiClient();

  Future<bool> register(String email, String? phone, String fullName, String password) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _api.post('/auth/register', data: {
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'password': password,
      });
      if (response.statusCode != 200) throw Exception('Server error');
      final data = response.data;
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      final token = data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      await _api.setToken(token);
      final loaded = await _loadUserProfile();
      return loaded;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _api.postForm('/auth/login', data: {
        'username': username,
        'password': password,
      });
      if (response.statusCode != 200) throw Exception('Server error: ${response.statusCode}');
      final data = response.data;
      if (data is! Map<String, dynamic>) throw Exception('Invalid response format');
      final token = data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      await _api.setToken(token);
      final loaded = await _loadUserProfile();
      return loaded;
    } catch (e) {
      print('login error: $e');
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
    try {
      final response = await _api.get('/auth/me');
      if (response.statusCode != 200) throw Exception('Failed to fetch profile');
      final data = response.data;
      if (data is! Map<String, dynamic>) throw Exception('Invalid profile data');

      print('Profile data: $data');

      // Безопасное извлечение
      final id = (data['id'] as num).toInt();
      final email = data['email'] as String;
      final fullName = data['full_name'] as String;
      final roleStr = data['role'] as String;
      final phone = data['phone'] as String?;
      final subUntilStr = data['subscription_until'] as String?;

      print('Parsed: id=$id, email=$email, name=$fullName, role=$roleStr, phone=$phone, sub=$subUntilStr');

      final user = User(
        id: id,
        email: email,
        phone: phone,
        fullName: fullName,
        role: _stringToRole(roleStr),
        subscriptionUntil: subUntilStr != null ? DateTime.parse(subUntilStr) : null,
      );
      state = AuthState(user: user);
      return true;
    } catch (e, stack) {
      print('Profile load error: $e');
      print('Stack: $stack');
      state = AuthState(error: 'Profile load error: $e');
      return false;
    }
  }

  UserRole _stringToRole(String role) {
    switch (role.toLowerCase()) {
      case 'founder': return UserRole.founder;
      case 'employee': return UserRole.employee;
      case 'superadmin': return UserRole.superadmin;
      default: return UserRole.employee;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    state = AuthState();
  }
}