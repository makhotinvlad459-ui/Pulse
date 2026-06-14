import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';

final productionJournalProvider = StateNotifierProvider<ProductionJournalNotifier, List<dynamic>>((ref) {
  return ProductionJournalNotifier();
});

class ProductionJournalNotifier extends StateNotifier<List<dynamic>> {
  ProductionJournalNotifier() : super([]);
  final ApiClient _api = ApiClient();

  Future<void> loadEntries(int companyId, DateTime start, DateTime end) async {
    try {
      print('🔵 Loading: start=${start.toIso8601String()}, end=${end.toIso8601String()}');
      final res = await _api.get('/production/journal', queryParameters: {
        'company_id': companyId,
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
      });
      print('✅ Loaded ${res.data.length} entries');
      state = res.data;
    } catch (e) {
      print('❌ Error: $e');
      state = [];
    }
  }

  Future<void> deleteEntry(int companyId, int entryId) async {
    try {
      await _api.delete('/production/journal/$entryId', queryParameters: {'company_id': companyId});
      state = state.where((e) => e['id'] != entryId).toList();
    } catch (e) {
      print('Error deleting: $e');
    }
  }
}