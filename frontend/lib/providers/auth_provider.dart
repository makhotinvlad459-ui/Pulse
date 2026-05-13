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
      final token = response.data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      await _api.setToken(token);
      return await _loadUserProfile();
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
      final token = response.data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      // ⚠️ ВАЖНО: сохраняем токен!
      await _api.setToken(token);
      return await _loadUserProfile();
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
    try {
      final response = await _api.get('/auth/me');
      final data = response.data;
      print('📦 /auth/me response: $data'); // посмотрим в консоли
      final id = data['id'] as int?;
      final email = data['email'] as String?;
      final fullName = data['full_name'] as String?;
      final roleStr = data['role'] as String?;
      if (id == null || email == null || fullName == null || roleStr == null) {
        throw Exception('Missing fields');
      }
      final user = User(
        id: id,
        email: email,
        phone: data['phone']?.toString() ?? '',
        fullName: fullName,
        role: _stringToRole(roleStr),
        subscriptionUntil: data['subscription_until'] != null
            ? DateTime.tryParse(data['subscription_until'].toString())
            : null,
      );
      state = AuthState(user: user);
      return true;
    } catch (e) {
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