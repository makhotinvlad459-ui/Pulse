import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_client.dart';

class ReportsTab extends StatefulWidget {
  final int companyId;
  final List<dynamic> categories;
  const ReportsTab({super.key, required this.companyId, required this.categories});

  @override
  ReportsTabState createState() => ReportsTabState();
}

class ReportsTabState extends State<ReportsTab> {
  final ApiClient _api = ApiClient();
  late DateTime _startDate;
  late DateTime _endDate;
  String _periodMode = 'month';
  String _chartInterval = 'day';
  bool _loading = true;

  List<FlSpot> _incomeSpots = [];
  List<FlSpot> _expenseSpots = [];
  List<dynamic> _dynamicsRaw = [];
  List<Map<String, dynamic>> _incomeByCategory = [];
  List<Map<String, dynamic>> _expenseByCategory = [];
  Map<String, double> _cashVsNoncash = {'cash': 0, 'noncash': 0};
  List<dynamic> _productSales = [];
  List<dynamic> _showcaseSales = [];
  List<dynamic> _productIncome = [];
  List<dynamic> _productConsumption = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalProfit = 0;
  List<String> _xLabels = [];
  int _activeSalesTab = 0;

  @override
  void initState() {
    super.initState();
    _setPeriodForMode('month');
  }

  void refreshData() => _loadData();

  void _setPeriodForMode(String mode) {
    final now = DateTime.now();
    DateTime start, end;
    switch (mode) {
      case 'day':
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = now;
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'year':
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
      default:
        start = DateTime(now.year, now.month, 1);
        end = now;
    }
    setState(() {
      _startDate = start;
      _endDate = end;
      _periodMode = mode;
      _chartInterval = (mode == 'day' || mode == 'week' || mode == 'month') ? 'day' : 'month';
    });
    _loadData();
  }

  void _shiftPeriod(int delta) {
    if (_periodMode == 'custom') return;
    DateTime newStart = _startDate, newEnd = _endDate;
    switch (_periodMode) {
      case 'day':
        newStart = _startDate.add(Duration(days: delta));
        newEnd = newStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        break;
      case 'week':
        newStart = _startDate.add(Duration(days: delta * 7));
        newEnd = newStart.add(const Duration(days: 6));
        break;
      case 'month':
        newStart = DateTime(_startDate.year, _startDate.month + delta, 1);
        if (newStart.isAfter(DateTime.now())) return;
        newEnd = DateTime(newStart.year, newStart.month + 1, 0);
        break;
      case 'year':
        newStart = DateTime(_startDate.year + delta, 1, 1);
        if (newStart.isAfter(DateTime.now())) return;
        newEnd = DateTime(newStart.year, 12, 31);
        break;
    }
    if (newStart.isAfter(DateTime.now())) return;
    setState(() {
      _startDate = newStart;
      _endDate = newEnd;
    });
    _loadData();
  }

  void _selectCustomPeriod() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _periodMode = 'custom';
        _chartInterval = 'day';
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadDynamics(),
      _loadIncomeByCategory(),
      _loadExpenseByCategory(),
      _loadCashVsNoncash(),
      _loadProductSales(),
      _loadShowcaseSales(),
      _loadProductIncome(),
      _loadProductConsumption(),
    ]);
    _calculateTotals();
    _prepareChartSpots();
    setState(() => _loading = false);
  }

  Future<void> _loadDynamics() async {
    try {
      final res = await _api.getDynamics(widget.companyId, _startDate, _endDate, _chartInterval);
      _dynamicsRaw = res.data ?? [];
    } catch (e) {
      _dynamicsRaw = [];
    }
  }

  void _prepareChartSpots() {
    if (_dynamicsRaw.isEmpty) {
      _incomeSpots = [];
      _expenseSpots = [];
      _xLabels = [];
      return;
    }
    _incomeSpots = [];
    _expenseSpots = [];
    _xLabels = [];
    for (int i = 0; i < _dynamicsRaw.length; i++) {
      final item = _dynamicsRaw[i];
      _incomeSpots.add(FlSpot(i.toDouble(), (item['income'] as num?)?.toDouble() ?? 0));
      _expenseSpots.add(FlSpot(i.toDouble(), (item['expense'] as num?)?.toDouble() ?? 0));
      _xLabels.add(_formatPeriodLabel(item['period'], _chartInterval));
    }
  }

  String _formatPeriodLabel(String period, String interval) {
    if (interval == 'day') {
      final parts = period.split('-');
      if (parts.length == 3) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return DateFormat('d MMM', 'ru').format(date);
      }
      return period;
    } else if (interval == 'week') {
      final parts = period.split('-');
      if (parts.length == 2) return '${parts[0]}, нед.${parts[1]}';
      return period;
    } else if (interval == 'month') {
      final parts = period.split('-');
      if (parts.length == 2) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return DateFormat('MMM', 'ru').format(date);
      }
      return period;
    }
    return period;
  }

  Future<void> _loadIncomeByCategory() async {
    try {
      final res = await _api.get('/statistics/income', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      final data = res.data;
      List<dynamic> raw = data['by_category'] ?? [];
      List<Map<String, dynamic>> normalized = [];
      double totalNoCat = 0;
      for (var item in raw) {
        final cat = item['category'];
        final total = (item['total'] as num).toDouble();
        if (cat == null || cat.toString().isEmpty) {
          totalNoCat += total;
        } else {
          normalized.add({'category_name': cat.toString(), 'total': total});
        }
      }
      if (totalNoCat > 0) normalized.add({'category_name': 'Без категории', 'total': totalNoCat});
      _incomeByCategory = normalized;
    } catch (e) {}
  }

  Future<void> _loadExpenseByCategory() async {
    try {
      final res = await _api.get('/statistics/expense', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      final data = res.data;
      List<dynamic> raw = data['by_category'] ?? [];
      List<Map<String, dynamic>> normalized = [];
      double totalNoCat = 0;
      for (var item in raw) {
        final cat = item['category'];
        final total = (item['total'] as num).toDouble();
        if (cat == null || cat.toString().isEmpty) {
          totalNoCat += total;
        } else {
          normalized.add({'category_name': cat.toString(), 'total': total});
        }
      }
      if (totalNoCat > 0) normalized.add({'category_name': 'Без категории', 'total': totalNoCat});
      _expenseByCategory = normalized;
    } catch (e) {}
  }

  Future<void> _loadCashVsNoncash() async {
    try {
      final res = await _api.get('/statistics/cash-vs-noncash', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      _cashVsNoncash = {
        'cash': (res.data['cash'] as num).toDouble(),
        'noncash': (res.data['noncash'] as num).toDouble(),
      };
    } catch (e) {}
  }

  Future<void> _loadProductSales() async {
    try {
      final res = await _api.get('/statistics/product-sales', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'sort_by': 'quantity',
      });
      _productSales = res.data ?? [];
    } catch (e) {
      _productSales = [];
    }
  }

  Future<void> _loadShowcaseSales() async {
    try {
      final res = await _api.get('/statistics/showcase-sales', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'sort_by': 'quantity',
      });
      _showcaseSales = res.data ?? [];
    } catch (e) {
      _showcaseSales = [];
    }
  }

  Future<void> _loadProductIncome() async {
    try {
      final res = await _api.get('/statistics/product-income', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'sort_by': 'quantity',
      });
      _productIncome = res.data ?? [];
    } catch (e) {
      _productIncome = [];
    }
  }

  Future<void> _loadProductConsumption() async {
    try {
      final res = await _api.get('/statistics/product-consumption', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
        'sort_by': 'quantity',
      });
      _productConsumption = res.data ?? [];
    } catch (e) {
      _productConsumption = [];
    }
  }

  void _calculateTotals() {
    _totalIncome = _dynamicsRaw.fold(0, (sum, item) => sum + ((item['income'] as num?)?.toDouble() ?? 0));
    _totalExpense = _dynamicsRaw.fold(0, (sum, item) => sum + ((item['expense'] as num?)?.toDouble() ?? 0));
    _totalProfit = _totalIncome - _totalExpense;
  }

  void _onSpotTapped(int index) async {
    if (index < 0 || index >= _dynamicsRaw.length) return;
    final periodStr = _dynamicsRaw[index]['period'];
    if (periodStr == null) return;
    DateTime newStart, newEnd;
    if (_chartInterval == 'day') {
      newStart = DateTime.parse(periodStr);
      newEnd = newStart.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    } else if (_chartInterval == 'week') {
      final parts = periodStr.split('-');
      final year = int.parse(parts[0]), week = int.parse(parts[1]);
      final firstDayOfYear = DateTime(year, 1, 1);
      final daysOffset = (week - 1) * 7 - firstDayOfYear.weekday + 1;
      newStart = firstDayOfYear.add(Duration(days: daysOffset));
      newEnd = newStart.add(const Duration(days: 6));
    } else if (_chartInterval == 'month') {
      final parts = periodStr.split('-');
      final year = int.parse(parts[0]), month = int.parse(parts[1]);
      newStart = DateTime(year, month, 1);
      newEnd = DateTime(year, month + 1, 0);
    } else {
      final year = int.parse(periodStr);
      newStart = DateTime(year, 1, 1);
      newEnd = DateTime(year, 12, 31);
    }
    if (_startDate == newStart && _endDate == newEnd) return;
    setState(() {
      _startDate = newStart;
      _endDate = newEnd;
      _periodMode = 'custom';
      _chartInterval = 'day';
    });
    await _loadData();
  }

  String _getIconForCategory(String categoryName) {
    if (categoryName == 'Без категории') return '📁';
    final cat = widget.categories.firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat != null ? (cat['icon'] ?? '📁') : '📁';
  }

  int? _getCategoryId(String categoryName) {
    if (categoryName == 'Без категории') return null;
    final cat = widget.categories.firstWhere((c) => c['name'] == categoryName, orElse: () => null);
    return cat?['id'];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_periodMode != 'custom')
                Row(
                  children: [
                    _buildShiftButton(Icons.arrow_back_ios, -1, colorScheme),
                    const SizedBox(width: 8),
                    _buildShiftButton(Icons.arrow_forward_ios, 1, colorScheme),
                    const SizedBox(width: 16),
                  ],
                ),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPeriodButton('День', 'day', colorScheme),
                    _buildPeriodButton('Неделя', 'week', colorScheme),
                    _buildPeriodButton('Месяц', 'month', colorScheme),
                    _buildPeriodButton('Год', 'year', colorScheme),
                    ElevatedButton(
                      onPressed: _selectCustomPeriod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        foregroundColor: colorScheme.onSurface,
                      ),
                      child: const Text('Выбрать'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryCard(title: 'Доход', amount: _totalIncome, color: Colors.green, colorScheme: colorScheme),
              const SizedBox(width: 8),
              _SummaryCard(title: 'Расход', amount: _totalExpense, color: Colors.red, colorScheme: colorScheme),
              const SizedBox(width: 8),
              _SummaryCard(title: 'Прибыль', amount: _totalProfit, color: Colors.blue, colorScheme: colorScheme),
            ],
          ),
          const SizedBox(height: 24),
          if (_incomeByCategory.isNotEmpty) ...[
            const Text('Доходы по категориям', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildCategoryColumn(_incomeByCategory, total: _totalIncome, color: Colors.green, colorScheme: colorScheme),
            const SizedBox(height: 24),
          ],
          if (_expenseByCategory.isNotEmpty) ...[
            const Text('Расходы по категориям', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildCategoryColumn(_expenseByCategory, total: _totalExpense, color: Colors.red, colorScheme: colorScheme),
            const SizedBox(height: 24),
          ],
          const Text('Динамика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildLineChart(colorScheme),
          const SizedBox(height: 24),
          const Text('Наличные vs Безналичные', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildCashBar(colorScheme),
          const SizedBox(height: 24),
          // Две таблицы горизонтально
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Общий расход товара (склад+витрина)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildProductConsumptionTable(_productConsumption, colorScheme),
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
                    _buildProductConsumptionTable(_productIncome, colorScheme),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
            selected: {_activeSalesTab},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() => _activeSalesTab = newSelection.first);
            },
          ),
          const SizedBox(height: 12),
          _activeSalesTab == 0
              ? _buildSalesTable(_productSales, isProduct: true, colorScheme: colorScheme)
              : _buildSalesTable(_showcaseSales, isProduct: false, colorScheme: colorScheme),
        ],
      ),
    );
  }

  Widget _buildShiftButton(IconData icon, int delta, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _shiftPeriod(delta),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.primaryContainer,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String mode, ColorScheme colorScheme) {
    final isSelected = _periodMode == mode;
    return ElevatedButton(
      onPressed: () => _setPeriodForMode(mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }

  Widget _SummaryCard({required String title, required double amount, required Color color, required ColorScheme colorScheme}) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${amount.toStringAsFixed(2)} ₽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(ColorScheme colorScheme) {
    if (_incomeSpots.isEmpty || _incomeSpots.length <= 2) return const Center(child: Text('Нет данных для графика'));
    return Container(
      padding: const EdgeInsets.only(right: 40),
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(NumberFormat.compact().format(value), style: TextStyle(color: colorScheme.onSurface)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 70,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _xLabels.length) return const Text('');
                  return Transform.rotate(
                    angle: -0.5,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(_xLabels[index], style: TextStyle(fontSize: 10, color: colorScheme.onSurface)),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: _incomeSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
            ),
            LineChartBarData(
              spots: _expenseSpots,
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.2)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) => LineTooltipItem(
                  '${spot.barIndex == 0 ? 'Доход' : 'Расход'}: ${spot.y.toStringAsFixed(2)} ₽',
                  const TextStyle(color: Colors.white),
                )).toList();
              },
            ),
            handleBuiltInTouches: true,
            touchCallback: (FlTouchEvent event, response) {
              if (event is FlTapUpEvent && response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                _onSpotTapped(response.lineBarSpots!.first.x.toInt());
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryColumn(List<Map<String, dynamic>> data, {required double total, required Color color, required ColorScheme colorScheme}) {
    if (data.isEmpty) return Text('Нет данных', style: TextStyle(color: colorScheme.onSurfaceVariant));
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
                      companyId: widget.companyId,
                      categoryId: categoryId,
                      categoryName: categoryName,
                      type: color == Colors.green ? 'income' : 'expense',
                      startDate: _startDate,
                      endDate: _endDate,
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

  Widget _buildCashBar(ColorScheme colorScheme) {
    final cash = _cashVsNoncash['cash']!;
    final noncash = _cashVsNoncash['noncash']!;
    final total = cash + noncash;
    if (total == 0) return Text('Нет данных', style: TextStyle(color: colorScheme.onSurfaceVariant));
    final cashPercent = (cash / total * 100).clamp(0, 100);
    final noncashPercent = (noncash / total * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          child: Row(
            children: [
              Expanded(
                flex: cashPercent.toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  ),
                  child: Center(child: Text('${cashPercent.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
              Expanded(
                flex: noncashPercent.toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                  ),
                  child: Center(child: Text('${noncashPercent.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Container(width: 12, height: 12, color: Colors.orange), const SizedBox(width: 4), Text('Наличные: ${cash.toStringAsFixed(2)} ₽', style: TextStyle(color: colorScheme.onSurfaceVariant))]),
            Row(children: [Container(width: 12, height: 12, color: Colors.blue), const SizedBox(width: 4), Text('Безналичные: ${noncash.toStringAsFixed(2)} ₽', style: TextStyle(color: colorScheme.onSurfaceVariant))]),
          ],
        ),
      ],
    );
  }

  Widget _buildProductConsumptionTable(List<dynamic> data, ColorScheme colorScheme) {
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
            1: FixedColumnWidth(100), // фиксированная ширина для колонки Количество (шт)
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: colorScheme.primary),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Товар', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Количество (шт)', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...data.map((item) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(item['product_name'], style: TextStyle(color: colorScheme.onSurface)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text((item['quantity'] as num).toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface)),
                  ),
                ],
              );
            }).toList(),
            TableRow(
              decoration: BoxDecoration(color: colorScheme.surface),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Итого', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTable(List<dynamic> data, {required bool isProduct, required ColorScheme colorScheme}) {
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
    final queryParams = {
      'company_id': companyId,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
    if (categoryId != null) queryParams['category_id'] = categoryId!;
    return Scaffold(
      appBar: AppBar(title: Text('$categoryName (${type == 'income' ? 'Приход' : 'Расход'})')),
      body: FutureBuilder(
        future: ApiClient().get('/transactions', queryParameters: queryParams),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          final transactions = snapshot.data!.data;
          if (transactions.isEmpty) return const Center(child: Text('Нет операций'));
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              return Card(
                child: ListTile(
                  title: Text('${t['amount']} ₽'),
                  subtitle: Text(t['description'] ?? ''),
                  trailing: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(t['date']))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}