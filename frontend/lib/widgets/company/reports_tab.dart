import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_client.dart';

class ReportsTab extends ConsumerStatefulWidget {
  final int companyId;
  const ReportsTab({super.key, required this.companyId});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  final ApiClient _api = ApiClient();
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _interval = 'day';
  bool _loading = true;

  List<dynamic> _dynamics = [];
  List<dynamic> _incomeByCategory = [];
  List<dynamic> _expenseByCategory = [];
  Map<String, double> _cashVsNoncash = {'cash': 0, 'noncash': 0};
  List<dynamic> _productSales = [];
  List<dynamic> _showcaseSales = [];
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalProfit = 0;

  int _activeSalesTab = 0; // 0 - товары, 1 - витрина

  @override
  void initState() {
    super.initState();
    _loadData();
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
    ]);
    _calculateTotals();
    setState(() => _loading = false);
  }

  Future<void> _loadDynamics() async {
    try {
      final res = await _api.getDynamics(widget.companyId, _startDate, _endDate, _interval);
      _dynamics = res.data;
    } catch (e) {
      print('Dynamics error: $e');
    }
  }

  Future<void> _loadIncomeByCategory() async {
    try {
      final res = await _api.getIncomeByCategory(widget.companyId, _startDate, _endDate);
      _incomeByCategory = res.data;
    } catch (e) {
      print('Income by category error: $e');
    }
  }

  Future<void> _loadExpenseByCategory() async {
    try {
      final res = await _api.getExpenseByCategory(widget.companyId, _startDate, _endDate);
      _expenseByCategory = res.data;
    } catch (e) {
      print('Expense by category error: $e');
    }
  }

  Future<void> _loadCashVsNoncash() async {
    try {
      final res = await _api.getCashVsNoncash(widget.companyId, _startDate, _endDate);
      _cashVsNoncash = {
        'cash': (res.data['cash'] as num).toDouble(),
        'noncash': (res.data['noncash'] as num).toDouble(),
      };
    } catch (e) {
      print('Cash vs noncash error: $e');
    }
  }

  Future<void> _loadProductSales() async {
    try {
      final res = await _api.getProductSales(widget.companyId, _startDate, _endDate, 'quantity');
      _productSales = res.data;
    } catch (e) {
      print('Product sales error: $e');
    }
  }

  Future<void> _loadShowcaseSales() async {
    try {
      final res = await _api.getShowcaseSales(widget.companyId, _startDate, _endDate, 'quantity');
      _showcaseSales = res.data;
    } catch (e) {
      print('Showcase sales error: $e');
    }
  }

  void _calculateTotals() {
    _totalIncome = _dynamics.fold(0, (sum, item) => sum + (item['income'] as num).toDouble());
    _totalExpense = _dynamics.fold(0, (sum, item) => sum + (item['expense'] as num).toDouble());
    _totalProfit = _totalIncome - _totalExpense;
  }

  void _selectPeriod() async {
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
      });
      await _loadData();
    }
  }

  void _setQuickPeriod(int days) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = _endDate.subtract(Duration(days: days));
    });
    _loadData();
  }

  void _onCategoryTap(int categoryId, bool isIncome) {
    // TODO: реализовать переход к операциям с фильтром
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Переход к операциям с категорией ID=$categoryId (в разработке)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Переключатель периода
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(onPressed: () => _setQuickPeriod(1), child: const Text('День')),
              ElevatedButton(onPressed: () => _setQuickPeriod(7), child: const Text('Неделя')),
              ElevatedButton(onPressed: () => _setQuickPeriod(30), child: const Text('Месяц')),
              ElevatedButton(onPressed: () => _setQuickPeriod(90), child: const Text('Квартал')),
              ElevatedButton(onPressed: () => _setQuickPeriod(365), child: const Text('Год')),
              ElevatedButton(onPressed: _selectPeriod, child: const Text('Выбрать')),
            ],
          ),
          const SizedBox(height: 16),
          // Карточки итогов
          Row(
            children: [
              _SummaryCard(title: 'Доход', amount: _totalIncome, color: Colors.green),
              const SizedBox(width: 8),
              _SummaryCard(title: 'Расход', amount: _totalExpense, color: Colors.red),
              const SizedBox(width: 8),
              _SummaryCard(title: 'Прибыль', amount: _totalProfit, color: Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          // Динамика (линейный график) с легендой
          const Text('Динамика доходов, расходов и прибыли', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildLegend(),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: _buildLineChart(),
          ),
          const SizedBox(height: 24),
          // Структура доходов и расходов в одной строке
          const Text('Структура', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Доходы', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SizedBox(height: 220, child: _buildPieChart(_incomeByCategory, Colors.green, isIncome: true)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    const Text('Расходы', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SizedBox(height: 220, child: _buildPieChart(_expenseByCategory, Colors.red, isIncome: false)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Наличные vs Безналичные
          const Text('Наличные vs Безналичные', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(height: 220, child: _buildCashPieChart()),
          const SizedBox(height: 24),
          // Продажи товаров и витрины – вкладки
          const Text('Продажи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Товары со склада')),
              ButtonSegment(value: 1, label: Text('Витрина')),
            ],
            selected: {_activeSalesTab},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _activeSalesTab = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 12),
          _activeSalesTab == 0 ? _buildSalesTable(_productSales, isProduct: true) : _buildSalesTable(_showcaseSales, isProduct: false),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.green, label: 'Доход'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.red, label: 'Расход'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.blue, label: 'Прибыль'),
      ],
    );
  }

  Widget _LegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _SummaryCard({required String title, required double amount, required Color color}) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${amount.toStringAsFixed(2)} ₽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (_dynamics.isEmpty) return const Center(child: Text('Нет данных'));
    double maxValue = 0;
    for (var item in _dynamics) {
      maxValue = maxValue > (item['income'] as num).toDouble() ? maxValue : (item['income'] as num).toDouble();
      maxValue = maxValue > (item['expense'] as num).toDouble() ? maxValue : (item['expense'] as num).toDouble();
      maxValue = maxValue > (item['profit'] as num).toDouble() ? maxValue : (item['profit'] as num).toDouble();
    }
    maxValue = maxValue * 1.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(NumberFormat.compact().format(value));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _dynamics.length) return const Text('');
                return Text(_dynamics[index]['period']);
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        minY: 0,
        maxY: maxValue,
        lineBarsData: [
          LineChartBarData(
            spots: _dynamics.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['income'])).toList(),
            color: Colors.green,
            isCurved: true,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: _dynamics.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['expense'])).toList(),
            color: Colors.red,
            isCurved: true,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
          LineChartBarData(
            spots: _dynamics.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['profit'])).toList(),
            color: Colors.blue,
            isCurved: true,
            barWidth: 2,
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<dynamic> data, Color defaultColor, {required bool isIncome}) {
    if (data.isEmpty) return const Center(child: Text('Нет данных'));
    final total = data.fold(0.0, (sum, item) => sum + (item['total'] as num).toDouble());
    if (total == 0) return const Center(child: Text('Нет данных'));
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final value = (item['total'] as num).toDouble();
      final percentage = value / total;
      sections.add(
        PieChartSectionData(
          value: value,
          title: '${item['category_name']}\n${value.toStringAsFixed(0)} ₽\n(${(percentage * 100).toStringAsFixed(1)}%)',
          color: Colors.primaries[i % Colors.primaries.length],
          radius: 90,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }
    return GestureDetector(
      onTapDown: (details) {
        // Здесь можно реализовать определение нажатого сектора через PieTouchDetector,
        // но для простоты пока оставим без обработки клика.
      },
      child: PieChart(
        PieChartData(sections: sections),
      ),
    );
  }

  Widget _buildCashPieChart() {
    final total = _cashVsNoncash['cash']! + _cashVsNoncash['noncash']!;
    if (total == 0) return const Center(child: Text('Нет данных'));
    final sections = [
      PieChartSectionData(
        value: _cashVsNoncash['cash']!,
        title: 'Наличные\n${_cashVsNoncash['cash']!.toStringAsFixed(0)} ₽',
        color: Colors.orange,
        radius: 90,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: _cashVsNoncash['noncash']!,
        title: 'Безналичные\n${_cashVsNoncash['noncash']!.toStringAsFixed(0)} ₽',
        color: Colors.blue,
        radius: 90,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
    return PieChart(PieChartData(sections: sections));
  }

  Widget _buildSalesTable(List<dynamic> data, {required bool isProduct}) {
    if (data.isEmpty) return const Center(child: Text('Нет продаж'));
    double totalAmount = 0;
    int totalQuantity = 0;
    for (var item in data) {
      totalAmount += (item['amount'] as num).toDouble();
      totalQuantity += (item['quantity'] as num).toInt();
    }
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Название')),
              DataColumn(label: Text('Кол-во')),
              DataColumn(label: Text('Сумма')),
            ],
            rows: [
              ...data.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item[isProduct ? 'product_name' : 'name'])),
                  DataCell(Text(item['quantity'].toString())),
                  DataCell(Text('${(item['amount'] as num).toStringAsFixed(2)} ₽')),
                ]);
              }).toList(),
              DataRow(
                cells: [
                  const DataCell(Text('Итого', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(totalQuantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('${totalAmount.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}