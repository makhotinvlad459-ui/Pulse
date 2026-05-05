import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../providers/locale_provider.dart';
import '../models/transaction.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ArchiveScreen extends ConsumerStatefulWidget {
  final int companyId;
  final int archiveAccountId;
  const ArchiveScreen(
      {super.key, required this.companyId, required this.archiveAccountId});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
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
      final response = await api.get('/transactions', queryParameters: {
        'company_id': widget.companyId,
        'include_deleted': 'false',
      });
      final List<dynamic> data = response.data;
      final allTransactions =
          data.map((json) => Transaction.fromJson(json)).toList();
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

  String _typeName(String type, AppLocalizations t) {
    switch (type) {
      case 'income': return t.income;
      case 'expense': return t.expense;
      case 'transfer': return t.transfer;
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.archiveTitle),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('${t.error}: $_error'))
              : _transactions.isEmpty
                  ? Center(child: Text(t.archiveEmpty))
                  : ListView.builder(
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            title: Text('${tx.amount} ₽',
                                style: TextStyle(
                                    color: tx.type == 'income'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_typeName(tx.type, t)} • ${tx.description ?? ''}'),
                                if (tx.creatorName != null)
                                  Text('${t.createdBy}: ${tx.creatorName}',
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            trailing: Text(
                              DateFormat('dd.MM.yyyy HH:mm')
                                  .format(tx.date.toLocal()),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}