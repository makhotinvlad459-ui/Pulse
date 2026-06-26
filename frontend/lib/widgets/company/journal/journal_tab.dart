import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/journal_entry.dart';
import '../../../providers/journal_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'journal_entry_dialog.dart';
import 'journal_complete_dialog.dart';
import '../../../services/api_client.dart';
import '../../../services/file_download_helper.dart';

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
  final ApiClient _apiClient = ApiClient();
  
  bool _isDisposed = false;
  
  // Для фильтра по сотрудникам
  List<Map<String, dynamic>> _companyMembers = [];
  int? _selectedMemberId;
  bool _loadingMembers = false;

  DateTime _normalize(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _loadCompanyMembers();
        _loadEntriesForMonth(_focusedDay);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadCompanyMembers() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loadingMembers = true);
    final api = ApiClient();
    try {
      final res = await api.get('/orders/company/${widget.companyId}/members');
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() {
  final t = AppLocalizations.of(context)!;
  _companyMembers = List<Map<String, dynamic>>.from(res.data).map((member) {
    final name = member['full_name'] ?? '';
    final role = member['role'];
    // Если это основатель — заменяем на локализованное имя
    if (role == 'founder' || name == 'Основатель') {
      member['full_name'] = t.founderRole;
    }
    return member;
  }).toList();
  _loadingMembers = false;
});
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadEntriesForMonth(DateTime month) async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    setState(() => _loading = true);
    final notifier = ref.read(journalProvider.notifier);
    
    await notifier.loadEntries(
      widget.companyId, 
      start, 
      end,
      assignedToId: _selectedMemberId,
    );
    
    if (_isDisposed) return;
    if (!mounted) return;
    
    final state = ref.read(journalProvider);
    _buildEntriesMap(state.entries);
    setState(() => _loading = false);
  }

  void _buildEntriesMap(List<JournalEntry> entries) {
    if (_isDisposed) return;
    
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
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    if (_isDisposed) return;
    
    _focusedDay = focusedDay;
    _loadEntriesForMonth(focusedDay);
  }

  void _onFilterChanged(int? memberId) {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() {
      _selectedMemberId = memberId;
    });
    _loadEntriesForMonth(_focusedDay);
  }

  Future<void> _refresh() async {
    if (_isDisposed) return;
    await _loadEntriesForMonth(_focusedDay);
  }

  Future<void> _createEntry() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => JournalEntryDialog(
        companyId: widget.companyId,
        initialDate: _selectedDay,
        permissions: widget.permissions,
        members: _companyMembers,
      ),
    );
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (result == true) {
      await _loadEntriesForMonth(_focusedDay);
    }
  }

  Future<void> _editEntry(JournalEntry entry) async {
    if (_isDisposed) return;
    if (!mounted) return;
    if (!widget.permissions.contains('edit_journal')) return;
    
    final entryMap = {
      'id': entry.id,
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
      'assigned_to_id': entry.assignedToId,
    };
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => JournalEntryDialog(
        companyId: widget.companyId,
        initialEntry: entryMap,
        permissions: widget.permissions,
        members: _companyMembers,
      ),
    );
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (result == true) {
      await _loadEntriesForMonth(_focusedDay);
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (_isDisposed) return;
    if (!mounted) return;
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
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (confirm == true) {
      final notifier = ref.read(journalProvider.notifier);
      await notifier.deleteEntry(widget.companyId, entry.id);
      await _loadEntriesForMonth(_focusedDay);
    }
  }

  Future<void> _completeEntry(JournalEntry entry) async {
    if (_isDisposed) return;
    if (!mounted) return;
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
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (accountId != null) {
      final notifier = ref.read(journalProvider.notifier);
      await notifier.completeEntry(widget.companyId, entry.id, accountId);
      widget.onRefresh?.call();
      await _loadEntriesForMonth(_focusedDay);
      if (_isDisposed) return;
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.entryCompleted)));
    }
  }

  Future<void> _viewAttachment(int attachmentId, String fileName) async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    final t = AppLocalizations.of(context)!;
    final ext = fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
    try {
      final response = await _apiClient.getJournalAttachmentFile(attachmentId, widget.companyId);
      if (_isDisposed) return;
      if (!mounted) return;
      
      final bytes = response.data is List<int>
          ? Uint8List.fromList(response.data as List<int>)
          : Uint8List.fromList((response.data as String).codeUnits);
      if (isImage) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              elevation: 0,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      child: Image.memory(bytes),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () {
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white, size: 30),
                      onPressed: () async {
                        await FileDownloadHelper.downloadFile(bytes, fileName, context: context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        await FileDownloadHelper.downloadFile(bytes, fileName, context: context);
        if (_isDisposed) return;
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fileSaved)));
      }
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _deleteAttachment(JournalEntry entry, int attachmentId) async {
    if (_isDisposed) return;
    if (!mounted) return;
    if (!widget.permissions.contains('edit_journal')) return;
    
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteFileTitle),
        content: Text(t.deleteFileContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (confirm == true) {
      try {
        await _apiClient.deleteJournalAttachment(attachmentId, widget.companyId);
        await _loadEntriesForMonth(_focusedDay);
      } catch (e) {
        if (_isDisposed) return;
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  String _getFileExtension(String filename) {
    final parts = filename.split('.');
    if (parts.length < 2) return '';
    return parts.last.toLowerCase();
  }

  Icon _getFileIcon(String filename) {
    final ext = _getFileExtension(filename);
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return const Icon(Icons.image, size: 16);
    } else if (ext == 'pdf') {
      return const Icon(Icons.picture_as_pdf, size: 16);
    } else if (['doc', 'docx'].contains(ext)) {
      return const Icon(Icons.description, size: 16);
    } else if (['xls', 'xlsx'].contains(ext)) {
      return const Icon(Icons.table_chart, size: 16);
    } else if (ext == 'txt') {
      return const Icon(Icons.text_fields, size: 16);
    }
    return const Icon(Icons.insert_drive_file, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final canCreate = widget.permissions.contains('create_journal');
    final selectedEntries = _selectedDayEntries;
    final showFilter = _companyMembers.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Фильтр по сотрудникам
            if (showFilter)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        decoration: InputDecoration(
                          labelText: t.filterByEmployee,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: _selectedMemberId,
                        hint: Text(t.allEmployees),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(t.allEmployees),
                          ),
                          ..._companyMembers.map((member) {
                            final name = member['full_name'] ?? 'Без имени';
                            return DropdownMenuItem<int?>(
                              value: member['id'],
                              child: Text(name),
                            );
                          }),
                        ],
                        onChanged: _onFilterChanged,
                      ),
                    ),
                    if (_selectedMemberId != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _onFilterChanged(null),
                        tooltip: t.clearFilter,
                      ),
                  ],
                ),
              ),
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
    final attachments = entry.attachments ?? [];
    
    // ✅ ЛОКАЛИЗАЦИЯ ДЛЯ ОСНОВАТЕЛЯ
    String assignedName = entry.assignedToName ?? '';
    if (assignedName == 'Основатель') {
      assignedName = t.founderRole;
    }
    
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
            // 👇 ПОКАЗЫВАЕМ НАЗНАЧЕННОГО СОТРУДНИКА С ЛОКАЛИЗАЦИЕЙ
            if (assignedName.isNotEmpty)
              Text('👤 ${t.assignedTo}: $assignedName', style: const TextStyle(fontSize: 11)),
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
              Text('${t.transactionLabel}: #${entry.transactionId}', style: const TextStyle(fontSize: 10, color: Colors.green)),
            if (attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: attachments.map((att) {
                    final fileName = att['file_name'] ?? 'file';
                    return GestureDetector(
                      onTap: () => _viewAttachment(att['id'], fileName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _getFileIcon(fileName),
                            const SizedBox(width: 4),
                            Text(
                              fileName.length > 20 ? '${fileName.substring(0, 17)}...' : fileName,
                              style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
                            ),
                            if (widget.permissions.contains('edit_journal') && !isCompleted)
                              GestureDetector(
                                onTap: () => _deleteAttachment(entry, att['id']),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.close, size: 12, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
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