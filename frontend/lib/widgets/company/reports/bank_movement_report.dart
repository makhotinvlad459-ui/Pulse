import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class BankAccountMovementReport extends ConsumerStatefulWidget {
  final int companyId;
  const BankAccountMovementReport({super.key, required this.companyId});

  @override
  ConsumerState<BankAccountMovementReport> createState() => _BankAccountMovementReportState();
}

class _BankAccountMovementReportState extends ConsumerState<BankAccountMovementReport> {
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = false;
  int? _bankAccountId;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0)
      .add(const Duration(days: 1))
      .subtract(const Duration(seconds: 1));

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _getBankAccountId();
  }

  Future<void> _getBankAccountId() async {
    try {
      final res = await _api.get('/accounts', queryParameters: {'company_id': widget.companyId});
      final accounts = res.data as List;
      final bankAcc = accounts.firstWhere((a) => a['type'] == 'bank', orElse: () => null);
      if (bankAcc != null) setState(() => _bankAccountId = bankAcc['id']);
      await _loadTransactions();
    } catch (e) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _loadTransactions() async {
    if (_bankAccountId == null) return;
    setState(() => _loading = true);
    try {
      final res = await _api.get('/transactions', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'include_deleted': 'false',
        'account_id': _bankAccountId,
      });
      setState(() {
        _transactions = List<Map<String, dynamic>>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
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
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      await _loadTransactions();
    }
  }

  String _translateDescription(String desc, AppLocalizations t) {
    String result = desc;
    result = result.replaceAll('Оплата по заказу', t.paymentForOrder);
    result = result.replaceAll('Выполнение заказа', t.orderCompletion);
    result = result.replaceAll('Продажа с витрины', t.saleFromShowcase);
    return result;
  }

  Future<void> _exportToExcel() async {
    if (_transactions.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    sheet.appendRow([
      t.dateLabel,
      t.incomeType,
      t.expenseType,
      t.descriptionLabel,
      t.counterpartyLabel,
    ]);

    for (var tx in _transactions) {
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']));
      final amount = tx['amount'];
      final incomeAmount = tx['type'] == 'income' ? amount : 0;
      final expenseAmount = tx['type'] == 'expense' ? amount : 0;
      final description = _translateDescription(tx['description'] ?? '', t);
      final counterparty = tx['counterparty'] ?? '';
      sheet.appendRow([date, incomeAmount, expenseAmount, description, counterparty]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'bank_movement.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/bank_movement_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: t.exportReport);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    double totalIncome = 0;
    double totalExpense = 0;
    for (var tx in _transactions) {
      if (tx['type'] == 'income') totalIncome += tx['amount'];
      else if (tx['type'] == 'expense') totalExpense += tx['amount'];
    }

    if (_bankAccountId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _selectPeriod,
                icon: Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                label: Text(
                  '${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download),
              label: Text(t.exportToExcel),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_transactions.isEmpty)
          Center(child: Text(t.noTransactionsForPeriod, style: TextStyle(color: colorScheme.onSurfaceVariant)))
        else
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(colorScheme.primary),
                  headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  columns: [
                    DataColumn(label: Text(t.dateLabel)),
                    DataColumn(label: Text(t.incomeType)),
                    DataColumn(label: Text(t.expenseType)),
                    DataColumn(label: Text(t.descriptionLabel)),
                    DataColumn(label: Text(t.counterpartyLabel)),
                  ],
                  rows: _transactions.map((tx) {
                    final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']));
                    final amount = tx['amount'];
                    final incomeAmount = tx['type'] == 'income' ? amount : 0;
                    final expenseAmount = tx['type'] == 'expense' ? amount : 0;
                    final description = _translateDescription(tx['description'] ?? '', t);
                    final counterparty = tx['counterparty'] ?? '';
                    return DataRow(cells: [
                      DataCell(Text(date, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(incomeAmount.toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(expenseAmount.toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(description, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(counterparty, style: TextStyle(color: colorScheme.onSurface))),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${t.totalLabel} ${t.incomeType}: ${totalIncome.toStringAsFixed(2)} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(width: 16),
                  Text('${t.totalLabel} ${t.expenseType}: ${totalExpense.toStringAsFixed(2)} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ],
          ),
      ],
    );
  }
}