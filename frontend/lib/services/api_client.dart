import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'secure_storage.dart';
import '../models/company.dart';
import '../models/statistics.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';

class ApiClient {
  static String get baseUrl {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (isProduction) {
      if (kIsWeb) {
        return '/api';
      }
      return 'https://pulse-yourmoney.com/api';
    } else {
      if (kIsWeb) return 'http://localhost:8000/api';
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
      return 'http://localhost:8000/api';
    }
  }

  final Dio _dio = Dio();
  final SecureStorage _storage = SecureStorage();

  Dio get dio => _dio;

  ApiClient() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      headers: {},
    );

    _dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers ??= {};
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  },
  onError: (DioException e, handler) async {
    final isAuthEndpoint = e.requestOptions.path.contains('/auth/login') ||
                           e.requestOptions.path.contains('/auth/register');

    if (e.response?.statusCode == 401 && !isAuthEndpoint) {
      final container = ProviderScope.containerOf(navigatorKey.currentContext!);
      final authNotifier = container.read(authProvider.notifier);
      final refreshed = await authNotifier.refreshAccessToken();

      if (refreshed) {
        final newToken = await _storage.read(key: 'access_token');
        e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        try {
          final response = await _dio.fetch(e.requestOptions);
          return handler.resolve(response);
        } catch (_) {
          _redirectToLogin();
          return handler.reject(e);
        }
      } else {
        _redirectToLogin();
        return handler.reject(e);
      }
    }

    final errorMessage = _getLocalizedErrorMessage(e);
    final userFriendlyError = DioException(
      requestOptions: e.requestOptions,
      response: e.response,
      type: e.type,
      error: errorMessage,
    );
    return handler.reject(userFriendlyError);
  },
));

_dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    });
  }

  String _getLocalizedErrorMessage(DioException e) {
  // Получаем локализацию
  final context = navigatorKey.currentContext;
  final t = context != null ? AppLocalizations.of(context) : null;

  String tr(String key, [String fallback = '']) {
    if (t == null) return fallback.isEmpty ? key : fallback;
    try {
      final value = (t as dynamic)[key];
      if (value is String) return value;
      return fallback.isEmpty ? key : fallback;
    } catch (_) {
      return fallback.isEmpty ? key : fallback;
    }
  }

  // Сетевые ошибки
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError) {
    return tr('error_connection', 'No connection to server. Check your internet.');
  }

  // Ошибки с ответом сервера
  if (e.response != null) {
    final statusCode = e.response!.statusCode;
    final data = e.response!.data;

    // Пытаемся извлечь сообщение из поля detail
    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail') && data['detail'] is String) {
        final detail = data['detail'] as String;
        // Переводим стандартное сообщение о неверных учётных данных
        if (detail == 'Invalid credentials' && t != null) {
          return tr('error_invalid_credentials', 'Invalid email or password');
        }
        return detail;
      }
      if (data.containsKey('message') && data['message'] is String) {
        return data['message'];
      }
      if (data.containsKey('error') && data['error'] is String) {
        return data['error'];
      }
    }

    // Если не удалось извлечь, возвращаем сообщение с кодом
    if (statusCode != null) {
      return tr('error_server', 'Server error: $statusCode').replaceFirst('{code}', '$statusCode');
    }
  }

  // Неизвестная ошибка
  final msg = e.message ?? '';
  return tr('error_unknown', 'An error occurred: $msg').replaceFirst('{message}', msg);
}

  // Базовые методы
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.post(path, data: data, queryParameters: queryParameters);

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.put(path, data: data, queryParameters: queryParameters);

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.patch(path, data: data, queryParameters: queryParameters);

  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.delete(path, queryParameters: queryParameters);

  Future<Response> postForm(String path, {required Map<String, String> data}) async {
    return await _dio.post(
      path,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {},
      ),
    );
  }

  // Загрузка файлов
  Future<Map<String, dynamic>> uploadChatFile({
    required int companyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final token = await getToken();
      if (token == null) throw Exception('No authentication token');
      final formData = FormData.fromMap({
        'company_id': companyId.toString(),
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post(
        '/chat/upload',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_getLocalizedErrorMessage(e));
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  Future<Response> getFile(String path, {Map<String, dynamic>? queryParameters}) async {
    final token = await getToken();
    if (path.startsWith('http')) {
      return await _dio.get(
        path,
        options: Options(responseType: ResponseType.bytes, headers: {'Authorization': 'Bearer $token'}),
      );
    } else {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes, headers: {'Authorization': 'Bearer $token'}),
      );
    }
  }

  // Управление токеном
  Future<void> setToken(String token) async => await _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() async => await _storage.delete(key: 'access_token');
  Future<String?> getToken() async => await _storage.read(key: 'access_token');

  // ========== Методы для работы с API ==========
  Future<List<Company>> getCompanies() async {
    final response = await get('/companies');
    final data = response.data;
    if (data is! List) {
      print('Ошибка: получен не список, а ${data.runtimeType}. Ответ: $data');
      return [];
    }
    return data.map((json) => Company.fromJson(json)).toList();
  }

  Future<FounderOverview> getFounderOverview() async {
    final response = await get('/statistics/founder-overview');
    return FounderOverview.fromJson(response.data);
  }

  Future<FounderOverview> getUserOverview() async {
    final response = await get('/statistics/user-overview');
    return FounderOverview.fromJson(response.data);
  }

  Future<void> updateLanguage(String langCode) async {
    try {
      await post('/auth/update-language', data: {'language': langCode});
    } catch (e) {
      print('Error updating language on server: $e');
    }
  }

  Future<Map<String, dynamic>> getUnreadCounts() async {
    final response = await get('/notifications/unread-counts');
    return response.data as Map<String, dynamic>;
  }

  Future<dynamic> getDynamics(int companyId, DateTime startDate, DateTime endDate, String interval) async {
    return await get('/statistics/dynamics', queryParameters: {
      'company_id': companyId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'interval': interval,
    });
  }

  Future<dynamic> getIncomeByCategory(int companyId, DateTime startDate, DateTime endDate) async {
    return await get('/statistics/income-by-category', queryParameters: {
      'company_id': companyId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });
  }

  Future<dynamic> getExpenseByCategory(int companyId, DateTime startDate, DateTime endDate) async {
    return await get('/statistics/expense-by-category', queryParameters: {
      'company_id': companyId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });
  }

  Future<dynamic> getCashVsNoncash(int companyId, DateTime startDate, DateTime endDate) async {
    return await get('/statistics/cash-vs-noncash', queryParameters: {
      'company_id': companyId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    });
  }

  Future<dynamic> getProductSales(int companyId, DateTime startDate, DateTime endDate, String sortBy) async {
    return await get('/statistics/product-sales', queryParameters: {
      'company_id': companyId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'sort_by': sortBy,
    });
  }

  Future<dynamic> getShowcaseSales(int companyId, DateTime startDate, DateTime endDate, String sortBy) async {
    return await get('/statistics/showcase-sales', queryParameters: {
      'company_id': companyId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'sort_by': sortBy,
    });
  }

  // ========== Методы для работы с правами ==========
  Future<List<dynamic>> getAllPermissions() async {
    final response = await get('/permissions/list');
    return response.data;
  }

  Future<Map<String, dynamic>> getMyPermissions(int companyId) async {
    final response = await get('/permissions/company/$companyId/my');
    return response.data;
  }

  Future<List<dynamic>> getCompanyPermissions(int companyId) async {
    final response = await get('/permissions/company/$companyId');
    return response.data;
  }

  Future<void> updateMemberPermissions(int companyId, int memberId, List<String> permissionNames) async {
    await put('/permissions/company/$companyId/member/$memberId', data: {'permission_names': permissionNames});
  }

  Future<Company> getCompany(int companyId) async {
    final response = await get('/companies/$companyId');
    return Company.fromJson(response.data);
  }

  // ========== Загрузка файлов ==========
  Future<Map<String, dynamic>> uploadTransactionFile({
    required int companyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post(
      '/transactions/upload',
      data: formData,
      queryParameters: {'company_id': companyId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> uploadCompanyLogo({
    required int companyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    FormData formData = FormData.fromMap({
      "file": MultipartFile.fromBytes(bytes, filename: filename),
      "company_id": companyId,
    });
    final response = await _dio.post('/companies/$companyId/logo', data: formData);
    return response.data;
  }

  Future<Response> getChatFile(int messageId) async {
    final response = await dio.get(
      '/chat/file/$messageId',
      options: Options(responseType: ResponseType.bytes),
    );
    return response;
  }

  Future<Response> getTransactionFile(int transactionId) async {
    final response = await dio.get(
      '/transactions/$transactionId/file',
      options: Options(responseType: ResponseType.bytes),
    );
    return response;
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await post('/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
}