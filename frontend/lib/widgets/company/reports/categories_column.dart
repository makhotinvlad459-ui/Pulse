import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/locale_provider.dart';
import 'transactions_by_category_screen.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CategoriesColumn extends ConsumerWidget {
  final List<Map<String, dynamic>> data;
  final double total;
  final Color color;
  final int companyId;
  final DateTime startDate;
  final DateTime endDate;
  final String type;
  final List<dynamic> categories;

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
      case 'Без категории': return t.withoutCategory;
      case 'Подрядчики': return t.catContractors;
      default: return name;
    }
  }

  String _getIconForCategory(String categoryName, AppLocalizations t) {
    if (categoryName == t.withoutCategory) return '📁';
    final cat = categories.firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat != null ? (cat['icon'] ?? '📁') : '📁';
  }

  int? _getCategoryId(String categoryName, AppLocalizations t) {
    if (categoryName == t.withoutCategory) return null;
    final cat = categories.firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat?['id'];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;
    if (data.isEmpty) {
      return Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant));
    }
    final totalAmount = total == 0 ? data.fold(0.0, (sum, item) => sum + (item['total'] as double)) : total;
    return Card(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: data.map((item) {
            final originalCategoryName = item['category_name'];
            final categoryName = _translateCategoryName(originalCategoryName, t);
            final amount = item['total'] as double;
            final percent = totalAmount == 0 ? 0 : (amount / totalAmount * 100);
            final icon = _getIconForCategory(originalCategoryName, t);
            return ListTile(
              leading: Text(icon, style: const TextStyle(fontSize: 20)),
              title: Text(categoryName, style: TextStyle(color: colorScheme.onSurface)),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${amount.toStringAsFixed(2)}$currency', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  Text('(${percent.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              onTap: () {
                final categoryId = _getCategoryId(originalCategoryName, t);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionsByCategoryScreen(
                      companyId: companyId,
                      categoryId: categoryId,
                      categoryName: originalCategoryName,
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