import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage.dart';
import '../models/company.dart';
import '../models/statistics.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/journal_entry.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;


class ApiClient {
  static String get baseUrl {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    // Переопределение для отладки на реальном устройстве
    const String customDebugUrl = String.fromEnvironment('DEBUG_API_URL');
    
    // Web
    if (kIsWeb) {
      if (isProduction) return '/api';
      return 'http://localhost:8000/api';
    }
    
    // Релизные сборки (Android, iOS)
    if (isProduction) {
      return 'https://pulse-yourmoney.com/api';
    }
    
    // Debug-режим на мобильных устройствах
    if (kDebugMode) {
      // Если передан кастомный URL через --dart-define, используем его
      if (customDebugUrl.isNotEmpty) {
        return customDebugUrl;
      }
      // Для Android-эмулятора
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8000/api';
      }
      // Для iOS-симулятора
      if (Platform.isIOS) {
        return 'http://localhost:8000/api';
      }
    }
    
    // Fallback
    return 'http://localhost:8000/api';
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
      validateStatus: (status) => status != null && status < 400,
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

  void clearAuth() {
  _dio.options.headers.remove('Authorization');
}

  void _redirectToLogin() async {
  await _storage.delete(key: 'access_token');
  await _storage.delete(key: 'refresh_token');
  _dio.options.headers.remove('Authorization'); // 👈 добавить
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

  // ========== НОВАЯ ОБРАБОТКА 402 (Payment Required) ==========
  if (e.response?.statusCode == 402) {
    // Показываем диалог о необходимости подписки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        _showSubscriptionRequiredDialog(navigatorKey.currentContext!);
      }
    });
    return e.response?.data?['detail'] ?? 'Достигнут лимит бесплатных операций. Оформите подписку.';
  }
  // ============================================================

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

    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail') && data['detail'] is String) {
        final detail = data['detail'] as String;
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

    if (statusCode != null) {
      return tr('error_server', 'Server error: $statusCode').replaceFirst('{code}', '$statusCode');
    }
  }

  final msg = e.message ?? '';
  return tr('error_unknown', 'An error occurred: $msg').replaceFirst('{message}', msg);
}

void _showSubscriptionRequiredDialog(BuildContext context) {
  final t = AppLocalizations.of(context);
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          const SizedBox(width: 8),
          Text(t?.subscriptionRequiredTitle ?? 'Лимит исчерпан'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t?.subscriptionRequiredMessage ?? 'Вы достигли лимита бесплатных операций.'),
          const SizedBox(height: 12),
          Text(
            t?.subscriptionRequiredAction ?? 'Оформите подписку, чтобы продолжить работу без ограничений.',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(t?.cancel ?? 'Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Переход на экран подписки
            Navigator.of(context).pushNamed('/subscription');
          },
          child: Text(t?.upgrade ?? 'Оформить подписку'),
        ),
      ],
    ),
  );
}
  // Базовые методы
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
  try {
    return await _dio.post(path, data: data, queryParameters: queryParameters);
  } catch (e) {
    throw _normalizeError(e);
  }
}

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
  try {
    return await _dio.get(path, queryParameters: queryParameters);
  } catch (e) {
    throw _normalizeError(e);
  }
}

  dynamic _normalizeError(dynamic error) {
  if (error is DioException) {
    // Пробрасываем DioException дальше, но с понятным сообщением
    return error;
  }
  return Exception('Unknown error occurred');
}


  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.put(path, data: data, queryParameters: queryParameters);

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.patch(path, data: data, queryParameters: queryParameters);

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
  final token = await getToken();
  return _dio.delete(
    path,
    data: data,
    queryParameters: queryParameters,
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
}

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

    // ========== Журнал ==========
  Future<List<JournalEntry>> getJournalEntries(int companyId, DateTime start, DateTime end) async {
    final response = await get('/journal/', queryParameters: {
    'company_id': companyId,
    'start_date': start.toIso8601String(),
    'end_date': end.toIso8601String(),
  });
    final List<dynamic> data = response.data;
  return data.map((json) => JournalEntry.fromJson(json)).toList();
}

  Future<JournalEntry> createJournalEntry(int companyId, {
  required DateTime start,
  required DateTime end,
  String? description,
  String? counterparty,
  int? showcaseItemId,
  int quantity = 1,
  double totalAmount = 0.0,
  List<Map<String, dynamic>>? items,
}) async {
  final response = await post('/journal/', queryParameters: {'company_id': companyId}, data: {
    'datetime_start': start.toIso8601String(),
    'datetime_end': end.toIso8601String(),
    'description': description,
    'counterparty': counterparty,
    'showcase_item_id': showcaseItemId,
    'quantity': quantity,
    'total_amount': totalAmount,
    'items': items, // отправляем список объектов
  });
  return JournalEntry.fromJson(response.data);
}

Future<JournalEntry> updateJournalEntry(int companyId, int entryId, {
  DateTime? start,
  DateTime? end,
  String? description,
  String? counterparty,
  int? showcaseItemId,
  int? quantity,
  double? totalAmount,
  List<Map<String, dynamic>>? items,
  String? status,
}) async {
  final data = <String, dynamic>{};
  if (start != null) data['datetime_start'] = start.toIso8601String();
  if (end != null) data['datetime_end'] = end.toIso8601String();
  if (description != null) data['description'] = description;
  if (counterparty != null) data['counterparty'] = counterparty;
  if (showcaseItemId != null) data['showcase_item_id'] = showcaseItemId;
  if (quantity != null) data['quantity'] = quantity;
  if (totalAmount != null) data['total_amount'] = totalAmount;
  if (items != null) data['items'] = items;
  if (status != null) data['status'] = status;
  final response = await patch('/journal/$entryId', queryParameters: {'company_id': companyId}, data: data);
  return JournalEntry.fromJson(response.data);
}

  Future<void> deleteJournalEntry(int companyId, int entryId) async {
    await delete('/journal/$entryId', queryParameters: {'company_id': companyId});
  }

  Future<void> completeJournalEntry(int companyId, int entryId, int accountId) async {
    await post('/journal/$entryId/complete', queryParameters: {
      'company_id': companyId,
      'account_id': accountId,
    });
  }

  Future<Map<String, dynamic>> uploadOrderAttachment({
  required int orderId,
  required int companyId,
  required Uint8List bytes,
  required String filename,
}) async {
  final token = await getToken();
  if (token == null) throw Exception('No authentication token');
  
  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(bytes, filename: filename),
  });
  
  final response = await _dio.post(
    '/orders/$orderId/attachments',
    data: formData,
    queryParameters: {'company_id': companyId},
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  return response.data;
}

Future<Response> getOrderAttachmentFile(int attachmentId, int companyId) async {
  final token = await getToken();
  final response = await _dio.get(
    '/orders/attachments/$attachmentId/file',
    queryParameters: {'company_id': companyId},
    options: Options(
      responseType: ResponseType.bytes,
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
  return response;
}

Future<void> deleteMyAccount(String password) async {
  await delete('/auth/me', data: {'password': password});
}

// ========== Журнал: вложения ==========
Future<Map<String, dynamic>> uploadJournalAttachment({
  required int entryId,
  required int companyId,
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final token = await getToken();
    if (token == null) throw Exception('No authentication token');
    
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    
    final response = await _dio.post(
      '/journal/$entryId/attachments',
      data: formData,
      queryParameters: {'company_id': companyId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw Exception(_getLocalizedErrorMessage(e));
  } catch (e) {
    throw Exception('Upload error: $e');
  }
}

Future<Response> getJournalAttachmentFile(int attachmentId, int companyId) async {
  final token = await getToken();
  return await _dio.get(
    '/journal/attachments/$attachmentId/file',
    queryParameters: {'company_id': companyId},
    options: Options(
      responseType: ResponseType.bytes,
      headers: {'Authorization': 'Bearer $token'},
    ),
  );
}

Future<List<dynamic>> getCounterpartyDocuments(int counterpartyId, int companyId) async {
  final response = await get('/counterparties/$counterpartyId/documents', queryParameters: {'company_id': companyId});
  return response.data;
}

Future<Map<String, dynamic>> uploadCounterpartyDocument({
  required int counterpartyId,
  required int companyId,
  required Uint8List bytes,
  required String filename,
  String? description,
}) async {
  final token = await getToken();
  if (token == null) throw Exception('No token');
  final formData = FormData.fromMap({
    'file': MultipartFile.fromBytes(bytes, filename: filename),
    'description': description,
  });
  final response = await _dio.post(
    '/counterparties/$counterpartyId/documents',
    data: formData,
    queryParameters: {'company_id': companyId},
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
  return response.data;
}

Future<Response> getCounterpartyDocumentFile(int documentId, int companyId) async {
  final token = await getToken();
  return await _dio.get(
    '/counterparties/documents/$documentId/file',
    queryParameters: {'company_id': companyId},
    options: Options(responseType: ResponseType.bytes, headers: {'Authorization': 'Bearer $token'}),
  );
}

// Удалить документ
Future<void> deleteCounterpartyDocument(int documentId, int companyId) async {
  await delete('/counterparties/documents/$documentId', queryParameters: {'company_id': companyId});
}

// Получить записи журнала по контрагенту
Future<List<dynamic>> getCounterpartyJournalEntries(int counterpartyId, int companyId) async {
  final response = await get('/counterparties/$counterpartyId/journal', queryParameters: {'company_id': companyId});
  return response.data;
}

Future<void> deleteJournalAttachment(int attachmentId, int companyId) async {
  await delete('/journal/attachments/$attachmentId', queryParameters: {'company_id': companyId});
}

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await post('/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
}