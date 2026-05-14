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
      print('🔵 Token saved, calling _loadUserProfile...');
      final loaded = await _loadUserProfile();
      print('login: profile loaded = $loaded');
      return loaded;
    } catch (e) {
      print('login error: $e');
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
  try {
    print('🔵 1. _loadUserProfile started');
    final response = await _api.get('/auth/me');
    print('🔵 2. Response status: ${response.statusCode}');
    if (response.statusCode != 200) throw Exception('Failed to fetch profile');
    
    final data = response.data;
    print('🔵 3. Data type: ${data.runtimeType}');
    print('🔵 4. Data content: $data');
    
    if (data is! Map<String, dynamic>) throw Exception('Invalid profile data');
    
    print('🔵 5. Keys: ${data.keys}');
    
    final rawId = data['id'];
    print('🔵 6. rawId: $rawId, type: ${rawId.runtimeType}');
    
    final int parsedId;
    if (rawId is int) {
      parsedId = rawId;
    } else {
      parsedId = int.tryParse(rawId.toString()) ?? 0;
    }
    print('🔵 7. parsedId: $parsedId');
    
    final email = data['email']?.toString() ?? '';
    print('🔵 8. email: $email');
    
    final fullName = data['full_name']?.toString() ?? 'No Name';
    print('🔵 9. fullName: $fullName');
    
    final roleStr = data['role']?.toString() ?? 'employee';
    print('🔵 10. roleStr: $roleStr');
    
    final phone = data['phone']?.toString() ?? '';
    print('🔵 11. phone: $phone');
    
    final subUntilStr = data['subscription_until']?.toString();
    print('🔵 12. subUntilStr: $subUntilStr');
    
    print('🔵 13. Creating User object...');
    final user = User(
      id: parsedId,
      email: email,
      phone: phone,
      fullName: fullName,
      role: _stringToRole(roleStr),
      subscriptionUntil: subUntilStr != null ? DateTime.tryParse(subUntilStr) : null,
    );
    print('🔵 14. User created: ${user.email}');
    
    state = AuthState(user: user);
    print('🔵 15. State updated, returning true');
    return true;
  } catch (e, stack) {
    print('🔴 ERROR in _loadUserProfile: $e');
    print('🔴 Stack: $stack');
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