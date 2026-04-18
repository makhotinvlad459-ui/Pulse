import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

final homeProvider = FutureProvider((ref) async {
  final api = ApiClient();
  final companies = await api.getCompanies();
  final overview = await api.getUserOverview();
  final countsResponse = await api.get('/notifications/unread-counts');
  final counts = countsResponse.data as Map<String, dynamic>;
  return (companies: companies, overview: overview, counts: counts);
});
