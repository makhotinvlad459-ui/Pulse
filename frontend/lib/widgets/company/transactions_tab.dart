import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:photo_view/photo_view.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import '../../models/transaction.dart';
import 'edit_transaction_dialog.dart';
import 'add_transaction_dialog.dart';
import 'package:frontend/l10n/app_localizations.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  final int companyId;
  final Future<void> Function() onRefresh;
  final List<dynamic> accounts;
  final List<dynamic> categories;
  final bool isFounder;
  final Set<String> permissions;

  const TransactionsTab({
    super.key,
    required this.companyId,
    required this.onRefresh,
    required this.accounts,
    required this.categories,
    required this.isFounder,
    required this.permissions,
  });

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
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
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _selectPeriod() async {
    final t = AppLocalizations.of(context)!;
    final now = DateTime.now();
    DateTime endDate = _endDate.isAfter(now) ? now : _endDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: endDate),
      locale: Locale('ru'), // можно заменить на текущую локаль, но оставим для удобства
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      });
      await _loadTransactions();
    }
  }

  String _typeName(String type, AppLocalizations t) {
    if (type == 'income') return t.incomeSale;
    if (type == 'expense') return t.expensePurchase;
    if (type == 'transfer') return t.transfer;
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

  String getCategoryName(int? id, AppLocalizations t) {
    if (id == null) return t.withoutCategory;
    try {
      final cat = widget.categories
          .cast<Map<String, dynamic>>()
          .firstWhere((c) => c['id'] == id);
      return '${cat['icon'] ?? '📁'} ${cat['name']}';
    } catch (e) {
      return t.withoutCategory;
    }
  }

  Future<void> _restoreTransaction(int id) async {
    final t = AppLocalizations.of(context)!;
    final api = ApiClient();
    try {
      await api.post('/transactions/$id/restore',
          queryParameters: {'company_id': widget.companyId});
      await _loadTransactions();
      await widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.transactionRestored)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _permanentDeleteTransaction(int id) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.permanentDeleteTitle),
        content: Text(t.permanentDeleteContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.delete, style: const TextStyle(color: Colors.red))),
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
          .showSnackBar(SnackBar(content: Text(t.transactionDeleted)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    final t = AppLocalizations.of(context)!;
    if (!widget.isFounder && !widget.permissions.contains('edit_transaction')) return;
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
      'counterparty': transaction.counterparty,
      'items': transaction.items.map((i) => {
        'product_id': i.productId,
        'product_name': i.productName,
        'quantity': i.quantity,
        'price_per_unit': i.pricePerUnit,
      }).toList(),
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
    final t = AppLocalizations.of(context)!;
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
            .showSnackBar(SnackBar(content: Text('${t.savedTo}: ${file.path}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _showAttachment(String? url, int transactionId) async {
    final t = AppLocalizations.of(context)!;
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
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(t.photo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: PhotoView(
                      imageProvider: MemoryImage(uint8list),
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t.close),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (ext == 'pdf') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.pdfFile),
            content: Text(t.downloadPdf),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(t.cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(t.download)),
            ],
          ),
        );
        if (confirm == true) {
          final filename = url.split('/').last;
          await _downloadFile('/transactions/$transactionId/photo', filename);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.cannotDisplayFile)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  String _getAccountType(int? accountId) {
    if (accountId == null) return '';
    try {
      final acc = widget.accounts
          .cast<Map<String, dynamic>>()
          .firstWhere((a) => a['id'] == accountId);
      return acc['type'] ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    Map<DateTime, List<Transaction>> grouped = {};
    for (var trans in _transactions) {
      DateTime date = trans.date.toLocal();
      DateTime key = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(key, () => []).add(trans);
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
                    icon: Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                    label: Text(
                        '${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
                    onPressed: _loadTransactions,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? Center(
                          child: Text(t.noTransactionsForPeriod,
                              style: TextStyle(color: colorScheme.onSurfaceVariant)))
                      : RefreshIndicator(
                          onRefresh: _loadTransactions,
                          child: ListView.builder(
                            itemCount: sortedDates.length,
                            itemBuilder: (context, index) {
                              final date = sortedDates[index];
                              final dayTransactions = grouped[date]!;
                              double turnover = 0;
                              double cashIncome = 0;
                              double nonCashIncome = 0;
                              for (var trans in dayTransactions) {
                                if (trans.type == 'income' && !trans.isDeleted) {
                                  turnover += trans.amount;
                                  String accType = _getAccountType(trans.accountId);
                                  if (accType == 'cash') {
                                    cashIncome += trans.amount;
                                  } else if (accType == 'bank') {
                                    nonCashIncome += trans.amount;
                                  }
                                }
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE, d MMMM yyyy', 'ru')
                                              .format(date),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: colorScheme.onSurface),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          children: [
                                            Text('💹 ${t.turnover}: ${turnover.toStringAsFixed(2)} ₽',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurfaceVariant)),
                                            Text('💵 ${t.cash}: ${cashIncome.toStringAsFixed(2)} ₽',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurfaceVariant)),
                                            Text('💳 ${t.nonCash}: ${nonCashIncome.toStringAsFixed(2)} ₽',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: colorScheme.onSurfaceVariant)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...dayTransactions.map((trans) {
                                    final isDeleted = trans.isDeleted;
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
                                      color: isDeleted
                                          ? colorScheme.surfaceContainerHighest
                                          : colorScheme.surface,
                                      child: ListTile(
                                        title: Row(
                                          children: [
                                            Text(
                                              '${trans.amount.toStringAsFixed(2)} ₽',
                                              style: TextStyle(
                                                color: trans.type == 'income'
                                                    ? (isDeleted
                                                        ? colorScheme.onSurfaceVariant
                                                        : Colors.green)
                                                    : (isDeleted
                                                        ? colorScheme.onSurfaceVariant
                                                        : Colors.red),
                                                decoration: isDeleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${t.transactionNumber} №${trans.number}',
                                              style: TextStyle(
                                                color: isDeleted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${_typeName(trans.type, t)} • ${getCategoryName(trans.categoryId, t)} • ${getAccountName(trans.accountId)} • ${trans.description ?? ''}',
                                              style: TextStyle(
                                                  color: isDeleted
                                                      ? colorScheme.onSurfaceVariant
                                                      : colorScheme.onSurface,
                                                  fontSize: 12),
                                            ),
                                            if (trans.counterparty != null && trans.counterparty!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  '${t.counterpartyLabel}: ${trans.counterparty}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDeleted ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            if (trans.items.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.shopping_cart, size: 14, color: Colors.blueGrey),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        '${t.productsLabel}: ${trans.items.map((i) => '${i.productName} (${i.quantity} ${t.pcs})').join(', ')}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (trans.creatorName != null)
                                              Text(
                                                '${t.createdByLabel}: ${trans.creatorName}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDeleted
                                                        ? colorScheme.onSurfaceVariant
                                                        : colorScheme.onSurfaceVariant),
                                              ),
                                            if (trans.updaterName != null &&
                                                trans.updaterName != trans.creatorName)
                                              Text(
                                                '${t.changedByLabel}: ${trans.updaterName}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDeleted
                                                        ? colorScheme.onSurfaceVariant
                                                        : colorScheme.onSurfaceVariant),
                                              ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (trans.attachmentUrl != null)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.attach_file,
                                                    size: 18,
                                                    color: Colors.blue),
                                                onPressed: () =>
                                                    _showAttachment(
                                                        trans.attachmentUrl, trans.id),
                                                tooltip: t.viewAttachment,
                                              ),
                                            if (isDeleted)
                                              IconButton(
                                                icon: const Icon(Icons.restore,
                                                    color: Colors.orange),
                                                onPressed: () =>
                                                    _restoreTransaction(trans.id),
                                                tooltip: t.restore,
                                              ),
                                            if (widget.isFounder && isDeleted)
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.delete_forever,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _permanentDeleteTransaction(
                                                        trans.id),
                                                tooltip: t.permanentDelete,
                                              ),
                                            Text(
                                              DateFormat('HH:mm')
                                                  .format(trans.date.toLocal()),
                                              style: TextStyle(
                                                  color: isDeleted
                                                      ? colorScheme.onSurfaceVariant
                                                      : colorScheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                        onTap: isDeleted
                                            ? null
                                            : () => _editTransaction(trans),
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
        if (widget.isFounder || widget.permissions.contains('create_transaction'))
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
                      await _loadTransactions();
                      await widget.onRefresh();
                    },
                    accounts: widget.accounts,
                    categories: widget.categories,
                  ),
                );
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }
}