import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import '../services/api_client.dart';
import '../services/error/error_handler.dart';

final journalProvider = StateNotifierProvider<JournalNotifier, JournalState>((ref) {
  return JournalNotifier();
});

class JournalState {
  final List<JournalEntry> entries;
  final bool isLoading;
  final String? error;

  JournalState({this.entries = const [], this.isLoading = false, this.error});
}

class JournalNotifier extends StateNotifier<JournalState> {
  JournalNotifier() : super(JournalState());

  final ApiClient _api = ApiClient();


  Future<void> loadEntries(int companyId, DateTime start, DateTime end, {int? assignedToId}) async {
    state = JournalState(isLoading: true, entries: state.entries);
    try {
      final entries = await _api.getJournalEntries(companyId, start, end, assignedToId: assignedToId);
      state = JournalState(entries: entries);
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      state = JournalState(entries: state.entries, error: appError.message);
    }
  }

  Future<JournalEntry?> createEntry(int companyId, {
    required DateTime start,
    required DateTime end,
    String? description,
    String? counterparty,
    int? showcaseItemId,
    int quantity = 1,
    double totalAmount = 0.0,
    List<Map<String, dynamic>>? items,
    int? assignedToId,
  }) async {
    try {
      final newEntry = await _api.createJournalEntry(
        companyId,
        start: start,
        end: end,
        description: description,
        counterparty: counterparty,
        showcaseItemId: showcaseItemId,
        quantity: quantity,
        totalAmount: totalAmount,
        items: items,
        assignedToId: assignedToId,
      );
      state = JournalState(entries: [...state.entries, newEntry]);
      return newEntry;
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      state = JournalState(entries: state.entries, error: appError.message);
      return null;
    }
  }

  // ✅ ДОБАВЛЕН ПАРАМЕТР assignedToId
  Future<bool> updateEntry(int companyId, int entryId, {
    DateTime? start,
    DateTime? end,
    String? description,
    String? counterparty,
    int? showcaseItemId,
    int? quantity,
    double? totalAmount,
    List<Map<String, dynamic>>? items,
    String? status,
    int? assignedToId,
  }) async {
    try {
      final updated = await _api.updateJournalEntry(
        companyId,
        entryId,
        start: start,
        end: end,
        description: description,
        counterparty: counterparty,
        showcaseItemId: showcaseItemId,
        quantity: quantity,
        totalAmount: totalAmount,
        items: items,
        status: status,
        assignedToId: assignedToId,
      );
      final newEntries = state.entries.map((e) => e.id == entryId ? updated : e).toList();
      state = JournalState(entries: newEntries);
      return true;
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      state = JournalState(entries: state.entries, error: appError.message);
      return false;
    }
  }

  Future<bool> deleteEntry(int companyId, int entryId) async {
    try {
      await _api.deleteJournalEntry(companyId, entryId);
      state = JournalState(entries: state.entries.where((e) => e.id != entryId).toList());
      return true;
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      state = JournalState(entries: state.entries, error: appError.message);
      return false;
    }
  }

  Future<bool> completeEntry(int companyId, int entryId, int accountId) async {
    try {
      await _api.completeJournalEntry(companyId, entryId, accountId);
      // Перезагружаем записи, чтобы обновить статус
      // Или можно обновить локально
      state = JournalState(entries: state.entries);
      return true;
    } catch (e) {
      final appError = ErrorHandler.handleError(e);
      state = JournalState(entries: state.entries, error: appError.message);
      return false;
    }
  }
}