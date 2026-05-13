import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class OrderStatsWidget extends ConsumerStatefulWidget {
  final int companyId;
  final DateTime startDate;
  final DateTime endDate;
  const OrderStatsWidget({super.key, required this.companyId, required this.startDate, required this.endDate});

  @override
  ConsumerState<OrderStatsWidget> createState() => _OrderStatsWidgetState();
}

class _OrderStatsWidgetState extends ConsumerState<OrderStatsWidget> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant OrderStatsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/statistics/order-stats', queryParameters: {
        'company_id': widget.companyId,
        'start_date': widget.startDate.toIso8601String(),
        'end_date': widget.endDate.toIso8601String(),
      });
      setState(() {
        _stats = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      print(e);
    }
  }

  String _statusName(String status, AppLocalizations t) {
    switch (status) {
      case 'pending': return t.pendingStatus;
      case 'accepted': return t.acceptedStatus;
      case 'completed': return t.completedStatus;
      case 'failed': return t.failedStatus;
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;
    if (_loading) return const CircularProgressIndicator();
    if (_stats.isEmpty) return Text(t.noOrderData, style: TextStyle(color: colorScheme.onSurfaceVariant));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.orderStatisticsTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _stats.entries.map((entry) {
            final status = entry.key;
            final data = entry.value;
            final count = data['count'] ?? 0;
            final totalSum = (data['total_sum'] as num?)?.toDouble() ?? 0;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(_statusName(status, t), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${t.quantityLabelLower}: $count', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    Text('${t.amountLabelLower}: ${totalSum.toStringAsFixed(2)}$currency', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}