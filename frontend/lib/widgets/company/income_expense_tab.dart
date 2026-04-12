import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';

class IncomeExpenseTab extends StatefulWidget {
  final int companyId;
  final List<dynamic> categories;
  const IncomeExpenseTab(
      {super.key, required this.companyId, required this.categories});

  @override
  State<IncomeExpenseTab> createState() => _IncomeExpenseTabState();
}

class _IncomeExpenseTabState extends State<IncomeExpenseTab> {
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
            .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
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
    final cat = widget.categories
        .firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat != null ? (cat['icon'] ?? '📁') : '📁';
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('Баланс за период',
                      style: TextStyle(fontSize: 12)),
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
                  title: 'Приходы',
                  data: _incomeByCategory,
                  color: Colors.green,
                  getIcon: _getIconForCategory,
                  onTapCategory: (categoryName) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsByCategoryScreen(
                          companyId: widget.companyId,
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
                  title: 'Расходы',
                  data: _expenseByCategory,
                  color: Colors.red,
                  getIcon: _getIconForCategory,
                  onTapCategory: (categoryName) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionsByCategoryScreen(
                          companyId: widget.companyId,
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
    if (data.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
          const Expanded(child: Center(child: Text('Нет данных'))),
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
  final String categoryName;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  const TransactionsByCategoryScreen({
    required this.companyId,
    required this.categoryName,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              '$categoryName (${type == 'income' ? 'Приход' : 'Расход'})')),
      body: FutureBuilder(
        future: ApiClient().get('/transactions', queryParameters: {
          'company_id': companyId,
          'type': type,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final transactions = snapshot.data!.data;
          if (transactions.isEmpty) {
            return const Center(child: Text('Нет операций'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              return Card(
                child: ListTile(
                  title: Text('${t['amount']} ₽'),
                  subtitle: Text(t['description'] ?? ''),
                  trailing: Text(DateFormat('dd.MM.yyyy')
                      .format(DateTime.parse(t['date']))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
