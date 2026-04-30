import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart'; // добавьте импорт Dio
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
      String email, String phone, String fullName, String password) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _api.post('/auth/register', data: {
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'password': password,
      });
      final token = response.data['access_token'];
      await _api.setToken(token);
      await _loadUserProfile();
      return true;
    } catch (e) {
      String errorMessage;
      if (e is DioError && e.response?.statusCode == 400) {
        errorMessage = 'Пользователь с таким телефоном или email уже существует';
      } else {
        errorMessage = e.toString();
      }
      state = AuthState(error: errorMessage);
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
      final token = response.data['access_token'];
      await _api.setToken(token);
      await _loadUserProfile();
    } catch (e) {
      String errorMessage;
      if (e is DioError) {
        if (e.response?.statusCode == 401) {
          errorMessage = 'Неверный логин или пароль';
        } else if (e.response?.statusCode == 403) {
          errorMessage = 'Учётная запись деактивирована';
        } else {
          errorMessage = 'Ошибка подключения к серверу';
        }
      } else {
        errorMessage = e.toString();
      }
      state = AuthState(error: errorMessage);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _api.get('/auth/me');
      final data = response.data;
      final user = User(
        id: data['id'],
        email: data['email'],
        phone: data['phone'],
        fullName: data['full_name'],
        role: _stringToRole(data['role']),
        subscriptionUntil: data['subscription_until'] != null
            ? DateTime.parse(data['subscription_until'])
            : null,
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: 'Failed to load user profile: $e');
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