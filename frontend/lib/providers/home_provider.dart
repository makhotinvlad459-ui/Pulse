import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

final homeProvider = FutureProvider((ref) async {
  final api = ApiClient();
  final companies = await api.getCompanies();
  final overview = await api.getUserOverview();
  return (companies: companies, overview: overview);
});
