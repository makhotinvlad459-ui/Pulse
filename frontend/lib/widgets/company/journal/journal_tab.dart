import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/journal_entry.dart';
import '../../../providers/journal_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'journal_entry_dialog.dart';
import 'journal_complete_dialog.dart';

class JournalTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  final VoidCallback? onRefresh;

  const JournalTab({
    super.key,
    required this.companyId,
    required this.permissions,
    this.onRefresh,
  });

  @override
  ConsumerState<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends ConsumerState<JournalTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final Map<DateTime, List<JournalEntry>> _entriesMap = {};
  bool _loading = false;

  DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEntriesForMonth(_focusedDay);
    });
  }

  Future<void> _loadEntriesForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    setState(() => _loading = true);
    final notifier = ref.read(journalProvider.notifier);
    await notifier.loadEntries(widget.companyId, start, end);
    final state = ref.read(journalProvider);
    _buildEntriesMap(state.entries);
    setState(() => _loading = false);
  }

  void _buildEntriesMap(List<JournalEntry> entries) {
    _entriesMap.clear();
    for (var e in entries) {
      final date = _normalize(e.datetimeStart);
      _entriesMap[date] = (_entriesMap[date] ?? [])..add(e);
    }
    if (mounted) setState(() {});
  }

  List<JournalEntry> get _selectedDayEntries {
    final key = _normalize(_selectedDay);
    return _entriesMap[key] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadEntriesForMonth(focusedDay);
  }

  Future<void> _refresh() async {
    await _loadEntriesForMonth(_focusedDay);
  }

  Future<void> _createEntry() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => JournalEntryDialog(
        companyId: widget.companyId,
        initialDate: _selectedDay,
        permissions: widget.permissions,
      ),
    );
    if (result != null && mounted) {
      final notifier = ref.read(journalProvider.notifier);
      await notifier.createEntry(
        widget.companyId,
        start: result['start'],
        end: result['end'],
        description: result['description'],
        counterparty: result['counterparty'],
        items: result['items'],
        totalAmount: result['totalAmount'],
      );
      await _loadEntriesForMonth(_focusedDay);
    }
  }

  Future<void> _editEntry(JournalEntry entry) async {
    if (!widget.permissions.contains('edit_journal')) return;
    final entryMap = {
      'datetime_start': entry.datetimeStart.toIso8601String(),
      'datetime_end': entry.datetimeEnd.toIso8601String(),
      'description': entry.description ?? '',
      'counterparty': entry.counterparty ?? '',
      'items': entry.items?.map((item) => {
  'showcase_item_id': item['showcase_item_id'],
  'quantity': item['quantity'],
  'price_at_time': item['price_at_time'],
  'name': item['name'] ?? 'Без названия',
}).toList(),
      'total_amount': entry.totalAmount,
    };
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => JournalEntryDialog(
        companyId: widget.companyId,
        initialEntry: entryMap,
        permissions: widget.permissions,
      ),
    );
    if (result != null && mounted) {
      final notifier = ref.read(journalProvider.notifier);
      await notifier.updateEntry(
        widget.companyId,
        entry.id,
        start: result['start'],
        end: result['end'],
        description: result['description'],
        counterparty: result['counterparty'],
        items: result['items'],
        totalAmount: result['totalAmount'],
      );
      await _loadEntriesForMonth(_focusedDay);
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (!widget.permissions.contains('delete_journal')) return;
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteJournalEntryTitle),
        content: Text('${t.deleteJournalEntryConfirm} "${entry.description ?? t.journalEntry}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final notifier = ref.read(journalProvider.notifier);
      await notifier.deleteEntry(widget.companyId, entry.id);
      await _loadEntriesForMonth(_focusedDay);
    }
  }

  Future<void> _completeEntry(JournalEntry entry) async {
    if (!widget.permissions.contains('complete_journal')) return;
    final t = AppLocalizations.of(context)!;
    if (entry.status != 'planned') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.onlyPlannedCanBeCompleted)));
      return;
    }
    final accountId = await showDialog<int?>(
      context: context,
      builder: (context) => JournalCompleteDialog(companyId: widget.companyId),
    );
    if (accountId != null && mounted) {
      final notifier = ref.read(journalProvider.notifier);
      await notifier.completeEntry(widget.companyId, entry.id, accountId);
      widget.onRefresh?.call(); 
      await _loadEntriesForMonth(_focusedDay);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.entryCompleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final canCreate = widget.permissions.contains('create_journal');
    final selectedEntries = _selectedDayEntries;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
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
                  final normalized = _normalize(date);
                  final count = _entriesMap[normalized]?.length;
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (selectedEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    t.noEntriesForDay,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...selectedEntries.map((entry) => _buildEntryCard(entry, colorScheme, t)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry, ColorScheme colorScheme, AppLocalizations t) {
    final isCompleted = entry.status == 'completed';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.event,
          size: 24,
          color: isCompleted ? Colors.green : colorScheme.primary,
        ),
        title: Text(
          '${DateFormat.Hm().format(entry.datetimeStart.toLocal())} - ${DateFormat.Hm().format(entry.datetimeEnd.toLocal())}',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.description != null && entry.description!.isNotEmpty)
              Text(entry.description!, style: const TextStyle(fontSize: 12)),
            if (entry.counterparty != null && entry.counterparty!.isNotEmpty)
              Text('${t.counterpartyLabel}: ${entry.counterparty}', style: const TextStyle(fontSize: 11)),
            if (entry.items != null && entry.items!.isNotEmpty)
              Column(
                children: entry.items!.map((item) {
                  final name = item['name'] ?? 'Без названия';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• $name x${item['quantity']} (${item['price_at_time']} ${t.currencySymbol}) = ${(item['quantity'] * item['price_at_time']).toStringAsFixed(2)} ${t.currencySymbol}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            if (entry.showcaseItemName != null && (entry.items == null || entry.items!.isEmpty))
              Text('${t.serviceLabel}: ${entry.showcaseItemName} x${entry.quantity}', style: const TextStyle(fontSize: 11)),
            if (entry.totalAmount > 0)
              Text('${t.sumLabel}: ${entry.totalAmount.toStringAsFixed(2)} ${t.currencySymbol}', style: const TextStyle(fontSize: 11)),
            if (isCompleted && entry.transactionId != null)
              Text('${t.transactionLabel}: #${entry.transactionId}', style: TextStyle(fontSize: 10, color: Colors.green)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompleted && widget.permissions.contains('complete_journal'))
              IconButton(
                icon: const Icon(Icons.done_all, size: 20),
                onPressed: () => _completeEntry(entry),
                tooltip: t.complete,
              ),
            if (widget.permissions.contains('edit_journal') && !isCompleted)
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _editEntry(entry),
                tooltip: t.edit,
              ),
            if (widget.permissions.contains('delete_journal'))
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () => _deleteEntry(entry),
                tooltip: t.delete,
              ),
          ],
        ),
      ),
    );
  }
}