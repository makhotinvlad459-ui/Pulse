import 'package:flutter/material.dart';

class SalesTables extends StatelessWidget {
  final List<dynamic> productSales;
  final List<dynamic> showcaseSales;
  final int activeTab; // 0 - товары со склада, 1 - товары с витрины
  final ValueChanged<int> onTabChanged;

  const SalesTables({
    super.key,
    required this.productSales,
    required this.showcaseSales,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Продажи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Продажи со склада (не включают товары, проданные через витрину)',
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
          segments: const [
            ButtonSegment(value: 0, label: Text('Товары со склада')),
            ButtonSegment(value: 1, label: Text('Товары с витрины')),
          ],
          selected: {activeTab},
          onSelectionChanged: (Set<int> newSelection) => onTabChanged(newSelection.first),
        ),
        const SizedBox(height: 12),
        activeTab == 0 ? _buildSalesTable(productSales, true, colorScheme) : _buildSalesTable(showcaseSales, false, colorScheme),
      ],
    );
  }

  Widget _buildSalesTable(List<dynamic> data, bool isProduct, ColorScheme colorScheme) {
    if (data.isEmpty) return Center(child: Text('Нет продаж', style: TextStyle(color: colorScheme.onSurfaceVariant)));
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
        columns: const [
          DataColumn(label: Text('Название')),
          DataColumn(label: Text('Количество')),
          DataColumn(label: Text('Сумма')),
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
              const DataCell(Text('Итого', style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
              DataCell(Text('${totalAmount.toStringAsFixed(2)} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
            ],
          ),
        ],
      ),
    );
  }
}