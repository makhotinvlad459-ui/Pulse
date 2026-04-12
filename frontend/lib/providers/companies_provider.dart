import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../models/company.dart';

final companiesProvider = FutureProvider<List<Company>>((ref) async {
  final api = ApiClient();
  final response = await api.get('/companies');
  final List<dynamic> data = response.data;
  return data.map((json) => Company.fromJson(json)).toList();
});
