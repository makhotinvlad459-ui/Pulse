import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/api_client.dart';
import '../../../providers/production_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'production_journal_entry_dialog.dart';

class ProductionJournalTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  final VoidCallback onRefresh;

  const ProductionJournalTab({
    super.key,
    required this.companyId,
    required this.permissions,
    required this.onRefresh,
  });

  @override
  ConsumerState<ProductionJournalTab> createState() => _ProductionJournalTabState();
}

class _ProductionJournalTabState extends ConsumerState<ProductionJournalTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadEntries();
  }

  Future<void> _loadProducts() async {
    final api = ApiClient();
    try {
      final res = await api.get('/production/products', queryParameters: {'company_id': widget.companyId});
      if (mounted) setState(() => _products = res.data);
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _loadEntries() async {
    final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final notifier = ref.read(productionJournalProvider.notifier);
    await notifier.loadEntries(widget.companyId, start, end);
    if (mounted) setState(() {});
  }

  List<dynamic> get _selectedDayEntries {
    final entries = ref.read(productionJournalProvider);
    return entries.where((e) {
      final date = DateTime.parse(e['production_date']).toLocal();
      return date.year == _selectedDay.year &&
          date.month == _selectedDay.month &&
          date.day == _selectedDay.day;
    }).toList();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadEntries();
  }

  Future<void> _refresh() async {
    await _loadEntries();
  }

  Future<void> _createEntry() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ProductionJournalEntryDialog(
        companyId: widget.companyId,
        initialDate: _selectedDay,
        permissions: widget.permissions,
        products: _products,
      ),
    );
    if (result == true && mounted) {
      await _refresh();
      widget.onRefresh();
      if (mounted) setState(() {});
    }
  }

  String _getProductName(int productId) {
    final product = _products.firstWhere((p) => p['id'] == productId, orElse: () => null);
    return product?['name'] ?? 'Товар удалён';
  }

  Widget _buildEntryCard(Map<String, dynamic> entry, ColorScheme colorScheme, AppLocalizations t) {
    final productName = _getProductName(entry['product_id']);
    final quantity = entry['actual_quantity'] ?? entry['planned_quantity'];
    final creatorName = entry['creator_name'] ?? '';
    final displayCreatorName = creatorName == 'Основатель' ? t.founderRole : creatorName;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.factory, color: colorScheme.primary),
        title: Text(productName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.quantity}: $quantity шт'),
            if (displayCreatorName.isNotEmpty)
              Text('${t.createdByLabel}: $displayCreatorName'),
            Text('${t.shift}: ${entry['shift'] == 'day' ? t.dayShift : t.nightShift}'),
            if (entry['notes'] != null && entry['notes'].isNotEmpty)
              Text('${t.notes}: ${entry['notes']}'),
          ],
        ),
        trailing: widget.permissions.contains('delete_production')
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  final notifier = ref.read(productionJournalProvider.notifier);
                  await notifier.deleteEntry(widget.companyId, entry['id']);
                  await _refresh();
                  widget.onRefresh();
                  if (mounted) setState(() {});
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final canCreate = widget.permissions.contains('create_production');
    final entries = ref.watch(productionJournalProvider);
    final selectedEntries = _selectedDayEntries;

    final Map<DateTime, int> markers = {};
    for (var e in entries) {
      final date = DateTime.parse(e['production_date']).toLocal();
      final key = DateTime(date.year, date.month, date.day);
      markers[key] = (markers[key] ?? 0) + 1;
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TableCalendar(
              focusedDay: _focusedDay,
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              onPageChanged: _onPageChanged,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final cleanDate = DateTime(date.year, date.month, date.day);
                  final count = markers[cleanDate];
                  if (count != null && count > 0) {
                    return Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
              locale: Localizations.localeOf(context).languageCode,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy', Localizations.localeOf(context).languageCode).format(_selectedDay),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (canCreate)
                    FloatingActionButton.small(
                      onPressed: _createEntry,
                      child: const Icon(Icons.add),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (selectedEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    t.noProductionEntries,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...selectedEntries.map((entry) => _buildEntryCard(entry, colorScheme, t)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}