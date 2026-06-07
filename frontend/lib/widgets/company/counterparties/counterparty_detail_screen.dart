import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart' as excelLib;
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import '../../../services/file_download_helper.dart';
import '../../../providers/locale_provider.dart';
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
      if (file.bytes == null) {
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
            decoration: InputDecoration(hintText: t.documentDescriptionHint),
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
        final compressed = await ImageCompression.compressImage(file.bytes!);
        await _api.uploadCounterpartyDocument(
          counterpartyId: widget.counterparty['id'],
          companyId: widget.companyId,
          bytes: compressed,
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
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      child: Image.memory(bytes),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t.close),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        await FileDownloadHelper.downloadFile(bytes, fileName);
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

  Future<void> _exportTransactions() async {
    if (_transactions.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    final excelFile = excelLib.Excel.createExcel();
    final sheet = excelFile.sheets.values.first;
    sheet.appendRow([t.dateLabel, t.transactionNumber, t.typeLabel, t.amountLabel, t.categoryLabel, t.accountLabel, t.descriptionLabel, t.counterpartyLabel, t.createdByLabel]);
    for (var tx in _transactions) {
      sheet.appendRow([
        DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date'])),
        tx['number'],
        tx['type'] == 'income' ? t.income : t.expense,
        tx['amount'],
        tx['category_name'] ?? '',
        tx['account_name'] ?? '',
        tx['description'] ?? '',
        tx['counterparty'] ?? '',
        tx['creator_name'] ?? '',
      ]);
    }
    final bytes = excelFile.encode();
    if (bytes != null) {
      await FileDownloadHelper.downloadFile(Uint8List.fromList(bytes), 'counterparty_transactions_${widget.counterparty['name']}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    }
  }

  Future<void> _exportJournal() async {
    if (_journalEntries.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    final excelFile = excelLib.Excel.createExcel();
    final sheet = excelFile.sheets.values.first;
    sheet.appendRow([t.dateLabel, t.startTime, t.endTime, t.description, t.counterpartyLabel, t.totalAmount]);
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
      await FileDownloadHelper.downloadFile(Uint8List.fromList(bytes), 'counterparty_visits_${widget.counterparty['name']}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
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
            Tab(text: t.operationsTab),
            Tab(text: t.visitsTab),
            Tab(text: t.documentsTab),
          ],
        ),
        actions: [
          if (_tabController.index == 0 && _transactions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportTransactions,
              tooltip: t.exportToExcel,
            ),
          if (_tabController.index == 1 && _journalEntries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportJournal,
              tooltip: t.exportToExcel,
            ),
          if (_tabController.index == 2)
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
          // Операции
          _loadingTransactions
              ? const Center(child: CircularProgressIndicator())
              : _transactions.isEmpty
                  ? Center(child: Text(t.noTransactions))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text('${tx['type'] == 'income' ? t.income : t.expense} - ${tx['amount']} ${t.currencySymbol}'),
                            subtitle: Text('${DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']))} • ${tx['description'] ?? ''}'),
                            trailing: Text(tx['category_name'] ?? ''),
                          ),
                        );
                      },
                    ),
          // Посещения (журнал)
          _loadingJournal
              ? const Center(child: CircularProgressIndicator())
              : _journalEntries.isEmpty
                  ? Center(child: Text(t.noVisits))
                  : ListView.builder(
                      itemCount: _journalEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _journalEntries[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            title: Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(entry['datetime_start']))),
                            subtitle: Text(entry['description'] ?? ''),
                            trailing: Text('${entry['total_amount']} ${t.currencySymbol}'),
                          ),
                        );
                      },
                    ),
          // Документы
          _loadingDocuments
              ? const Center(child: CircularProgressIndicator())
              : _documents.isEmpty
                  ? Center(child: Text(t.noDocuments))
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
    );
  }
}