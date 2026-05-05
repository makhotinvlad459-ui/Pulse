import 'package:flutter/material.dart';

class ProductTables extends StatelessWidget {
  final List<dynamic> productIncome;
  final List<dynamic> productConsumption;

  const ProductTables({super.key, required this.productIncome, required this.productConsumption});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Общий расход товара (склад+витрина)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildProductTable(productConsumption, colorScheme),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Общий приход товара (склад)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildProductTable(productIncome, colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductTable(List<dynamic> data, ColorScheme colorScheme) {
    if (data.isEmpty) return Text('Нет данных', style: TextStyle(color: colorScheme.onSurfaceVariant));
    double totalQuantity = 0;
    for (var item in data) totalQuantity += (item['quantity'] as num).toDouble();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FixedColumnWidth(100),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: colorScheme.primary),
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('Товар', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold))),
                Padding(padding: const EdgeInsets.all(8), child: Text('Количество (шт)', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold))),
              ],
            ),
            ...data.map((item) {
              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(item['product_name'], style: TextStyle(color: colorScheme.onSurface))),
                  Padding(padding: const EdgeInsets.all(8), child: Text((item['quantity'] as num).toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                ],
              );
            }).toList(),
            TableRow(
              decoration: BoxDecoration(color: colorScheme.surface),
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('Итого', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
                Padding(padding: const EdgeInsets.all(8), child: Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}