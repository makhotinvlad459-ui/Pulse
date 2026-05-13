import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'reports/period_selector.dart';
import 'reports/summary_cards.dart';
import 'reports/categories_column.dart';
import 'reports/dynamics_chart.dart';
import 'reports/cash_vs_noncash_bar.dart';
import 'reports/product_tables.dart';
import 'reports/sales_tables.dart';
import 'reports/material_consumption_widget.dart';
import 'reports/order_stats_widget.dart';
import 'reports/counterparties_report_widget.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'reports/product_movement_report.dart';
import 'reports/operations_export_widget.dart';
import 'reports/counterparty_movement_report.dart';
import 'reports/cash_movement_report.dart';
import 'reports/bank_movement_report.dart';


class ReportsTab extends ConsumerStatefulWidget {
  final int companyId;
  final List<dynamic> categories;
  const ReportsTab({super.key, required this.companyId, required this.categories});

  @override
  ReportsTabState createState() => ReportsTabState();
}

class ReportsTabState extends ConsumerState<ReportsTab> {
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
      locale: Localizations.localeOf(context),
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
    final locale = Localizations.localeOf(context);
    for (int i = 0; i < _dynamicsRaw.length; i++) {
      final item = _dynamicsRaw[i];
      _incomeSpots.add(FlSpot(i.toDouble(), (item['income'] as num?)?.toDouble() ?? 0));
      _expenseSpots.add(FlSpot(i.toDouble(), (item['expense'] as num?)?.toDouble() ?? 0));
      _xLabels.add(_formatPeriodLabel(item['period'], _chartInterval, locale));
    }
  }

  String _formatPeriodLabel(String period, String interval, Locale locale) {
    if (interval == 'day') {
      final parts = period.split('-');
      if (parts.length == 3) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return DateFormat('d MMM', locale.toString()).format(date);
      }
      return period;
    } else if (interval == 'week') {
      final parts = period.split('-');
      if (parts.length == 2) return '${parts[0]}, ${AppLocalizations.of(context)!.weekAbbr}${parts[1]}';
      return period;
    } else if (interval == 'month') {
      final parts = period.split('-');
      if (parts.length == 2) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return DateFormat('MMM', locale.toString()).format(date);
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
        if (cat != null && cat.toString().isNotEmpty) {
          normalized.add({'category_name': cat.toString(), 'total': total});
        } else {
          totalNoCat += total;
        }
      }
      if (totalNoCat > 0) {
        final t = AppLocalizations.of(context)!;
        normalized.add({'category_name': t.withoutCategory, 'total': totalNoCat});
      }
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
        if (cat != null && cat.toString().isNotEmpty) {
          normalized.add({'category_name': cat.toString(), 'total': total});
        } else {
          totalNoCat += total;
        }
      }
      if (totalNoCat > 0) {
        final t = AppLocalizations.of(context)!;
        normalized.add({'category_name': t.withoutCategory, 'total': totalNoCat});
      }
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

   @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PeriodSelector(
            periodMode: _periodMode,
            onDay: () => _setPeriodForMode('day'),
            onWeek: () => _setPeriodForMode('week'),
            onMonth: () => _setPeriodForMode('month'),
            onYear: () => _setPeriodForMode('year'),
            onCustom: _selectCustomPeriod,
            onPrevious: () => _shiftPeriod(-1),
            onNext: () => _shiftPeriod(1),
            showArrows: _periodMode != 'custom',
          ),
          const SizedBox(height: 16),
          SummaryCards(income: _totalIncome, expense: _totalExpense, profit: _totalProfit),
          const SizedBox(height: 24),

          Text(t.dynamics, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DynamicsChart(
            incomeSpots: _incomeSpots,
            expenseSpots: _expenseSpots,
            xLabels: _xLabels,
            onSpotTapped: _onSpotTapped,
          ),
          const SizedBox(height: 24),

          Text(t.cashVsNoncash, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CashVsNoncashBar(cash: _cashVsNoncash['cash']!, noncash: _cashVsNoncash['noncash']!),
          const SizedBox(height: 24),

          if (_incomeByCategory.isNotEmpty)
            ExpansionTile(
              title: Text(t.incomeByCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              initiallyExpanded: false,
              children: [
                CategoriesColumn(
                  data: _incomeByCategory,
                  total: _totalIncome,
                  color: Colors.green,
                  companyId: widget.companyId,
                  startDate: _startDate,
                  endDate: _endDate,
                  type: 'income',
                  categories: widget.categories,
                ),
              ],
            ),

          if (_expenseByCategory.isNotEmpty)
            ExpansionTile(
              title: Text(t.expenseByCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              initiallyExpanded: false,
              children: [
                CategoriesColumn(
                  data: _expenseByCategory,
                  total: _totalExpense,
                  color: Colors.red,
                  companyId: widget.companyId,
                  startDate: _startDate,
                  endDate: _endDate,
                  type: 'expense',
                  categories: widget.categories,
                ),
              ],
            ),

          ExpansionTile(
            title: Text(t.productIncomeExpense, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              ProductTables(productIncome: _productIncome, productConsumption: _productConsumption),
            ],
          ),

          ExpansionTile(
            title: Text(t.productMovementTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              ProductMovementReport(companyId: widget.companyId),
            ],
          ),

          ExpansionTile(
            title: Text(t.sales, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              SalesTables(
                productSales: _productSales,
                showcaseSales: _showcaseSales,
                activeTab: _activeSalesTab,
                onTabChanged: (value) => setState(() => _activeSalesTab = value),
              ),
            ],
          ),

          ExpansionTile(
            title: Text(t.materialConsumptionInOrders, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              MaterialConsumptionWidget(
                companyId: widget.companyId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ],
          ),

          ExpansionTile(
            title: Text(t.orderStatistics, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              OrderStatsWidget(
                companyId: widget.companyId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ],
          ),

          ExpansionTile(
            title: Text(t.counterparties, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: false,
            children: [
              CounterpartiesReportWidget(
                companyId: widget.companyId,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ],
          ),
          ExpansionTile(
  title: Text(t.exportToExcel),
  leading: const Icon(Icons.download),
  initiallyExpanded: false,
  children: [
    ExpansionTile(
      leading: const Icon(Icons.receipt),
      title: Text(t.operationsExportTitle),
      children: [OperationsExportWidget(companyId: widget.companyId)],
    ),
    ExpansionTile(
      leading: const Icon(Icons.inventory),
      title: Text(t.productMovementTitle),
      children: [ProductMovementReport(companyId: widget.companyId)],
    ),
    ExpansionTile(
      leading: const Icon(Icons.people),
      title: Text(t.counterpartyMovementTitle),
      children: [CounterpartyMovementReport(companyId: widget.companyId)],
    ),
    ExpansionTile(
      leading: const Icon(Icons.money),
      title: Text(t.cashMovementTitle),
      children: [CashAccountMovementReport(companyId: widget.companyId)],
    ),
    ExpansionTile(
      leading: const Icon(Icons.account_balance),
      title: Text(t.bankMovementTitle),
      children: [BankAccountMovementReport(companyId: widget.companyId)],
    ),
  ],
),

          
        ],
      ),
    );
  }
}