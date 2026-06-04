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
  int? _selectedShowcaseItemId;
  String? _selectedShowcaseItemName;
  int _quantity = 1;
  double _totalAmount = 0.0;
  bool _loadingShowcase = false;
  List<Map<String, dynamic>> _showcaseItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      // Редактирование: парсим даты и приводим к локальному времени
      _startDateTime = DateTime.parse(widget.initialEntry['datetime_start']).toLocal();
      _endDateTime = DateTime.parse(widget.initialEntry['datetime_end']).toLocal();
      _descriptionController.text = widget.initialEntry['description'] ?? '';
      _counterpartyController.text = widget.initialEntry['counterparty'] ?? '';
      _selectedShowcaseItemId = widget.initialEntry['showcase_item_id'];
      _quantity = widget.initialEntry['quantity'] ?? 1;
      _totalAmount = widget.initialEntry['total_amount'] ?? 0.0;
    } else {
      // Новая запись: берём дату из выбранного дня в календаре
      final baseDate = widget.initialDate ?? DateTime.now();
      // Устанавливаем начало на 10:00, конец на 11:00 (можно изменить)
      _startDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, 10, 0);
      _endDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, 11, 0);
    }
    _loadShowcaseItems();
  }

  Future<void> _loadShowcaseItems() async {
    setState(() => _loadingShowcase = true);
    try {
      final api = ApiClient();
      final res = await api.get('/showcase', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _showcaseItems = List<Map<String, dynamic>>.from(res.data);
        if (_selectedShowcaseItemId != null) {
          final found = _showcaseItems.firstWhere(
            (i) => i['id'] == _selectedShowcaseItemId,
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) _selectedShowcaseItemName = found['name'];
        }
        _loadingShowcase = false;
      });
    } catch (e) {
      setState(() => _loadingShowcase = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
  final initialTime = TimeOfDay.fromDateTime(isStart ? _startDateTime : _endDateTime);
  final picked = await showTimePicker(
    context: context,
    initialTime: initialTime,
    // builder убран
  );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.endTimeAfterStart)),
          );
          _endDateTime = _startDateTime.add(const Duration(hours: 1));
        }
      }
    });
  }
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
          children: [
            // Отображаем дату (только для информации, нередактируемая)
            ListTile(
              title: Text(t.dateLabel),
              trailing: Text(DateFormat('dd.MM.yyyy').format(_startDateTime)),
            ),
            const SizedBox(height: 8),
            // Время начала
            ListTile(
              title: Text(t.startTime),
              trailing: Text(DateFormat('HH:mm').format(_startDateTime)),
              onTap: () => _selectTime(true),
            ),
            // Время окончания
            ListTile(
              title: Text(t.endTime),
              trailing: Text(DateFormat('HH:mm').format(_endDateTime)),
              onTap: () => _selectTime(false),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: t.description),
            ),
            TextField(
              controller: _counterpartyController,
              decoration: InputDecoration(labelText: t.counterpartyOptional),
            ),
            if (widget.permissions.contains('sell_from_showcase') || widget.permissions.contains('view_showcase'))
              Column(
                children: [
                  DropdownButtonFormField<int>(
                    value: _selectedShowcaseItemId,
                    decoration: InputDecoration(labelText: t.serviceFromShowcaseOptional),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      ..._showcaseItems.map((item) => DropdownMenuItem(
                        value: item['id'],
                        child: Text('${item['name']} (${item['price']} ${t.currencySymbol})'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedShowcaseItemId = value;
                        final found = _showcaseItems.firstWhere(
                          (i) => i['id'] == value,
                          orElse: () => <String, dynamic>{},
                        );
                        _selectedShowcaseItemName = found.isNotEmpty ? found['name'] : null;
                        if (value != null && found.isNotEmpty) {
                          _totalAmount = (found['price'] as num).toDouble() * _quantity;
                        } else {
                          _totalAmount = 0.0;
                        }
                      });
                    },
                  ),
                  if (_selectedShowcaseItemId != null)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _quantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: t.quantityLabel),
                            onChanged: (value) {
                              final qty = int.tryParse(value) ?? 1;
                              setState(() {
                                _quantity = qty;
                                if (_selectedShowcaseItemId != null) {
                                  final found = _showcaseItems.firstWhere(
                                    (i) => i['id'] == _selectedShowcaseItemId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (found.isNotEmpty) {
                                    _totalAmount = (found['price'] as num).toDouble() * qty;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: _totalAmount.toStringAsFixed(2),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(labelText: t.totalAmount),
                            onChanged: (value) {
                              final amount = double.tryParse(value) ?? 0.0;
                              setState(() => _totalAmount = amount);
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            if (_selectedShowcaseItemId == null)
              TextFormField(
                initialValue: _totalAmount.toStringAsFixed(2),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.totalAmount),
                onChanged: (value) {
                  _totalAmount = double.tryParse(value) ?? 0.0;
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
  'showcaseItemId': _selectedShowcaseItemId,
  'quantity': _quantity,
  'totalAmount': _totalAmount,
});
          },
          child: Text(isEdit ? t.save : t.create),
        ),
      ],
    );
  }
}