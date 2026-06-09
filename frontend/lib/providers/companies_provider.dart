import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../models/company.dart';
import '../services/error/safe_api_call.dart';
import '../services/error/error_handler.dart';

final companiesProvider = FutureProvider<List<Company>>((ref) async {
  final api = ApiClient();
  
  // Можно использовать try-catch с ErrorHandler
  try {
    final response = await api.get('/companies');
    final List<dynamic> data = response.data;
    return data.map((json) => Company.fromJson(json)).toList();
  } catch (e) {
    // Пробрасываем обработанную ошибку
    throw ErrorHandler.handleError(e);
  }
});