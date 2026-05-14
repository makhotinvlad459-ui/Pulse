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
      print('📤 Register response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final token = response.data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      await _api.setToken(token);
      final profileLoaded = await _loadUserProfile();
      return profileLoaded;
    } catch (e) {
      print('❌ Register error: $e');
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
      print('📤 Login response status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final token = response.data['access_token'] as String?;
      if (token == null) throw Exception('No token');
      await _api.setToken(token);
      final profileLoaded = await _loadUserProfile();
      return profileLoaded;
    } catch (e) {
      print('❌ Login error: $e');
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
    try {
      print('🔄 Loading user profile...');
      final response = await _api.get('/auth/me');
      print('📥 /auth/me status: ${response.statusCode}');
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
      final data = response.data;
      print('📦 Profile raw data: $data');

      final id = data['id'];
      final email = data['email'];
      final fullName = data['full_name'];
      final roleStr = data['role'];

      if (id == null || email == null || fullName == null || roleStr == null) {
        throw Exception('Missing required fields');
      }

      final user = User(
        id: id is int ? id : int.parse(id.toString()),
        email: email.toString(),
        phone: data['phone']?.toString() ?? '',
        fullName: fullName.toString(),
        role: _stringToRole(roleStr.toString()),
        subscriptionUntil: data['subscription_until'] != null
            ? DateTime.tryParse(data['subscription_until'].toString())
            : null,
      );
      state = AuthState(user: user);
      print('✅ Profile loaded for: ${user.email}');
      return true;
    } catch (e) {
      print('❌ Load profile error: $e');
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