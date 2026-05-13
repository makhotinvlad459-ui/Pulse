import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/user.dart';

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.isLoading = false, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  final ApiClient _api = ApiClient();

  Future<bool> register(
    String email, String? phone, String fullName, String password) async {
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
      print('✅ Register token: $token');
      await _api.setToken(token);
      final loaded = await _loadUserProfile();
      return loaded;
    } catch (e) {
      print('❌ Register error: $e');
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> login(String username, String password) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _api.postForm('/auth/login', data: {
        'username': username,
        'password': password,
      });
      final token = response.data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      print('✅ Login token: $token');
      await _api.setToken(token);
      await _loadUserProfile();  // не проверяем результат, ошибка внутри
    } catch (e) {
      print('❌ Login error: $e');
      state = AuthState(error: e.toString());
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      print('🔄 Loading user profile...');
      final response = await _api.get('/auth/me');
      final data = response.data;
      print('📦 Profile data: $data');
      if (data == null) throw Exception('No data');
      final userId = data['id'] as int?;
      final email = data['email'] as String?;
      final phone = data['phone'] as String?;
      final fullName = data['full_name'] as String?;
      final roleStr = data['role'] as String?;
      final subUntil = data['subscription_until'] as String?;
      
      if (userId == null || email == null || fullName == null || roleStr == null) {
        throw Exception('Incomplete user data');
      }
      
      final user = User(
        id: userId,
        email: email,
        phone: phone ?? '',
        fullName: fullName,
        role: _stringToRole(roleStr),
        subscriptionUntil: subUntil != null ? DateTime.parse(subUntil) : null,
      );
      state = AuthState(user: user);
      print('✅ Profile loaded, user: ${user.email}');
    } catch (e) {
      print('❌ Load profile error: $e');
      state = AuthState(error: 'Failed to load profile: $e');
    }
  }

  UserRole _stringToRole(String role) {
    switch (role) {
      case 'founder':
        return UserRole.founder;
      case 'employee':
        return UserRole.employee;
      case 'superadmin':
        return UserRole.superadmin;
      default:
        return UserRole.employee;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    state = AuthState();
  }
}