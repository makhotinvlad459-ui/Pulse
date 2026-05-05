import 'package:flutter/material.dart';
import 'transactions_by_category_screen.dart';

class CategoriesColumn extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double total;
  final Color color;
  final int companyId;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'income' or 'expense'
  final List<dynamic> categories; // для получения иконок

  const CategoriesColumn({
    super.key,
    required this.data,
    required this.total,
    required this.color,
    required this.companyId,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.categories,
  });

  String _getIconForCategory(String categoryName) {
    if (categoryName == 'Без категории') return '📁';
    final cat = categories.firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat != null ? (cat['icon'] ?? '📁') : '📁';
  }

  int? _getCategoryId(String categoryName) {
    if (categoryName == 'Без категории') return null;
    final cat = categories.firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat?['id'];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return Text('Нет данных', style: TextStyle(color: colorScheme.onSurfaceVariant));
    }
    final totalAmount = total == 0 ? data.fold(0.0, (sum, item) => sum + (item['total'] as double)) : total;
    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: data.map((item) {
            final categoryName = item['category_name'];
            final amount = item['total'] as double;
            final percent = totalAmount == 0 ? 0 : (amount / totalAmount * 100);
            final icon = _getIconForCategory(categoryName);
            return ListTile(
              leading: Text(icon, style: const TextStyle(fontSize: 20)),
              title: Text(categoryName, style: TextStyle(color: colorScheme.onSurface)),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${amount.toStringAsFixed(2)} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  Text('(${percent.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              onTap: () {
                final categoryId = _getCategoryId(categoryName);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionsByCategoryScreen(
                      companyId: companyId,
                      categoryId: categoryId,
                      categoryName: categoryName,
                      type: type,
                      startDate: startDate,
                      endDate: endDate,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
