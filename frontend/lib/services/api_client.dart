import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../models/company.dart';
import '../models/statistics.dart';
import '../main.dart';

class ApiClient {
  static String get baseUrl {
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (isProduction) {
      // Режим продакшена (release-сборка)
      if (kIsWeb) {
        
        return '/api'; 
      }
      // Для Android/iOS мобильных приложений прописываем новый защищенный HTTPS домен
      return 'https://pulse-yourmoney.com/api';
    } else {
      // Режим разработки (debug) — тут всё оставляем как было для локальных тестов
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
      headers: {},                     // инициализация (на всякий случай)
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers ??= {};       // гарантируем, что headers не null
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          await clearToken();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          });
          return handler.reject(e);
        }
        return handler.next(e);
      },
    ));

    _dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  }

  // Базовые методы
  Future<Response> post(String path,
          {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.post(path, data: data, queryParameters: queryParameters);

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> put(String path,
          {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.put(path, data: data, queryParameters: queryParameters);

  Future<Response> patch(String path,
          {dynamic data, Map<String, dynamic>? queryParameters}) =>
      _dio.patch(path, data: data, queryParameters: queryParameters);

  Future<Response> delete(String path,
          {Map<String, dynamic>? queryParameters}) =>
      _dio.delete(path, queryParameters: queryParameters);

  Future<Response> postForm(String path, {required Map<String, String> data}) async {
    return await _dio.post(
      path,
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {},                   // предотвращает сброс headers
      ),
    );
  }

  // Загрузка фото (мобильное устройство)
  Future<Map<String, dynamic>> uploadChatFile({
    required int companyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }
      
      final formData = FormData.fromMap({
        'company_id': companyId.toString(),
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });
      
      print('📤 Uploading file to: /chat/upload');
      print('   Company ID: $companyId');
      print('   Filename: $filename');
      print('   File size: ${bytes.length} bytes');
      
      final response = await _dio.post(
        '/chat/upload',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      
      print('✅ Upload response: ${response.statusCode}');
      print('   Data: ${response.data}');
      
      return response.data as Map<String, dynamic>;
      
    } on DioException catch (e) {
      print('❌ Upload error: ${e.response?.statusCode} - ${e.response?.data}');
      throw Exception('Upload failed: ${e.response?.data['detail'] ?? e.message}');
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }
Future<Response> getFile(String path,
    {Map<String, dynamic>? queryParameters}) async {
  final token = await getToken();
  
  // Если это полный URL (http:// или https://)
  if (path.startsWith('http')) {
    return await _dio.get(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  } else {
    // Если это относительный путь
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}

  // Управление токеном – теперь только через storage!
  Future<void> setToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
    // НЕ трогаем _dio.options.headers – перехватчик сам всё сделает
  }

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

    // Замените существующий метод uploadChatFile на этот:
Future<Map<String, dynamic>> uploadChatFile({
  required int companyId,
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token');
    }
    
    // Определяем content-type для файла
    String contentType = 'application/octet-stream';
    if (filename.toLowerCase().endsWith('.jpg') || 
        filename.toLowerCase().endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else if (filename.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    } else if (filename.toLowerCase().endsWith('.gif')) {
      contentType = 'image/gif';
    } else if (filename.toLowerCase().endsWith('.pdf')) {
      contentType = 'application/pdf';
    }
    
    final formData = FormData.fromMap({
      'company_id': companyId.toString(),
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    });
    
    print('📤 Uploading to: /chat/upload');
    print('   Company ID: $companyId');
    print('   File: $filename (${bytes.length} bytes)');
    print('   Content-Type: $contentType');
    
    final response = await _dio.post(
      '/chat/upload',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
        // Не устанавливайте contentType принудительно, Dio сам установит multipart/form-data с boundary
      ),
    );
    
    print('✅ Upload success: ${response.statusCode}');
    print('   Response: ${response.data}');
    
    return response.data;
  } on DioException catch (e) {
    print('❌ Dio error in uploadChatFile:');
    print('   Status: ${e.response?.statusCode}');
    print('   Response: ${e.response?.data}');
    print('   Headers: ${e.response?.headers}');
    throw Exception('Upload failed: ${e.response?.data ?? e.message}');
  } catch (e) {
    print('❌ Unexpected error in uploadChatFile: $e');
    rethrow;
  }
}
  // Методы для работы с правами
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

// Добавь эти методы в класс ApiClient в файле api_client.dart

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
    queryParameters: {'company_id': companyId},  // <-- company_id в query параметр
  );
  return response.data;
}
  

  Future<Map<String, dynamic>> uploadCompanyLogo(
      {required int companyId, required Uint8List bytes, required String filename}) async {
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
    options: Options(
      responseType: ResponseType.bytes,  // важно!
    ),
  );
  return response;
}

  Future<Response> getTransactionFile(int transactionId) async {
  final response = await dio.get(
    '/transactions/$transactionId/file',
    options: Options(
      responseType: ResponseType.bytes,
    ),
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