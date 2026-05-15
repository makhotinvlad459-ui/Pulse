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
  final companies = await api.getCompanies();
  final overview = await api.getUserOverview();

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

  return HomeData(companies: companies, overview: overview, counts: counts);
});