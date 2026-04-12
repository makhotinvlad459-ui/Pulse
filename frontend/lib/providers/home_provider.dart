import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../models/company.dart';
import '../models/statistics.dart';

final homeProvider = FutureProvider((ref) async {
  final api = ApiClient();
  final companies = await api.getCompanies();
  final overview = await api.getFounderOverview();
  return (companies: companies, overview: overview);
});
