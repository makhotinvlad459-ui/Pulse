import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

final homeProvider = FutureProvider((ref) async {
  final api = ApiClient();
  final companies = await api.getCompanies();
  final overview = await api.getUserOverview();

  // Безопасно получаем counts – если не Map, используем пустой Map
  Map<String, dynamic> counts;
  try {
    final countsResponse = await api.get('/notifications/unread-counts');
    final data = countsResponse.data;
    if (data is Map<String, dynamic>) {
      counts = data;
    } else {
      print('⚠️ counts is not a Map, using empty. Type: ${data.runtimeType}');
      counts = {};
    }
  } catch (e) {
    print('⚠️ Failed to fetch counts: $e');
    counts = {};
  }

  return (companies: companies, overview: overview, counts: counts);
});