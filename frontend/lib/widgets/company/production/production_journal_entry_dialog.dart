import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../l10n/app_localizations.dart';

class ProductionJournalEntryDialog extends StatefulWidget {
  final int companyId;
  final DateTime? initialDate;
  final dynamic initialEntry;
  final Set<String> permissions;
  final List<dynamic> products;

  const ProductionJournalEntryDialog({
    super.key,
    required this.companyId,
    this.initialDate,
    this.initialEntry,
    required this.permissions,
    required this.products,
  });

  @override
  State<ProductionJournalEntryDialog> createState() => _ProductionJournalEntryDialogState();
}

class _ProductionJournalEntryDialogState extends State<ProductionJournalEntryDialog> {
  late DateTime _productionDate;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _shift = 'day';
  Map<String, dynamic>? _selectedProduct;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEntry != null) {
      _productionDate = DateTime.parse(widget.initialEntry['production_date']).toLocal();
      _quantityController.text = widget.initialEntry['actual_quantity'].toString();
      _notesController.text = widget.initialEntry['notes'] ?? '';
      _shift = widget.initialEntry['shift'] ?? 'day';
      final productId = widget.initialEntry['product_id'];
      final product = widget.products.firstWhere(
        (p) => p['id'] == productId,
        orElse: () => null,
      );
      _selectedProduct = product as Map<String, dynamic>?;
    } else {
      _productionDate = widget.initialDate ?? DateTime.now();
      _quantityController.text = '1';
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _productionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _productionDate = picked);
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context)!;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.selectProduct)),
      );
      return;
    }
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.enterValidQuantity)),
      );
      return;
    }

    setState(() => _loading = true);
    final api = ApiClient();

    try {
      final dateStr = _productionDate.toIso8601String().split('.')[0];
      
      if (widget.initialEntry != null) {
        await api.patch('/production/journal/${widget.initialEntry['id']}',
          queryParameters: {'company_id': widget.companyId},
          data: {
            'actual_quantity': quantity,
            'production_date': dateStr,
            'shift': _shift,
            'notes': _notesController.text,
          },
        );
      } else {
        await api.post('/production/produce',
          queryParameters: {'company_id': widget.companyId},
          data: {
            'product_id': _selectedProduct!['id'],
            'quantity': quantity,
            'production_date': dateStr,
            'shift': _shift,
            'notes': _notesController.text,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t.error}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.initialEntry != null;
    final currency = t.currencySymbol;

    return AlertDialog(
      title: Text(isEdit ? t.editProductionEntry : t.newProductionEntry, 
        style: TextStyle(color: colorScheme.onSurface)),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedProduct,
                    decoration: InputDecoration(
                      labelText: t.product,
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(color: colorScheme.onSurface),
                    items: widget.products.map<DropdownMenuItem<Map<String, dynamic>>>((p) {
                      final product = p as Map<String, dynamic>;
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: product,
                        child: Text('${product['name']} (${product['price']}$currency)', 
                          style: TextStyle(color: colorScheme.onSurface)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedProduct = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: t.quantity,
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(t.productionDate, style: TextStyle(color: colorScheme.onSurface)),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(_productionDate), 
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    onTap: _selectDate,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
  segments: [
    ButtonSegment(value: 'day', label: Text(t.dayShift)),
    ButtonSegment(value: 'night', label: Text(t.nightShift)),
  ],
  selected: {_shift},
  onSelectionChanged: (s) => setState(() => _shift = s.first),
),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: t.notes,
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    maxLines: 3,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: Text(isEdit ? t.save : t.create),
        ),
      ],
    );
  }
}