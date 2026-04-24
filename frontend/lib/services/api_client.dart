import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../models/company.dart';
import '../models/statistics.dart';

class ApiClient {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://192.168.0.115:8000';
    return 'http://localhost:8000';
  }

  final Dio _dio = Dio(); // ← убрали BaseOptions из конструктора
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Публичный геттер для доступа к Dio
  Dio get dio => _dio;

  ApiClient() {
    // Устанавливаем опции с followRedirects и validateStatus
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,               // ← автоматом следовать редиректам
      maxRedirects: 5,
      validateStatus: (status) => status! < 500, // ← не считать 3xx ошибкой
    );

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
    _dio.interceptors
        .add(LogInterceptor(responseBody: true, requestBody: true));
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

  Future<Response> postForm(String path, {required Map<String, String> data}) =>
      _dio.post(path,
          data: data,
          options: Options(contentType: Headers.formUrlEncodedContentType));

  // Загрузка фото (для XFile)
  Future<void> uploadPhoto(String path, XFile photo,
      {Map<String, dynamic>? queryParameters}) async {
    final bytes = await photo.readAsBytes();
    final multipartFile = MultipartFile.fromBytes(bytes, filename: photo.name);
    final formData = FormData.fromMap({'file': multipartFile});
    await _dio.post(path, data: formData, queryParameters: queryParameters);
  }

  // Загрузка байтов (для веб-файлов)
  Future<void> uploadPhotoBytes(String path, List<int> bytes, String filename,
      {Map<String, dynamic>? queryParameters}) async {
    final multipartFile = MultipartFile.fromBytes(bytes, filename: filename);
    final formData = FormData.fromMap({'file': multipartFile});
    await _dio.post(path, data: formData, queryParameters: queryParameters);
  }

  // Получение файла (для просмотра)
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

  // Методы для работы с API
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

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
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
}
