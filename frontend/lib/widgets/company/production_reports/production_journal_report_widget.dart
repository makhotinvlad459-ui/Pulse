import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ProductionJournalReportWidget extends ConsumerStatefulWidget {
  final int companyId;
  const ProductionJournalReportWidget({super.key, required this.companyId});

  @override
  ConsumerState<ProductionJournalReportWidget> createState() => _ProductionJournalReportWidgetState();
}

class _ProductionJournalReportWidgetState extends ConsumerState<ProductionJournalReportWidget> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  Map<int, String> _productNames = {};
  Set<String> _creators = {};
  String? _selectedCreator;
  bool _loading = false;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _api.get('/production/products', queryParameters: {'company_id': widget.companyId});
      final List<dynamic> products = res.data;
      for (var p in products) {
        _productNames[p['id']] = p['name'];
      }
      await _loadData();
    } catch (e) {
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('/production/journal', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });
      
      final List<dynamic> data = res.data;
      
      Set<String> creators = {};
      final t = AppLocalizations.of(context)!;
      
      for (var entry in data) {
        final creatorRaw = entry['creator_name'] ?? '';
        String creator;
        if (creatorRaw == 'Основатель') {
          creator = t.founderRole;
        } else if (creatorRaw.isEmpty) {
          creator = t.unknown;
        } else {
          creator = creatorRaw;
        }
        if (creator.isNotEmpty && creator != t.unknown) creators.add(creator);
        
        final productId = entry['product_id'];
        if (_productNames[productId] == null && productId != null) {
          try {
            final prodRes = await _api.get('/production/products/$productId', queryParameters: {'company_id': widget.companyId});
            _productNames[productId] = prodRes.data['name'];
          } catch (_) {}
        }
      }
      
      setState(() {
        _entries = List<Map<String, dynamic>>.from(data);
        _filteredEntries = List.from(_entries);
        _creators = creators;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  void _filterByCreator(String? creator) {
    setState(() {
      _selectedCreator = creator;
      if (creator == null || creator.isEmpty) {
        _filteredEntries = List.from(_entries);
      } else {
        _filteredEntries = _entries.where((entry) {
          final entryCreator = _translateCreator(entry['creator_name'] ?? '');
          return entryCreator == creator;
        }).toList();
      }
    });
  }

  Future<void> _selectPeriod() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: Localizations.localeOf(context),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
      });
      await _loadData();
    }
  }

  Future<void> _exportToExcel() async {
    if (_filteredEntries.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excelFile = excel.Excel.createExcel();
    var sheet = excelFile.sheets.values.first;
    sheet.rows.clear();

    sheet.appendRow([t.dateLabel, t.productColumn, t.quantity, t.shift, t.createdByLabel]);

    for (var entry in _filteredEntries) {
      final productId = entry['product_id'];
      final productName = _productNames[productId] ?? entry['product_name'] ?? 'ID:$productId';
      final date = DateFormat('dd.MM.yyyy').format(DateTime.parse(entry['production_date']));
      final quantity = entry['actual_quantity'] ?? entry['planned_quantity'] ?? 0;
      final shift = entry['shift'] == 'day' ? t.dayShift : t.nightShift;
      final creator = _translateCreator(entry['creator_name'] ?? '');
      sheet.appendRow([date, productName, quantity, shift, creator]);
    }

    final bytes = excelFile.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'production_journal.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/production_journal_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: t.exportReport);
      }
    }
  }

  String _translateCreator(String creator) {
    final t = AppLocalizations.of(context)!;
    if (creator == 'Основатель') return t.founderRole;
    if (creator.isEmpty) return t.unknown;
    return creator;
  }

  Widget _buildInfoChip(IconData icon, String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // Группировка по продуктам
    final Map<String, double> productTotals = {};
    for (var entry in _filteredEntries) {
      final productId = entry['product_id'];
      final name = _productNames[productId] ?? entry['product_name'] ?? 'ID:$productId';
      final qty = (entry['actual_quantity'] ?? entry['planned_quantity'] ?? 0).toDouble();
      productTotals[name] = (productTotals[name] ?? 0) + qty;
    }
    final double totalQuantity = productTotals.values.fold(0, (sum, q) => sum + q);

    // Подсчет по создателям с количеством смен
    final Map<String, double> creatorTotals = {};
    final Map<String, Set<String>> creatorShifts = {};
    
    for (var entry in _filteredEntries) {
      final creator = _translateCreator(entry['creator_name'] ?? '');
      final qty = (entry['actual_quantity'] ?? entry['planned_quantity'] ?? 0).toDouble();
      creatorTotals[creator] = (creatorTotals[creator] ?? 0) + qty;
      
      final date = DateFormat('yyyy-MM-dd').format(DateTime.parse(entry['production_date']));
      final shift = entry['shift'] == 'day' ? t.dayShift : t.nightShift;
      creatorShifts.putIfAbsent(creator, () => {}).add('$date-$shift');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Панель фильтров
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _selectPeriod,
              icon: Icon(Icons.calendar_today, size: 18, color: colorScheme.onSurfaceVariant),
              label: Text(
                '${DateFormat('dd.MM.yy').format(_startDate)} - ${DateFormat('dd.MM.yy').format(_endDate)}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
            // Фильтр по создателю
            if (_creators.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedCreator,
                  hint: Text(t.filterByCreator, style: const TextStyle(fontSize: 12)),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все', style: TextStyle(fontSize: 12))),
                    ..._creators.map((creator) => DropdownMenuItem(
                      value: creator,
                      child: Text(creator, style: const TextStyle(fontSize: 12)),
                    )),
                  ],
                  onChanged: _filterByCreator,
                ),
              ),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download, size: 16),
              label: Text(t.exportToExcel),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_filteredEntries.isEmpty)
          Center(child: Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant)))
        else
          Column(
            children: [
              // Сводка по продуктам
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(t.byProduct, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...productTotals.entries.map((entry) {
                        final percent = totalQuantity == 0 ? 0 : (entry.value / totalQuantity * 100);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))),
                              Text('${entry.value.toStringAsFixed(1)} ${t.unitPcs}', style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '${percent.toStringAsFixed(1)}%',
                                  style: TextStyle(fontSize: 13, color: Colors.green.shade600, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Сводка по сотрудникам
              if (creatorTotals.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(t.byCreator, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...creatorTotals.entries.map((entry) {
                          final creatorName = entry.key;
                          final totalQuantityValue = entry.value;
                          final shiftsCount = creatorShifts[creatorName]?.length ?? 0;
                          final avgPerShift = shiftsCount > 0 ? totalQuantityValue / shiftsCount : 0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        creatorName, 
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.primary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '${totalQuantityValue.toStringAsFixed(1)} ${t.unitPcs}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildInfoChip(Icons.calendar_today, '${t.shiftsCount ?? "Смен"}: $shiftsCount', colorScheme),
                                    const SizedBox(width: 12),
                                    _buildInfoChip(Icons.speed, '${t.avgPerShift ?? "Средняя"}: ${avgPerShift.toStringAsFixed(1)} ${t.unitPcs}', colorScheme),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Детальная таблица
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(colorScheme.primary),
                  headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                  dataRowMaxHeight: 48,
                  columns: [
                    DataColumn(label: Text(t.dateLabel, style: const TextStyle(fontSize: 12))),
                    DataColumn(label: Text(t.productColumn, style: const TextStyle(fontSize: 12))),
                    DataColumn(label: Text(t.quantity, style: const TextStyle(fontSize: 12))),
                    DataColumn(label: Text(t.shift, style: const TextStyle(fontSize: 12))),
                    DataColumn(label: Text(t.createdByLabel, style: const TextStyle(fontSize: 12))),
                  ],
                  rows: _filteredEntries.map((entry) {
                    final productId = entry['product_id'];
                    final productName = _productNames[productId] ?? entry['product_name'] ?? 'ID:$productId';
                    final date = DateFormat('dd.MM.yy').format(DateTime.parse(entry['production_date']));
                    final quantity = entry['actual_quantity'] ?? entry['planned_quantity'] ?? 0;
                    final shift = entry['shift'] == 'day' ? t.dayShift : t.nightShift;
                    final creator = _translateCreator(entry['creator_name'] ?? '');
                    return DataRow(cells: [
                      DataCell(Text(date, style: TextStyle(fontSize: 12, color: colorScheme.onSurface))),
                      DataCell(Text(productName, style: TextStyle(fontSize: 12, color: colorScheme.onSurface))),
                      DataCell(Text(quantity.toString(), style: TextStyle(fontSize: 12, color: colorScheme.onSurface))),
                      DataCell(Text(shift, style: TextStyle(fontSize: 12, color: colorScheme.onSurface))),
                      DataCell(Text(creator, style: TextStyle(fontSize: 12, color: colorScheme.onSurface))),
                    ]);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
      ],
    );
  }
}