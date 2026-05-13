import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SalesTables extends ConsumerStatefulWidget {
  final List<dynamic> productSales;
  final List<dynamic> showcaseSales;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const SalesTables({
    super.key,
    required this.productSales,
    required this.showcaseSales,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  ConsumerState<SalesTables> createState() => _SalesTablesState();
}

class _SalesTablesState extends ConsumerState<SalesTables> {
  Future<void> _exportToExcel() async {
    final t = AppLocalizations.of(context)!;
    final currentData = widget.activeTab == 0 ? widget.productSales : widget.showcaseSales;
    if (currentData.isEmpty) return;
    final isProduct = widget.activeTab == 0;

    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    // Заголовки
    sheet.appendRow([
      t.productNameLabel,
      t.quantityLabel,
      t.amountLabel,
    ]);

    for (var item in currentData) {
      final name = item[isProduct ? 'product_name' : 'name'];
      final quantity = (item['quantity'] as num).toDouble();
      final amount = (item['amount'] as num).toDouble();
      sheet.appendRow([
        name,
        quantity.toStringAsFixed(2),
        amount.toStringAsFixed(2),
      ]);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'sales_${widget.activeTab == 0 ? 'warehouse' : 'showcase'}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/sales_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
        Row(
          children: [
            Text(t.salesTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Tooltip(
              message: t.salesTooltip,
              child: const Icon(Icons.help_outline, size: 18),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download),
              label: Text(t.exportToExcel),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          style: ButtonStyle(
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) return colorScheme.onPrimary;
              return colorScheme.onSurface;
            }),
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) return colorScheme.primary;
              return colorScheme.surfaceContainerHighest;
            }),
          ),
          segments: [
            ButtonSegment(value: 0, label: Text(t.warehouseSalesTab)),
            ButtonSegment(value: 1, label: Text(t.showcaseSalesTab)),
          ],
          selected: {widget.activeTab},
          onSelectionChanged: (Set<int> newSelection) => widget.onTabChanged(newSelection.first),
        ),
        const SizedBox(height: 12),
        _buildSalesTable(
          widget.activeTab == 0 ? widget.productSales : widget.showcaseSales,
          widget.activeTab == 0,
          colorScheme,
          t,
        ),
      ],
    );
  }

  Widget _buildSalesTable(List<dynamic> data, bool isProduct, ColorScheme colorScheme, AppLocalizations t) {
    final currency = t.currencySymbol;
    if (data.isEmpty) return Center(child: Text(t.noSalesData, style: TextStyle(color: colorScheme.onSurfaceVariant)));
    double totalAmount = 0, totalQuantity = 0;
    for (var item in data) {
      totalAmount += (item['amount'] as num).toDouble();
      totalQuantity += (item['quantity'] as num).toDouble();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(colorScheme.primary),
        headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
        dataRowColor: MaterialStateProperty.all(colorScheme.surface),
        columns: [
          DataColumn(label: Text(t.productNameLabel)),
          DataColumn(label: Text(t.quantityLabel)),
          DataColumn(label: Text(t.amountLabel)),
        ],
        rows: [
          ...data.map((item) {
            return DataRow(cells: [
              DataCell(Text(item[isProduct ? 'product_name' : 'name'], style: TextStyle(color: colorScheme.onSurface))),
              DataCell(Text((item['quantity'] as num).toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
              DataCell(Text('${(item['amount'] as num).toStringAsFixed(2)}$currency', style: TextStyle(color: colorScheme.onSurface))),
            ]);
          }).toList(),
          DataRow(
            cells: [
              DataCell(Text(t.totalLabel, style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
              DataCell(Text('${totalAmount.toStringAsFixed(2)}$currency', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
            ],
          ),
        ],
      ),
    );
  }
}