import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/secure_storage.dart';
import '../services/websocket_service.dart';
import '../models/user.dart';
import '../services/error/error_handler.dart';
import '../services/fcm_service.dart'; // 👈 ДОБАВЬ ИМПОРТ

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
  final SecureStorage _storage = SecureStorage();

  Future<void> syncLanguage(String langCode) async {
    await _api.updateLanguage(langCode);
  }

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
      
      // 👇 ДОБАВЛЯЕМ ОТПРАВКУ FCM ТОКЕНА ПОСЛЕ РЕГИСТРАЦИИ
      if (loaded) {
        await FcmService().updateFcmToken();
      }
      
      return loaded;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> refreshAccessToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _api.post('/auth/refresh', data: {'refresh_token': refreshToken});
      if (response.statusCode != 200) return false;
      final newAccess = response.data['access_token'] as String?;
      if (newAccess == null) return false;
      await _api.setToken(newAccess);
      WebSocketService().refreshAllConnections();
      return true;
    } catch (e) {
      print('Refresh error: $e');
      return false;
    }
  }

  Future<bool> login(String username, String password, Locale currentLocale) async {
    state = AuthState(isLoading: true);
    try {
      final response = await _api.postForm('/auth/login', data: {
        'username': username,
        'password': password,
      });
      
      final data = response.data;
      if (data is! Map<String, dynamic>) throw Exception('Invalid response format');
      
      final token = data['access_token'] as String?;
      if (token == null) throw Exception('No token in response');
      
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken != null) {
        await _storage.setRefreshToken(refreshToken);
      }
      
      await _api.setToken(token);
      
      final loaded = await _loadUserProfile();
      
      if (loaded) {
        await syncLanguage(currentLocale.languageCode);
        
       
        // Отправка FCM токена ТОЛЬКО НЕ НА WEB
        if (!kIsWeb) {
          try {
            await FcmService().updateFcmToken();
            print('✅ [FCM] Токен обновлен после логина');
          } catch (e) {
            print('⚠️ [FCM] Ошибка обновления токена после логина: $e');
          }
        } else {
          print('⚠️ [FCM] Web режим: токен НЕ отправляется');
        }
        
      }
      
      return loaded;
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      state = AuthState(error: appError.message);
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
    await _storage.clearTokens();
    _api.clearAuth();
    WebSocketService().disconnectAll();
    state = AuthState();
  }
}