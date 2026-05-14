import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    if (kIsWeb) return '/api';
    if (Platform.isAndroid) return 'http://93.115.19.96:8000';
    return 'http://93.115.19.96:8000';
  }

  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Dio get dio => _dio;

  ApiClient() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          await clearToken();
          // Исправленная строка – безопасный вызов с ?.
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
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
  }

  // Загрузка фото (мобильное устройство)
  Future<void> uploadPhoto(String path, XFile photo,
      {Map<String, dynamic>? queryParameters}) async {
    final bytes = await photo.readAsBytes();
    final multipartFile = MultipartFile.fromBytes(bytes, filename: photo.name);
    final formData = FormData.fromMap({'file': multipartFile});
    await _dio.post(path, data: formData, queryParameters: queryParameters);
  }

  // Загрузка байтов (для веб‑файлов)
  Future<void> uploadPhotoBytes(String path, List<int> bytes, String filename,
      {Map<String, dynamic>? queryParameters}) async {
    final multipartFile = MultipartFile.fromBytes(bytes, filename: filename);
    final formData = FormData.fromMap({'file': multipartFile});
    await _dio.post(path, data: formData, queryParameters: queryParameters);
  }

  // Получение файла
  Future<Response> getFile(String path,
      {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path,
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes));
  }

  // Управление токеном
  Future<void> setToken(String token) async =>
      await _storage.write(key: 'access_token', value: token);
  Future<void> clearToken() async => await _storage.delete(key: 'access_token');
  Future<String?> getToken() async => await _storage.read(key: 'access_token');

  // ========== Методы для работы с API ==========
  Future<List<Company>> getCompanies() async {
    final response = await get('/companies');
    final List<dynamic> data = response.data;
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

  Future<Map<String, dynamic>> uploadChatFile(
    XFile? photo,
    PlatformFile? webFile,
    int companyId,
  ) async {
    final uri = Uri.parse('$baseUrl/chat/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${await getToken()}';
    if (photo != null) {
      request.files.add(await http.MultipartFile.fromPath('file', photo.path));
    } else if (webFile != null && webFile.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        webFile.bytes!,
        filename: webFile.name,
      ));
    } else {
      throw Exception('No file provided');
    }
    request.fields['company_id'] = companyId.toString();
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception('Failed to upload chat file: ${response.body}');
    }
    return jsonDecode(response.body);
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
}