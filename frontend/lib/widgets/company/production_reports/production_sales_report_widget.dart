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

class ProductionSalesReportWidget extends ConsumerStatefulWidget {
  final int companyId;
  const ProductionSalesReportWidget({super.key, required this.companyId});

  @override
  ConsumerState<ProductionSalesReportWidget> createState() => _ProductionSalesReportWidgetState();
}

class _ProductionSalesReportWidgetState extends ConsumerState<ProductionSalesReportWidget> {
  List<Map<String, dynamic>> _sales = [];
  bool _loading = false;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  bool _showOnlyUnpaid = false;

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/production/sales-report', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'only_unpaid': _showOnlyUnpaid,
      });
      setState(() {
        _sales = List<Map<String, dynamic>>.from(res.data);
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _markAsPaid(int transactionId) async {
    final t = AppLocalizations.of(context)!;
    try {
      await _api.patch('/transactions/$transactionId/pay', queryParameters: {'company_id': widget.companyId});
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.paymentMarked)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  String _translateCreator(String creator, AppLocalizations t) {
    if (creator == 'Основатель') return t.founderRole;
    return creator;
  }

  Future<void> _exportToExcel() async {
    if (_sales.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    sheet.appendRow([
      t.dateLabel,
      t.productColumn,
      t.quantity,
      t.amountLabel,
      t.accountLabel,
      t.counterpartyLabel,
      t.paymentStatus,
    ]);

    for (var sale in _sales) {
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(sale['date']));
      final productName = sale['product_name'] ?? '';
      final quantity = sale['quantity'];
      final amount = sale['amount'];
      final accountName = sale['account_name'] ?? '';
      final counterparty = sale['counterparty'] ?? '';
      final isPaid = sale['is_paid'] ?? false;
      sheet.appendRow([date, productName, quantity, amount, accountName, counterparty, isPaid ? t.paid : t.unpaid]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'production_sales.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/production_sales_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
    final currency = t.currencySymbol;

    double totalAmount = 0;
    for (var sale in _sales) {
      totalAmount += (sale['amount'] ?? 0).toDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _selectPeriod,
              icon: Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
              label: Text(
                '${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            FilterChip(
              label: Text(t.showUnpaidOnly),
              selected: _showOnlyUnpaid,
              onSelected: (v) {
                setState(() => _showOnlyUnpaid = v);
                _loadData();
              },
            ),
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
        else if (_sales.isEmpty)
          Center(child: Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant)))
        else
          Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(colorScheme.primary),
                  headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  columns: [
                    DataColumn(label: Text(t.dateLabel)),
                    DataColumn(label: Text(t.productColumn)),
                    DataColumn(label: Text(t.quantity)),
                    DataColumn(label: Text(t.amountLabel)),
                    DataColumn(label: Text(t.counterpartyLabel)),  // ← Контрагент
                    DataColumn(label: Text(t.accountLabel)),       // ← Счет
                    DataColumn(label: Text(t.paymentStatus)),
                    if (!_showOnlyUnpaid) DataColumn(label: Text(t.actions)),
                  ],
                  rows: _sales.map((sale) {
                    final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(sale['date']));
                    final productName = sale['product_name'] ?? '';
                    final quantity = sale['quantity'];
                    final amount = sale['amount'];
                    final counterparty = sale['counterparty'] ?? '';
                    final accountName = sale['account_name'] ?? '';
                    final isPaid = sale['is_paid'] ?? false;
                    final transactionId = sale['transaction_id'];
                    return DataRow(cells: [
                      DataCell(Text(date, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(productName, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(quantity.toString(), style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text('${amount.toStringAsFixed(2)}$currency', style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(counterparty, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text(accountName, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPaid ? t.paid : t.unpaid,
                            style: TextStyle(color: isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      if (!_showOnlyUnpaid)
                        DataCell(
                          !isPaid
                              ? IconButton(
                                  icon: Icon(Icons.payment, color: Colors.green, size: 20),
                                  onPressed: () => _markAsPaid(transactionId),
                                  tooltip: t.markAsPaid,
                                )
                              : const SizedBox.shrink(),
                        ),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${t.totalLabel}: ${totalAmount.toStringAsFixed(2)}$currency',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
      ],
    );
  }
}