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
      if (response.statusCode != 200) throw Exception('Server error');
      final data = response.data;
      if (data is! Map<String, dynamic>) throw Exception('Invalid response');
      final token = data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      print('Token before setToken: $token');
      await _api.setToken(token);
      final loaded = await _loadUserProfile();
      return loaded;
    } catch (e) {
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

      // Безопасное извлечение с дефолтными значениями
      final rawId = data['id'];
      final int parsedId = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
      final email = data['email']?.toString() ?? '';
      final fullName = data['full_name']?.toString() ?? 'No Name';
      final roleStr = data['role']?.toString() ?? 'employee';
      final phone = data['phone']?.toString(); // может быть null
      final subUntilStr = data['subscription_until']?.toString();

      final user = User(
        id: parsedId,
        email: email,
        phone: phone,
        fullName: fullName,
        role: _stringToRole(roleStr),
        subscriptionUntil: subUntilStr != null ? DateTime.tryParse(subUntilStr) : null,
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