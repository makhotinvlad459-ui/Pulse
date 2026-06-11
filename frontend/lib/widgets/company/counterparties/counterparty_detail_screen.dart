import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import '../../../services/file_download_helper.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/user.dart';
import '../../../l10n/app_localizations.dart';

class CounterpartyDetailScreen extends ConsumerStatefulWidget {
  final int companyId;
  final Map<String, dynamic> counterparty;
  final Set<String> permissions;

  const CounterpartyDetailScreen({
    super.key,
    required this.companyId,
    required this.counterparty,
    required this.permissions,
  });

  @override
  ConsumerState<CounterpartyDetailScreen> createState() => _CounterpartyDetailScreenState();
}

class _CounterpartyDetailScreenState extends ConsumerState<CounterpartyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _documents = [];
  List<dynamic> _transactions = [];
  List<dynamic> _journalEntries = [];
  bool _loadingTransactions = true;
  bool _loadingJournal = true;
  bool _loadingDocuments = true;
  bool _uploading = false;

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTransactions();
    _loadJournalEntries();
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get _totalIncome {
    return _transactions.fold(0.0, (sum, tx) => sum + (tx['type'] == 'income' ? (tx['amount'] as double) : 0.0));
  }

  double get _totalExpense {
    return _transactions.fold(0.0, (sum, tx) => sum + (tx['type'] == 'expense' ? (tx['amount'] as double) : 0.0));
  }

  bool get _canManage => ref.read(authProvider).user?.role == UserRole.founder ||
      widget.permissions.contains('manage_counterparties');

  Future<void> _loadTransactions() async {
    setState(() => _loadingTransactions = true);
    try {
      final stats = await _api.get('/statistics/counterparty-stats', queryParameters: {
        'company_id': widget.companyId,
        'counterparty': widget.counterparty['name'],
      });
      setState(() {
        _transactions = stats.data['transactions'] ?? [];
        _loadingTransactions = false;
      });
    } catch (e) {
      setState(() => _loadingTransactions = false);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _loadJournalEntries() async {
    setState(() => _loadingJournal = true);
    try {
      final entries = await _api.getCounterpartyJournalEntries(widget.counterparty['id'], widget.companyId);
      setState(() {
        _journalEntries = entries;
        _loadingJournal = false;
      });
    } catch (e) {
      setState(() => _loadingJournal = false);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _loadingDocuments = true);
    try {
      final docs = await _api.getCounterpartyDocuments(widget.counterparty['id'], widget.companyId);
      setState(() {
        _documents = List<Map<String, dynamic>>.from(docs);
        _loadingDocuments = false;
      });
    } catch (e) {
      setState(() => _loadingDocuments = false);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _pickAndUploadDocument() async {
  final t = AppLocalizations.of(context)!;
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
  );
  if (result != null && mounted) {
    final file = result.files.first;
    Uint8List? fileBytes;
    if (file.bytes != null) {
      fileBytes = file.bytes;
    } else if (!kIsWeb && file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    }
    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fileReadError)));
      return;
    }
    String? description;
    final descController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.documentDescription),
        content: TextField(
          controller: descController,
          decoration: InputDecoration(hintText: t.optional),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.upload),
          ),
        ],
      ),
    );
    description = descController.text.trim().isEmpty ? null : descController.text;
    setState(() => _uploading = true);
    try {
      final ext = file.name.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
      final bytesToUpload = isImage ? await ImageCompression.compressImage(fileBytes) : fileBytes;
      await _api.uploadCounterpartyDocument(
        counterpartyId: widget.counterparty['id'],
        companyId: widget.companyId,
        bytes: bytesToUpload,
        filename: file.name,
        description: description,
      );
      await _loadDocuments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

  Future<void> _viewDocument(Map<String, dynamic> doc) async {
  final t = AppLocalizations.of(context)!;
  final fileName = doc['file_name'];
  final ext = fileName.split('.').last.toLowerCase();
  final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  try {
    final response = await _api.getCounterpartyDocumentFile(doc['id'], widget.companyId);
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
                    onPressed: () => Navigator.pop(context),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fileSaved)));
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }
}

  Future<void> _deleteDocument(int docId) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteDocumentTitle),
        content: Text(t.deleteDocumentContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteCounterpartyDocument(docId, widget.companyId);
      await _loadDocuments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _exportCurrentTab() async {
    final t = AppLocalizations.of(context)!;
    final currentIndex = _tabController.index;
    if (currentIndex == 0) {
      if (_transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.noTransactionsToExport)));
        return;
      }
      await _exportTransactions();
    } else if (currentIndex == 1) {
      if (_journalEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.noVisitsToExport)));
        return;
      }
      await _exportJournal();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.exportNotAvailable)));
    }
  }

  Future<void> _exportTransactions() async {
    final t = AppLocalizations.of(context)!;
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile.sheets.values.first;
    sheet.appendRow([
      t.dateLabel,
      t.transactionNumber,
      t.typeLabel,
      t.income,
      t.expense,
      t.descriptionLabel,
    ]);
    for (var tx in _transactions) {
      final amount = tx['amount'] as double;
      final isIncome = tx['type'] == 'income';
      sheet.appendRow([
        DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date'])),
        tx['number'] ?? '—',
        isIncome ? t.incomeSale : t.expensePurchase,
        isIncome ? amount : 0,
        !isIncome ? amount : 0,
        tx['description'] ?? '',
      ]);
    }
    final bytes = excelFile.encode();
    if (bytes != null) {
      await FileDownloadHelper.downloadFile(
        Uint8List.fromList(bytes),
        'counterparty_transactions_${widget.counterparty['name']}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        context: context,
      );
    }
  }

  Future<void> _exportJournal() async {
    final t = AppLocalizations.of(context)!;
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile.sheets.values.first;
    sheet.appendRow([
      t.dateLabel,
      t.startTime,
      t.endTime,
      t.description,
      t.counterpartyLabel,
      t.totalAmount,
    ]);
    for (var entry in _journalEntries) {
      sheet.appendRow([
        DateFormat('dd.MM.yyyy').format(DateTime.parse(entry['datetime_start'])),
        DateFormat('HH:mm').format(DateTime.parse(entry['datetime_start'])),
        DateFormat('HH:mm').format(DateTime.parse(entry['datetime_end'])),
        entry['description'] ?? '',
        entry['counterparty'] ?? '',
        entry['total_amount'],
      ]);
    }
    final bytes = excelFile.encode();
    if (bytes != null) {
      await FileDownloadHelper.downloadFile(
        Uint8List.fromList(bytes),
        'counterparty_visits_${widget.counterparty['name']}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        context: context,
      );
    }
  }

  Future<void> _viewJournalAttachment(int attachmentId, String fileName) async {
  final t = AppLocalizations.of(context)!;
  try {
    final response = await _api.getJournalAttachmentFile(attachmentId, widget.companyId);
    final bytes = response.data is List<int>
        ? Uint8List.fromList(response.data as List<int>)
        : Uint8List.fromList((response.data as String).codeUnits);
    final ext = fileName.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
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
                    onPressed: () => Navigator.pop(context),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fileSaved)));
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }
}

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.counterparty['name']),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t.operations),
            Tab(text: t.visits),
            Tab(text: t.documents),
          ],
        ),
        actions: [
          // Экспорт в Excel (всегда)
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCurrentTab,
            tooltip: t.exportToExcel,
          ),
          // Кнопка добавления документа (всегда)
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _pickAndUploadDocument,
            tooltip: t.addDocument,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ========== ОПЕРАЦИИ ==========
          _loadingTransactions
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? Center(child: Text(t.noTransactions))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 12,
                              columns: [
                                DataColumn(label: Text(t.dateLabel)),
                                DataColumn(label: Text(t.transactionNumber)),
                                DataColumn(label: Text(t.typeLabel)),
                                DataColumn(label: Text(t.income)),
                                DataColumn(label: Text(t.expense)),
                                DataColumn(label: Text(t.descriptionLabel)),
                              ],
                              rows: _transactions.map((tx) {
                                final amount = tx['amount'] as double;
                                final isIncome = tx['type'] == 'income';
                                return DataRow(cells: [
                                  DataCell(Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date'])))),
                                  DataCell(Text(tx['number']?.toString() ?? '—')),
                                  DataCell(Text(isIncome ? t.incomeSale : t.expensePurchase)),
                                  DataCell(Text(isIncome ? '$amount ${t.currencySymbol}' : '—')),
                                  DataCell(Text(!isIncome ? '$amount ${t.currencySymbol}' : '—')),
                                  DataCell(Text(tx['description'] ?? '')),
                                ]);
                              }).toList(),
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t.totalIncome, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${_totalIncome.toStringAsFixed(2)} ${t.currencySymbol}', style: const TextStyle(color: Colors.green)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t.totalExpense, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${_totalExpense.toStringAsFixed(2)} ${t.currencySymbol}', style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(t.balance, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${(_totalIncome - _totalExpense).toStringAsFixed(2)} ${t.currencySymbol}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (_totalIncome - _totalExpense) >= 0 ? Colors.green : Colors.red,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

          // ========== ПОСЕЩЕНИЯ (ЖУРНАЛ) ==========
          _loadingJournal
              ? const Center(child: CircularProgressIndicator())
              : _journalEntries.isEmpty
                  ? Center(child: Text(t.noVisits))
                  : ListView.builder(
                      itemCount: _journalEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _journalEntries[index];
                        final attachments = entry['attachments'] as List? ?? [];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(entry['datetime_start']))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (entry['description'] != null && entry['description'].isNotEmpty)
                                  Text(entry['description']),
                                const SizedBox(height: 4),
                                if (attachments.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: attachments.map((att) {
                                      final fileName = att['file_name'] ?? 'file';
                                      return GestureDetector(
                                        onTap: () => _viewJournalAttachment(att['id'], fileName),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.attachment, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                fileName.length > 20 ? '${fileName.substring(0, 17)}...' : fileName,
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                            trailing: Text('${entry['total_amount']} ${t.currencySymbol}'),
                          ),
                        );
                      },
                    ),

          // ========== ДОКУМЕНТЫ ==========
          _loadingDocuments
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t.noDocuments, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickAndUploadDocument,
                            icon: const Icon(Icons.upload_file),
                            label: Text(t.addDocument),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _documents.length,
                      itemBuilder: (context, index) {
                        final doc = _documents[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file),
                            title: Text(doc['file_name']),
                            subtitle: doc['description'] != null ? Text(doc['description']) : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () => _viewDocument(doc),
                                ),
                                if (_canManage)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteDocument(doc['id']),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _pickAndUploadDocument,
        child: _uploading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add),
      ),
    );
  }
}