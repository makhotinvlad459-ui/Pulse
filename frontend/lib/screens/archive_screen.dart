import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../models/transaction.dart';

class ArchiveScreen extends StatefulWidget {
  final int companyId;
  final int archiveAccountId;
  const ArchiveScreen(
      {super.key, required this.companyId, required this.archiveAccountId});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Transaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArchiveTransactions();
  }

  Future<void> _loadArchiveTransactions() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      // Загружаем все операции компании (без фильтра по дате)
      final response = await api.get('/transactions', queryParameters: {
        'company_id': widget.companyId,
        'include_deleted': 'false',
      });
      final List<dynamic> data = response.data;
      final allTransactions =
          data.map((json) => Transaction.fromJson(json)).toList();
      // Фильтруем: либо account_id, либо transfer_to_account_id равны архивному счёту
      final filtered = allTransactions
          .where((t) =>
              t.accountId == widget.archiveAccountId ||
              t.transferToAccountId == widget.archiveAccountId)
          .toList();
      setState(() {
        _transactions = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _typeName(String type) {
    if (type == 'income') return 'Доход';
    if (type == 'expense') return 'Расход';
    if (type == 'transfer') return 'Перевод';
    return type;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Архив операций'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Ошибка: $_error'))
              : _transactions.isEmpty
                  ? const Center(child: Text('Архив пуст'))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            title: Text('${t.amount} ₽',
                                style: TextStyle(
                                    color: t.type == 'income'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${_typeName(t.type)} • ${t.description ?? ''}'),
                                if (t.creatorName != null)
                                  Text('Создал: ${t.creatorName}',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            trailing: Text(
                              DateFormat('dd.MM.yyyy HH:mm')
                                  .format(t.date.toLocal()),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
