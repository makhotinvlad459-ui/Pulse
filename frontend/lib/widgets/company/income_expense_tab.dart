import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class IncomeExpenseTab extends ConsumerStatefulWidget {
  final int companyId;
  final List<dynamic> categories;
  const IncomeExpenseTab(
      {super.key, required this.companyId, required this.categories});

  @override
  ConsumerState<IncomeExpenseTab> createState() => _IncomeExpenseTabState();
}

class _IncomeExpenseTabState extends ConsumerState<IncomeExpenseTab> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate =
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  Map<String, double> _incomeByCategory = {};
  Map<String, double> _expenseByCategory = {};
  bool _loading = true;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;
    try {
      final incomeStats = await api.get('/statistics/income', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      final expenseStats =
          await api.get('/statistics/expense', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      final incomeByCat = <String, double>{};
      for (var cat in incomeStats.data['by_category']) {
        incomeByCat[cat['category']] = (cat['total'] as num).toDouble();
      }
      final expenseByCat = <String, double>{};
      for (var cat in expenseStats.data['by_category']) {
        expenseByCat[cat['category']] = (cat['total'] as num).toDouble();
      }
      final totalIncome = incomeStats.data['total'] as num;
      final totalExpense = expenseStats.data['total'] as num;
      setState(() {
        _incomeByCategory = incomeByCat;
        _expenseByCategory = expenseByCat;
        _balance = totalIncome.toDouble() - totalExpense.toDouble();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _selectPeriod() async {
    final now = DateTime.now();
    DateTime endDate = _endDate.isAfter(now) ? now : _endDate;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: endDate),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadData();
    }
  }

  String _getIconForCategory(String categoryName) {
    if (categoryName == 'Без категории') return '📁';
    final cat = widget.categories
        .firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat != null ? (cat['icon'] ?? '📁') : '📁';
  }

  int? _getCategoryId(String categoryName) {
    if (categoryName == 'Без категории') return null;
    final cat = widget.categories
        .firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat?['id'];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.balanceForPeriod,
                      style: const TextStyle(fontSize: 12)),
                  Text('${_balance.toStringAsFixed(2)} ₽',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              TextButton.icon(
                onPressed: _selectPeriod,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                    '${DateFormat('dd.MM.yyyy', 'ru').format(_startDate)} - ${DateFormat('dd.MM.yyyy', 'ru').format(_endDate)}'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CategoryColumn(
                  title: t.incomeTitle,
                  data: _incomeByCategory,
                  color: Colors.green,
                  getIcon: _getIconForCategory,
                  onTapCategory: (categoryName) {
                    final categoryId = _getCategoryId(categoryName);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsByCategoryScreen(
                          companyId: widget.companyId,
                          categoryId: categoryId,
                          categoryName: categoryName,
                          type: 'income',
                          startDate: _startDate,
                          endDate: _endDate,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _CategoryColumn(
                  title: t.expenseTitle,
                  data: _expenseByCategory,
                  color: Colors.red,
                  getIcon: _getIconForCategory,
                  onTapCategory: (categoryName) {
                    final categoryId = _getCategoryId(categoryName);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsByCategoryScreen(
                          companyId: widget.companyId,
                          categoryId: categoryId,
                          categoryName: categoryName,
                          type: 'expense',
                          startDate: _startDate,
                          endDate: _endDate,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryColumn extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final Color color;
  final String Function(String) getIcon;
  final Function(String) onTapCategory;
  const _CategoryColumn({
    required this.title,
    required this.data,
    required this.color,
    required this.getIcon,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    if (data.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
          const Expanded(child: Center(child: Text('Нет данных'))), // will be localized later
        ],
      );
    }
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 18)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Text(getIcon(entry.key)),
                title: Text(entry.key),
                trailing: Text('${entry.value.toStringAsFixed(2)} ₽'),
                onTap: () => onTapCategory(entry.key),
              );
            },
          ),
        ),
      ],
    );
  }
}

class TransactionsByCategoryScreen extends StatelessWidget {
  final int companyId;
  final int? categoryId;
  final String categoryName;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  const TransactionsByCategoryScreen({
    required this.companyId,
    this.categoryId,
    required this.categoryName,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final queryParams = {
      'company_id': companyId,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
    if (categoryId != null) {
      queryParams['category_id'] = categoryId!;
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(
              '$categoryName (${type == 'income' ? t.incomeTitle : t.expenseTitle})')),
      body: FutureBuilder(
        future: ApiClient().get('/transactions', queryParameters: queryParams),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${t.error}: ${snapshot.error}'));
          }
          final transactions = snapshot.data!.data;
          if (transactions.isEmpty) {
            return Center(child: Text(t.noTransactions));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final trans = transactions[index];
              return Card(
                child: ListTile(
                  title: Text('${trans['amount']} ₽'),
                  subtitle: Text(trans['description'] ?? ''),
                  trailing: Text(DateFormat('dd.MM.yyyy')
                      .format(DateTime.parse(trans['date']))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}