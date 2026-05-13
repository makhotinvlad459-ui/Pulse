import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class MaterialConsumptionWidget extends ConsumerStatefulWidget {
  final int companyId;
  final DateTime startDate;
  final DateTime endDate;
  const MaterialConsumptionWidget({super.key, required this.companyId, required this.startDate, required this.endDate});

  @override
  ConsumerState<MaterialConsumptionWidget> createState() => _MaterialConsumptionWidgetState();
}

class _MaterialConsumptionWidgetState extends ConsumerState<MaterialConsumptionWidget> {
  List<dynamic> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MaterialConsumptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/statistics/order-materials-consumption', queryParameters: {
        'company_id': widget.companyId,
        'start_date': widget.startDate.toIso8601String(),
        'end_date': widget.endDate.toIso8601String(),
      });
      setState(() {
        _data = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      print(e);
    }
  }

  Future<void> _exportToExcel() async {
    if (_data.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    var excel = Excel.createExcel();
    var sheet = excel.sheets.values.first;
    sheet.rows.clear();

    // Заголовки
    sheet.appendRow([
      t.materialColumn,
      t.unitColumn,
      t.quantityColumn,
      t.costColumn,
    ]);

    for (var item in _data) {
      final name = item['name'];
      final unit = item['unit'];
      final quantity = (item['total_quantity'] as num).toDouble();
      final cost = (item['total_cost'] as num).toDouble();
      sheet.appendRow([
        name,
        unit,
        quantity.toStringAsFixed(2),
        cost.toStringAsFixed(2),
      ]);
    }

    // Итоговая строка
    double totalQuantity = 0, totalCost = 0;
    for (var d in _data) {
      totalQuantity += (d['total_quantity'] as num).toDouble();
      totalCost += (d['total_cost'] as num).toDouble();
    }
    sheet.appendRow([
      t.totalLabel,
      '',
      totalQuantity.toStringAsFixed(2),
      totalCost.toStringAsFixed(2),
    ]);

    final bytes = excel.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'material_consumption.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/material_consumption_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: t.exportReport);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;
    if (_loading) return const CircularProgressIndicator();
    if (_data.isEmpty) return Text(t.noMaterialData, style: TextStyle(color: colorScheme.onSurfaceVariant));
    double totalQuantity = 0, totalCost = 0;
    for (var d in _data) {
      totalQuantity += (d['total_quantity'] as num).toDouble();
      totalCost += (d['total_cost'] as num).toDouble();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.materialConsumptionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: const Icon(Icons.download),
              label: Text(t.exportToExcel),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(colorScheme.primary),
            headingTextStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
            columns: [
              DataColumn(label: Text(t.materialColumn)),
              DataColumn(label: Text(t.unitColumn)),
              DataColumn(label: Text(t.quantityColumn)),
              DataColumn(label: Text(t.costColumn)),
            ],
            rows: [
              ..._data.map((item) {
                return DataRow(cells: [
                  DataCell(Text(item['name'], style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text(item['unit'], style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text((item['total_quantity'] as num).toStringAsFixed(2), style: TextStyle(color: colorScheme.onSurface))),
                  DataCell(Text('${(item['total_cost'] as num).toStringAsFixed(2)}$currency', style: TextStyle(color: colorScheme.onSurface))),
                ]);
              }).toList(),
              DataRow(
                cells: [
                  DataCell(Text(t.totalLabel, style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataCell(Text('')),
                  DataCell(Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
                  DataCell(Text('${totalCost.toStringAsFixed(2)}$currency', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}