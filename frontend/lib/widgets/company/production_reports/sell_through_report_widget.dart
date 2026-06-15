import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SellThroughReportWidget extends ConsumerStatefulWidget {
  final int companyId;
  const SellThroughReportWidget({super.key, required this.companyId});

  @override
  ConsumerState<SellThroughReportWidget> createState() => _SellThroughReportWidgetState();
}

class _SellThroughReportWidgetState extends ConsumerState<SellThroughReportWidget> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/production/sell-through-report', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      
      setState(() {
        _items = List<Map<String, dynamic>>.from(res.data);
        // Ограничиваем процент до 100%
        for (var item in _items) {
          double percent = (item['sell_through_percent'] ?? 0).toDouble();
          if (percent > 100) percent = 100;
          item['sell_through_percent'] = percent;
        }
        // Сортируем по убыванию процента
        _items.sort((a, b) => (b['sell_through_percent'] ?? 0).compareTo(a['sell_through_percent'] ?? 0));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _selectPeriod() async {
    final t = AppLocalizations.of(context)!;
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
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _exportToExcel() async {
    if (_items.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    sheet.appendRow([
      t.productColumn,
      t.producedLabel,
      t.soldLabel,
      t.currentStockLabel,
      t.sellThroughPercent,
    ]);

    for (var item in _items) {
      final name = item['product_name'] ?? '';
      final unit = item['unit'] ?? 'шт';
      final produced = item['produced_quantity'] ?? 0;
      final sold = item['sold_quantity'] ?? 0;
      final stock = item['current_stock'] ?? 0;
      final percent = item['sell_through_percent'] ?? 0;
      sheet.appendRow([name, '$produced $unit', '$sold $unit', '$stock $unit', '${percent.toStringAsFixed(1)}%']);
    }

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'sell_through_report.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/sell_through_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: t.exportReport);
      }
    }
  }

  Color _getPercentColor(double percent) {
    if (percent >= 70) return Colors.green;
    if (percent >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    double totalProduced = 0;
    double totalSold = 0;
    for (var item in _items) {
      totalProduced += (item['produced_quantity'] ?? 0).toDouble();
      totalSold += (item['sold_quantity'] ?? 0).toDouble();
    }
    final double totalPercent = totalProduced > 0 ? (totalSold / totalProduced * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _selectPeriod,
                icon: Icon(Icons.calendar_today, color: colorScheme.onSurfaceVariant),
                label: Text(
                  '${DateFormat('dd.MM.yyyy').format(_startDate)} - ${DateFormat('dd.MM.yyyy').format(_endDate)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download),
              label: Text(t.exportToExcel),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_items.isEmpty)
          Center(child: Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant)))
        else
          Column(
            children: [
              // Карточка с общей статистикой
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(t.producedLabel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('${totalProduced.toStringAsFixed(1)} ${t.unitPcs}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(t.soldLabel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('${totalSold.toStringAsFixed(1)} ${t.unitPcs}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(t.sellThroughPercent, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('${totalPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getPercentColor(totalPercent),
                            )),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Таблица с деталями
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(colorScheme.primary),
                  headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  columns: [
                    DataColumn(label: Text(t.productColumn)),
                    DataColumn(label: Text(t.producedLabel)),
                    DataColumn(label: Text(t.soldLabel)),
                    DataColumn(label: Text(t.currentStockLabel)),
                    DataColumn(label: Text(t.sellThroughPercent)),
                  ],
                  rows: _items.map((item) {
                    final name = item['product_name'] ?? '';
                    final unit = item['unit'] ?? 'шт';
                    final produced = (item['produced_quantity'] ?? 0).toDouble();
                    final sold = (item['sold_quantity'] ?? 0).toDouble();
                    final stock = (item['current_stock'] ?? 0).toDouble();
                    final percent = (item['sell_through_percent'] ?? 0).toDouble();
                    return DataRow(cells: [
                      DataCell(Text(name, style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text('${produced.toStringAsFixed(2)} $unit', style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text('${sold.toStringAsFixed(2)} $unit', style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(Text('${stock.toStringAsFixed(2)} $unit', style: TextStyle(color: colorScheme.onSurface))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPercentColor(percent).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${percent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _getPercentColor(percent),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
      ],
    );
  }
}