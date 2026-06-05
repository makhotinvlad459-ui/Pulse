import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../l10n/app_localizations.dart';

class JournalEntryDialog extends StatefulWidget {
  final int companyId;
  final DateTime? initialDate;
  final dynamic initialEntry;
  final Set<String> permissions;

  const JournalEntryDialog({
    super.key,
    required this.companyId,
    this.initialDate,
    this.initialEntry,
    required this.permissions,
  });

  @override
  State<JournalEntryDialog> createState() => _JournalEntryDialogState();
}

class _JournalEntryDialogState extends State<JournalEntryDialog> {
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _counterpartyController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loadingShowcase = false;
  List<Map<String, dynamic>> _showcaseItems = [];
  final TextEditingController _manualAmountController = TextEditingController();
  bool _isManualAmountEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      _startDateTime = DateTime.parse(widget.initialEntry['datetime_start']).toLocal();
      _endDateTime = DateTime.parse(widget.initialEntry['datetime_end']).toLocal();
      _descriptionController.text = widget.initialEntry['description'] ?? '';
      _counterpartyController.text = widget.initialEntry['counterparty'] ?? '';
      if (widget.initialEntry['items'] != null) {
        _items = List<Map<String, dynamic>>.from(widget.initialEntry['items']).map((item) {
          final total = item['total'] ?? item['quantity'] * item['price_at_time'];
          return {
            'showcase_item_id': item['showcase_item_id'],
            'quantity': item['quantity'],
            'price_at_time': item['price_at_time'],
            'name': item['name'] ?? 'Без названия',
            'total': total.toDouble(),
          };
        }).toList();
      }
      final total = widget.initialEntry['total_amount'];
      _manualAmountController.text = (total != null ? (total as num).toDouble() : 0.0).toStringAsFixed(2);
    } else {
      final baseDate = widget.initialDate ?? DateTime.now();
      _startDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, 10, 0);
      _endDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, 11, 0);
      _manualAmountController.text = '0.00';
    }
    _loadShowcaseItems();
    _updateManualAmountState();
  }

  void _updateManualAmountState() {
    final hasServices = _items.isNotEmpty;
    setState(() {
      _isManualAmountEnabled = !hasServices;
      if (hasServices) {
        final computed = _items.fold(0.0, (sum, item) => sum + ((item['total'] ?? 0.0) as double));
        _manualAmountController.text = computed.toStringAsFixed(2);
      }
    });
  }

  Future<void> _loadShowcaseItems() async {
    setState(() => _loadingShowcase = true);
    try {
      final api = ApiClient();
      final res = await api.get('/showcase', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _showcaseItems = List<Map<String, dynamic>>.from(res.data);
        _loadingShowcase = false;
      });
    } catch (e) {
      setState(() => _loadingShowcase = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final initialTime = TimeOfDay.fromDateTime(isStart ? _startDateTime : _endDateTime);
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDateTime = DateTime(
            _startDateTime.year, _startDateTime.month, _startDateTime.day,
            picked.hour, picked.minute,
          );
          if (_endDateTime.isBefore(_startDateTime)) {
            _endDateTime = _startDateTime.add(const Duration(hours: 1));
          }
        } else {
          _endDateTime = DateTime(
            _endDateTime.year, _endDateTime.month, _endDateTime.day,
            picked.hour, picked.minute,
          );
          if (_endDateTime.isBefore(_startDateTime)) {
            _endDateTime = _startDateTime.add(const Duration(hours: 1));
          }
        }
      });
    }
  }

  void _addService() async {
    final t = AppLocalizations.of(context)!;
    if (_loadingShowcase) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.loadingServices)));
      return;
    }
    if (_showcaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.noServicesAvailable)));
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.selectService),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _showcaseItems.length,
            itemBuilder: (context, index) {
              final item = _showcaseItems[index];
              return ListTile(
                title: Text(item['name']),
                subtitle: Text('${item['price']} ${t.currencySymbol}'),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _items.add({
          'showcase_item_id': selected['id'],
          'name': selected['name'],
          'quantity': 1,
          'price_at_time': (selected['price'] as num).toDouble(),
          'total': (selected['price'] as num).toDouble(),
        });
        _updateManualAmountState();
      });
    }
  }

  void _removeService(int index) {
    setState(() {
      _items.removeAt(index);
      _updateManualAmountState();
    });
  }

  void _updateService(int index, {int? quantity, double? priceAtTime}) {
    setState(() {
      if (quantity != null) _items[index]['quantity'] = quantity;
      if (priceAtTime != null) _items[index]['price_at_time'] = priceAtTime;
      final qty = _items[index]['quantity'] as int;
      final price = _items[index]['price_at_time'] as double;
      _items[index]['total'] = qty * price;
      _updateManualAmountState();
    });
  }

  double get _finalAmount {
    if (_items.isNotEmpty) {
      return _items.fold(0.0, (sum, item) => sum + ((item['total'] ?? 0.0) as double));
    }
    return double.tryParse(_manualAmountController.text) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.initialEntry != null;

    return AlertDialog(
      title: Text(isEdit ? t.editJournalEntry : t.newJournalEntry, style: TextStyle(color: colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(t.dateLabel),
              trailing: Text(DateFormat('dd.MM.yyyy').format(_startDateTime)),
            ),
            ListTile(
              title: Text(t.startTime),
              trailing: Text(DateFormat('HH:mm').format(_startDateTime)),
              onTap: () => _selectTime(true),
            ),
            ListTile(
              title: Text(t.endTime),
              trailing: Text(DateFormat('HH:mm').format(_endDateTime)),
              onTap: () => _selectTime(false),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: t.description),
            ),
            TextField(
              controller: _counterpartyController,
              decoration: InputDecoration(labelText: t.counterpartyOptional),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(t.services, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addService,
                  icon: const Icon(Icons.add),
                  label: Text(t.addService),
                ),
              ],
            ),
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => _removeService(idx),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item['quantity'].toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: t.quantityLabel, isDense: true),
                              onChanged: (value) {
                                final qty = int.tryParse(value) ?? 1;
                                _updateService(idx, quantity: qty);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: item['price_at_time'].toStringAsFixed(2),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: t.priceLabel, isDense: true),
                              onChanged: (value) {
                                final price = double.tryParse(value) ?? 0.0;
                                _updateService(idx, priceAtTime: price);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${(item['total'] ?? 0.0).toStringAsFixed(2)} ${t.currencySymbol}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.noServicesAdded, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t.totalAmount,
                prefixIcon: const Icon(Icons.attach_money),
                enabled: _isManualAmountEnabled,
              ),
              onChanged: (value) {
                if (_items.isEmpty) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        ElevatedButton(
          onPressed: () {
            if (_endDateTime.isBefore(_startDateTime)) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.endTimeAfterStart)));
              return;
            }
            Navigator.pop(context, {
              'start': _startDateTime,
              'end': _endDateTime,
              'description': _descriptionController.text.trim(),
              'counterparty': _counterpartyController.text.trim(),
              'items': _items.map((item) => {
                'showcase_item_id': item['showcase_item_id'],
                'quantity': item['quantity'],
                'price_at_time': item['price_at_time'],
                'name': item['name'],
              }).toList(),
              'totalAmount': _finalAmount,
            });
          },
          child: Text(isEdit ? t.save : t.create),
        ),
      ],
    );
  }
}