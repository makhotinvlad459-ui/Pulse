import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import '../../services/api_client.dart';
import '../../models/transaction.dart';
import 'edit_transaction_dialog.dart';
import 'add_transaction_dialog.dart'; // добавлен импорт

class TransactionsTab extends StatefulWidget {
  final int companyId;
  final Future<void> Function() onRefresh;
  final List<dynamic> accounts;
  final List<dynamic> categories;
  final bool isFounder;
  const TransactionsTab({
    super.key,
    required this.companyId,
    required this.onRefresh,
    required this.accounts,
    required this.categories,
    required this.isFounder,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  List<Transaction> _transactions = [];
  bool _loading = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0)
      .add(const Duration(days: 1))
      .subtract(const Duration(seconds: 1));

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/transactions', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'include_deleted': 'true',
      });
      final List<dynamic> data = res.data;
      setState(() {
        _transactions = data.map((json) => Transaction.fromJson(json)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  Future<void> _selectPeriod() async {
    final now = DateTime.now();
    DateTime endDate = _endDate.isAfter(now) ? now : _endDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: endDate),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      });
      await _loadTransactions();
      setState(() {});
    }
  }

  String _typeName(String type) {
    if (type == 'income') return 'Доход';
    if (type == 'expense') return 'Расход';
    if (type == 'transfer') return 'Перевод';
    return type;
  }

  String getAccountName(int? id) {
    if (id == null) return '';
    try {
      final acc = widget.accounts
          .cast<Map<String, dynamic>>()
          .firstWhere((a) => a['id'] == id);
      String icon =
          acc['type'] == 'cash' ? '💵' : (acc['type'] == 'bank' ? '🏦' : '📁');
      return '$icon ${acc['name']}';
    } catch (e) {
      return '';
    }
  }

  String getCategoryName(int? id) {
    if (id == null) return 'Без категории';
    try {
      final cat = widget.categories
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == id);
      return '${cat['icon'] ?? '📁'} ${cat['name']}';
    } catch (e) {
      return 'Без категории';
    }
  }

  Future<void> _restoreTransaction(int id) async {
    final api = ApiClient();
    try {
      await api.post('/transactions/$id/restore',
          queryParameters: {'company_id': widget.companyId});
      await _loadTransactions();
      await widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Операция восстановлена')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка восстановления: $e')));
    }
  }

  Future<void> _permanentDeleteTransaction(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить операцию навсегда?'),
        content: const Text(
            'Операция будет удалена без возможности восстановления.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/transactions/$id',
          queryParameters: {'company_id': widget.companyId});
      await widget.onRefresh();
      await _loadTransactions();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Операция удалена')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final Map<String, dynamic> map = {
      'id': transaction.id,
      'type': transaction.type,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'account_id': transaction.accountId,
      'category_id': transaction.categoryId,
      'description': transaction.description,
      'attachment_url': transaction.attachmentUrl,
      'transfer_to_account_id': transaction.transferToAccountId,
    };
    await showDialog(
      context: context,
      builder: (context) => EditTransactionDialog(
        transaction: map,
        companyId: widget.companyId,
        accounts: widget.accounts,
        categories: widget.categories,
        onSuccess: () async {
          await _loadTransactions();
          await widget.onRefresh();
        },
        isFounder: widget.isFounder,
      ),
    );
  }

  Future<void> _downloadFile(String url, String filename) async {
    final api = ApiClient();
    try {
      final response = await api
          .getFile(url, queryParameters: {'company_id': widget.companyId});
      final bytes = response.data as List<int>;
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);
        final downloadLink = html.AnchorElement(href: objectUrl)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(objectUrl);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Сохранено: ${file.path}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка скачивания: $e')));
    }
  }

  Future<void> _showAttachment(String? url, int transactionId) async {
    if (url == null) return;
    final api = ApiClient();
    try {
      final response = await api.getFile('/transactions/$transactionId/photo',
          queryParameters: {'company_id': widget.companyId});
      final bytes = response.data as List<int>;
      final uint8list = Uint8List.fromList(bytes);
      final ext = url.split('.').last.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Фото',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Image.memory(uint8list),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть')),
              ],
            ),
          ),
        );
      } else if (ext == 'pdf') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('PDF файл'),
            content: const Text('Файл в формате PDF. Скачать?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Скачать')),
            ],
          ),
        );
        if (confirm == true) {
          final filename = url.split('/').last;
          await _downloadFile('/transactions/$transactionId/photo', filename);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Невозможно отобразить файл')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки файла: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<DateTime, List<Transaction>> grouped = {};
    for (var t in _transactions) {
      DateTime date = t.date.toLocal();
      DateTime key = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    var sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectPeriod,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                        '${DateFormat('dd.MM.yyyy', 'ru').format(_startDate)} - ${DateFormat('dd.MM.yyyy', 'ru').format(_endDate)}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTransactions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? const Center(
                          child: Text('Нет операций за выбранный период'))
                      : RefreshIndicator(
                          onRefresh: _loadTransactions,
                          child: ListView.builder(
                            itemCount: sortedDates.length,
                            itemBuilder: (context, index) {
                              final date = sortedDates[index];
                              final dayTransactions = grouped[date]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    child: Text(
                                      DateFormat('EEEE, d MMMM yyyy', 'ru')
                                          .format(date),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                  ...dayTransactions.map((t) {
                                    final isDeleted = t.isDeleted;
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      color: isDeleted
                                          ? Colors.grey.shade200
                                          : Colors.white,
                                      child: ListTile(
                                        title: Text(
                                          '${t.amount} ₽',
                                          style: TextStyle(
                                            color: t.type == 'income'
                                                ? (isDeleted
                                                    ? Colors.grey
                                                    : Colors.green)
                                                : (isDeleted
                                                    ? Colors.grey
                                                    : Colors.red),
                                            decoration: isDeleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_typeName(t.type)} • ${getCategoryName(t.categoryId)} • ${getAccountName(t.accountId)} • ${t.description ?? ''}',
                                              style: TextStyle(
                                                  color: isDeleted
                                                      ? Colors.grey
                                                      : Colors.black87,
                                                  fontSize: 12),
                                            ),
                                            if (t.creatorName != null)
                                              Text(
                                                'Создал: ${t.creatorName}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDeleted
                                                        ? Colors.grey
                                                        : Colors.grey.shade600),
                                              ),
                                            if (t.updaterName != null &&
                                                t.updaterName != t.creatorName)
                                              Text(
                                                'Изменил: ${t.updaterName}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDeleted
                                                        ? Colors.grey
                                                        : Colors.grey.shade600),
                                              ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (t.attachmentUrl != null)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.attach_file,
                                                    size: 18,
                                                    color: Colors.blue),
                                                onPressed: () =>
                                                    _showAttachment(
                                                        t.attachmentUrl, t.id),
                                                tooltip: 'Просмотреть вложение',
                                              ),
                                            if (isDeleted)
                                              IconButton(
                                                icon: const Icon(Icons.restore,
                                                    color: Colors.orange),
                                                onPressed: () =>
                                                    _restoreTransaction(t.id),
                                                tooltip: 'Восстановить',
                                              ),
                                            if (widget.isFounder && isDeleted)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_forever,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _permanentDeleteTransaction(
                                                        t.id),
                                                tooltip: 'Удалить навсегда',
                                              ),
                                            Text(
                                              DateFormat('HH:mm', 'ru')
                                                  .format(t.date.toLocal()),
                                              style: TextStyle(
                                                  color: isDeleted
                                                      ? Colors.grey
                                                      : Colors.black54),
                                            ),
                                          ],
                                        ),
                                        onTap: isDeleted
                                            ? null
                                            : () => _editTransaction(t),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
        // FAB для добавления операции
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => AddTransactionDialog(
                  companyId: widget.companyId,
                  onSuccess: () async {
                    await _loadTransactions(); // обновляем список
                    await widget.onRefresh(); // обновляем счета/категории
                  },
                  accounts: widget.accounts,
                  categories: widget.categories,
                ),
              );
            },
            backgroundColor: Colors.blueGrey.shade300,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
