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

class OperationsExportWidget extends ConsumerStatefulWidget {
  final int companyId;

  const OperationsExportWidget({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<OperationsExportWidget> createState() => _OperationsExportWidgetState();
}

class _OperationsExportWidgetState extends ConsumerState<OperationsExportWidget> {
  List<dynamic> _transactions = [];
  List<dynamic> _accounts = [];
  List<dynamic> _categories = [];
  bool _loading = false;
  bool _loadingReferences = true;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0)
      .add(const Duration(days: 1))
      .subtract(const Duration(seconds: 1));

  final ApiClient _api = ApiClient();

  String _translateAccountName(String? name, AppLocalizations t) {
    if (name == null) return '';
    switch (name) {
      case 'Наличные': return t.cashType;
      case 'Банк': return t.bankType;
      case 'Архив': return t.archive;
      default: return name;
    }
  }

  String _translateCategoryName(String name, AppLocalizations t) {
    switch (name) {
      case 'Зарплата': return t.catSalary;
      case 'Аренда': return t.catRent;
      case 'Транспортные': return t.catTransport;
      case 'Продукты': return t.catFood;
      case 'Связь': return t.catCommunication;
      case 'Реклама': return t.catAdvertising;
      case 'Налоги': return t.catTaxes;
      case 'Прочее': return t.catOther;
      case 'Реализация': return t.catSales;
      case 'Продажи': return t.catSales;
      case 'Касса': return t.catCashbox;
      case 'Офис': return t.catOffice;
      case 'Магазин': return t.catShop;
      case 'Подрядчики': return t.catContractors;
      case 'Без категории': return t.withoutCategory;
      default: return name;
    }
  }

  String _translateDescription(String desc, AppLocalizations t) {
    String result = desc;
    result = result.replaceAll('Оплата по заказу', t.paymentForOrder);
    result = result.replaceAll('Выполнение заказа', t.orderCompletion);
    result = result.replaceAll('Продажа с витрины', t.saleFromShowcase);
    return result;
  }

  String _translateCreator(String name, AppLocalizations t) {
    if (name == 'Основатель') return t.founderRole;
    return name;
  }

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    setState(() => _loadingReferences = true);
    try {
      final accountsRes = await _api.get('/accounts', queryParameters: {'company_id': widget.companyId});
      final categoriesRes = await _api.get('/categories', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _accounts = accountsRes.data;
        _categories = categoriesRes.data;
        _loadingReferences = false;
      });
      await _loadTransactions();
    } catch (e) {
      setState(() => _loadingReferences = false);
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/transactions', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'include_deleted': 'false',
      });
      setState(() {
        _transactions = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
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

  String _getAccountName(int? id, AppLocalizations t) {
    if (id == null) return '';
    try {
      final acc = _accounts.firstWhere((a) => a['id'] == id);
      return _translateAccountName(acc['name'], t);
    } catch (e) {
      return '';
    }
  }

  String _getCategoryName(int? id, AppLocalizations t) {
    if (id == null) return t.withoutCategory;
    try {
      final cat = _categories.firstWhere((c) => c['id'] == id);
      return _translateCategoryName(cat['name'], t);
    } catch (e) {
      return t.withoutCategory;
    }
  }

  Future<void> _exportToExcel() async {
    if (_transactions.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    // Заголовки
    sheet.appendRow([
      t.dateLabel,
      t.transactionNumber,
      t.typeLabel,
      t.amountLabel,
      t.categoryLabel,
      t.accountLabel,
      t.descriptionLabel,
      t.counterpartyLabel,
      t.createdByLabel,
      t.productsLabel,
    ]);

    for (var tx in _transactions) {
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']));
      final number = tx['number'];
      final type = tx['type'] == 'income' ? t.incomeSale : (tx['type'] == 'expense' ? t.expensePurchase : t.transfer);
      final amount = tx['amount'];
      final categoryName = _getCategoryName(tx['category_id'], t);
      final accountName = _getAccountName(tx['account_id'], t);
      final description = _translateDescription(tx['description'] ?? '', t);
      final counterparty = tx['counterparty'] ?? '';
      final creator = _translateCreator(tx['creator_name'] ?? '', t);
      String products = '';
      final items = tx['items'] as List?;
      if (items != null && items.isNotEmpty) {
        products = items.map((i) => '${i['product_name']} (${i['quantity']})').join(', ');
      }
      sheet.appendRow([
        date,
        number,
        type,
        amount,
        categoryName,
        accountName,
        description,
        counterparty,
        creator,
        products,
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'operations_${DateFormat('yyyyMMdd').format(_startDate)}-${DateFormat('yyyyMMdd').format(_endDate)}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/operations_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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

    if (_loadingReferences) {
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(colorScheme.primary),
              headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
              columns: [
                DataColumn(label: Text(t.dateLabel)),
                DataColumn(label: Text(t.transactionNumber)),
                DataColumn(label: Text(t.typeLabel)),
                DataColumn(label: Text(t.amountLabel)),
                DataColumn(label: Text(t.categoryLabel)),
                DataColumn(label: Text(t.accountLabel)),
                DataColumn(label: Text(t.descriptionLabel)),
                DataColumn(label: Text(t.counterpartyLabel)),
                DataColumn(label: Text(t.createdByLabel)),
                DataColumn(label: Text(t.productsLabel)),
              ],
              rows: _transactions.map((tx) {
                final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']));
                final number = tx['number'];
                final type = tx['type'] == 'income' ? t.incomeSale : (tx['type'] == 'expense' ? t.expensePurchase : t.transfer);
                final amount = tx['amount'];
                final categoryName = _getCategoryName(tx['category_id'], t);
                final accountName = _getAccountName(tx['account_id'], t);
                final description = _translateDescription(tx['description'] ?? '', t);
                final counterparty = tx['counterparty'] ?? '';
                final creator = _translateCreator(tx['creator_name'] ?? '', t);
                String products = '';
                final items = tx['items'] as List?;
                if (items != null && items.isNotEmpty) {
                  products = items.map((i) => '${i['product_name']} (${i['quantity']})').join(', ');
                }
                return DataRow(cells: [
                  DataCell(Text(date, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(number.toString(), style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(type, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(amount.toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(categoryName, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(accountName, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(description, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(counterparty, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(creator, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(products, style: TextStyle(color: colorScheme.onSurface))),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }
}