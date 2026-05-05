import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ProductTables extends ConsumerWidget {
  final List<dynamic> productIncome;
  final List<dynamic> productConsumption;

  const ProductTables({super.key, required this.productIncome, required this.productConsumption});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.totalConsumptionTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildProductTable(productConsumption, colorScheme, t),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.totalIncomeTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildProductTable(productIncome, colorScheme, t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductTable(List<dynamic> data, ColorScheme colorScheme, AppLocalizations t) {
    if (data.isEmpty) return Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant));
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
                Padding(padding: const EdgeInsets.all(8), child: Text(t.productColumn, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold))),
                Padding(padding: const EdgeInsets.all(8), child: Text(t.quantityPcsColumn, style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold))),
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
                Padding(padding: const EdgeInsets.all(8), child: Text(t.totalLabel, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
                Padding(padding: const EdgeInsets.all(8), child: Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}