import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
Widget build(BuildContext context) {
  ref.watch(localeProvider);
  final t = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;
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
      Text(t.materialConsumptionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                DataCell(Text('${(item['total_cost'] as num).toStringAsFixed(2)} ₽', style: TextStyle(color: colorScheme.onSurface))),
              ]);
            }).toList(),
            DataRow(
              cells: [
                DataCell(Text(t.totalLabel, style: TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                DataCell(Text(totalQuantity.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
                DataCell(Text('${totalCost.toStringAsFixed(2)} ₽', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface))),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
}