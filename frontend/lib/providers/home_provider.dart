import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../models/company.dart';        
import '../models/statistics.dart';    

class HomeData {
  final List<Company> companies;
  final FounderOverview overview;
  final Map<String, dynamic> counts;

  HomeData({required this.companies, required this.overview, required this.counts});
}

final homeProvider = FutureProvider<HomeData>((ref) async {
  final api = ApiClient();

  // Запускаем все три запроса параллельно
  final results = await Future.wait([
    api.getCompanies(),
    api.getUserOverview(),
    api.get('/notifications/unread-counts').then((response) {
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      print('⚠️ counts not a Map, using empty');
      return {};
    }).catchError((e) {
      print('⚠️ Failed to fetch counts: $e');
      return {};
    }),
  ]);

  final companies = results[0] as List<Company>;
  final overview = results[1] as FounderOverview;
  final counts = results[2] as Map<String, dynamic>;

  return HomeData(companies: companies, overview: overview, counts: counts);
});