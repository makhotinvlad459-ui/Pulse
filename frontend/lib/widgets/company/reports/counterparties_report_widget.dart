import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CounterpartiesReportWidget extends ConsumerStatefulWidget {
  final int companyId;
  final DateTime startDate;
  final DateTime endDate;
  const CounterpartiesReportWidget({super.key, required this.companyId, required this.startDate, required this.endDate});

  @override
  ConsumerState<CounterpartiesReportWidget> createState() => _CounterpartiesReportWidgetState();
}

class _CounterpartiesReportWidgetState extends ConsumerState<CounterpartiesReportWidget> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant CounterpartiesReportWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/statistics/counterparties-report', queryParameters: {
        'company_id': widget.companyId,
        'start_date': widget.startDate.toIso8601String(),
        'end_date': widget.endDate.toIso8601String(),
      });
      setState(() {
        _data = List<Map<String, dynamic>>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;
    if (_loading) return const CircularProgressIndicator();
    if (_data.isEmpty) return Text(t.noCounterpartiesPeriod, style: TextStyle(color: colorScheme.onSurfaceVariant));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(colorScheme.primary),
        headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
        columns: [
          DataColumn(label: Text(t.counterpartyLabel)),
          DataColumn(label: Text('${t.income}$currency')),
          DataColumn(label: Text('${t.expense}$currency')),
          DataColumn(label: Text('${t.balance}$currency')),
        ],
        rows: _data.map((row) {
          final balance = row['balance'] as double;
          return DataRow(cells: [
            DataCell(Text(row['name'], style: TextStyle(color: colorScheme.onSurface))),
            DataCell(Text(row['total_income'].toStringAsFixed(2), style: TextStyle(color: Colors.green))),
            DataCell(Text(row['total_expense'].toStringAsFixed(2), style: TextStyle(color: Colors.red))),
            DataCell(Text(balance.toStringAsFixed(2), style: TextStyle(color: balance >= 0 ? Colors.green : Colors.red))),
          ]);
        }).toList(),
      ),
    );
  }
}