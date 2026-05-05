import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SalesTables extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
          selected: {activeTab},
          onSelectionChanged: (Set<int> newSelection) => onTabChanged(newSelection.first),
        ),
        const SizedBox(height: 12),
        activeTab == 0 ? _buildSalesTable(productSales, true, colorScheme, t) : _buildSalesTable(showcaseSales, false, colorScheme, t),
      ],
    );
  }

  Widget _buildSalesTable(List<dynamic> data, bool isProduct, ColorScheme colorScheme, AppLocalizations t) {
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
            DataCell(Text('${(item['amount'] as num).toStringAsFixed(2)} ₽', style: TextStyle(color: colorScheme.onSurface))),
          ]);
        }).toList(),
        DataRow(
          cells: [
            DataCell(Text(t.totalLabel, style: TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
            DataCell(Text('${totalAmount.toStringAsFixed(2)} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
          ],
        ),
      ],
    ),
  );
}
}