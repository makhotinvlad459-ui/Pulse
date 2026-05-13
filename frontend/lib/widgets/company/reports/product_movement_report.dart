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

class ProductMovementReport extends ConsumerStatefulWidget {
  final int companyId;
  const ProductMovementReport({super.key, required this.companyId});

  @override
  ConsumerState<ProductMovementReport> createState() => _ProductMovementReportState();
}

class _ProductMovementReportState extends ConsumerState<ProductMovementReport> {
  List<dynamic> _products = [];
  List<dynamic> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _loadingProducts = true;
  bool _loadingTransactions = false;
  int? _selectedProductId;
  String _selectedProductName = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadAllTransactions();
  }

  Future<void> _loadProducts() async {
    final api = ApiClient();
    try {
      final res = await api.get('/products/', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _products = res.data;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() => _loadingProducts = false);
      print('Error loading products: $e');
    }
  }

  Future<void> _loadAllTransactions() async {
    setState(() => _loadingTransactions = true);
    final api = ApiClient();
    try {
      final res = await api.get('/transactions', queryParameters: {'company_id': widget.companyId, 'include_deleted': 'false'});
      setState(() {
        _transactions = res.data;
        _loadingTransactions = false;
      });
    } catch (e) {
      setState(() => _loadingTransactions = false);
      print('Error loading transactions: $e');
    }
  }

  void _filterTransactionsByProduct() {
    if (_selectedProductId == null) {
      setState(() => _filteredTransactions = []);
      return;
    }
    final filtered = _transactions.where((tx) {
      final items = tx['items'] as List?;
      if (items == null) return false;
      return items.any((item) => item['product_id'] == _selectedProductId);
    }).toList();
    setState(() {
      _filteredTransactions = filtered.cast<Map<String, dynamic>>();
    });
  }

  void _onProductSelected(int id, String name) {
    setState(() {
      _selectedProductId = id;
      _selectedProductName = name;
      _searchController.clear();
    });
    _filterTransactionsByProduct();
  }

  Future<void> _exportToExcel() async {
    if (_filteredTransactions.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    // Заголовки
    sheet.appendRow([
      t.dateLabel,
      t.incomeType,
      t.expenseType,
      t.quantityLabel,
      t.counterpartyLabel,
      t.descriptionLabel,
    ]);

    for (var tx in _filteredTransactions) {
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']));
      final amount = tx['amount'];
      final incomeAmount = tx['type'] == 'income' ? amount : 0;
      final expenseAmount = tx['type'] == 'expense' ? amount : 0;
      double quantity = 0;
      final items = tx['items'] as List?;
      if (items != null) {
        for (var item in items) {
          if (item['product_id'] == _selectedProductId) {
            quantity += (item['quantity'] as num).toDouble();
          }
        }
      }
      final counterparty = tx['counterparty'] ?? '';
      final description = tx['description'] ?? '';
      sheet.appendRow([
        date,
        incomeAmount,
        expenseAmount,
        quantity.toStringAsFixed(2),
        counterparty,
        description,
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'product_movement_${_selectedProductName}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/product_movement_${_selectedProductName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.productMovementTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) return [];
                  await Future.delayed(Duration.zero);
                  return _products.where((p) => p['name'].toLowerCase().contains(textEditingValue.text.toLowerCase())).cast<Map<String, dynamic>>().toList();
                },
                onSelected: (selected) {
                  _onProductSelected(selected['id'], selected['name']);
                },
                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: t.selectProduct,
                      border: const OutlineInputBorder(),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  );
                },
                displayStringForOption: (option) => option['name'],
              ),
            ),
            const SizedBox(width: 8),
            if (_selectedProductId != null)
              ElevatedButton.icon(
                onPressed: _exportToExcel,
                icon: const Icon(Icons.download),
                label: Text(t.exportToExcel),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingProducts || _loadingTransactions)
          const Center(child: CircularProgressIndicator())
        else if (_selectedProductId == null)
          Center(child: Text(t.selectProductHint, style: TextStyle(color: colorScheme.onSurfaceVariant)))
        else if (_filteredTransactions.isEmpty)
          Center(child: Text(t.noTransactionsForProduct, style: TextStyle(color: colorScheme.onSurfaceVariant)))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(colorScheme.primary),
              headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
              columns: [
                DataColumn(label: Text(t.dateLabel)),
                DataColumn(label: Text(t.incomeType)),
                DataColumn(label: Text(t.expenseType)),
                DataColumn(label: Text(t.quantityLabel)),
                DataColumn(label: Text(t.counterpartyLabel)),
                DataColumn(label: Text(t.descriptionLabel)),
              ],
              rows: _filteredTransactions.map((tx) {
                final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(tx['date']));
                final amount = tx['amount'];
                final incomeAmount = tx['type'] == 'income' ? amount : 0;
                final expenseAmount = tx['type'] == 'expense' ? amount : 0;
                double quantity = 0;
                final items = tx['items'] as List?;
                if (items != null) {
                  for (var item in items) {
                    if (item['product_id'] == _selectedProductId) {
                      quantity += (item['quantity'] as num).toDouble();
                    }
                  }
                }
                final counterparty = tx['counterparty'] ?? '';
                final description = tx['description'] ?? '';
                return DataRow(cells: [
                  DataCell(Text(date, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(incomeAmount.toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(expenseAmount.toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(quantity.toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(counterparty, style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(description, style: TextStyle(color: colorScheme.onSurface))),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }
}