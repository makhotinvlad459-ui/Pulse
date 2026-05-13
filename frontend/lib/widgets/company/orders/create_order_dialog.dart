import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'add_material_dialog.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CreateOrderDialog extends ConsumerStatefulWidget {
  final int companyId;
  final List<Map<String, dynamic>> members;
  final VoidCallback onOrderCreated;

  const CreateOrderDialog({
    super.key,
    required this.companyId,
    required this.members,
    required this.onOrderCreated,
  });

  @override
  ConsumerState<CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends ConsumerState<CreateOrderDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _workPriceController = TextEditingController();
  int? _assigneeId;
  DateTime? _deadline;
  List<Map<String, dynamic>> _items = [];
  List<dynamic> _products = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final api = ApiClient();
    try {
      final res = await api.get('/products/', queryParameters: {'company_id': widget.companyId});
      if (mounted) {
        setState(() {
          _products = res.data;
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProducts = false);
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _createOrder() async {
    final t = AppLocalizations.of(context)!;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.enterTitle)));
      return;
    }
    final api = ApiClient();
    try {
      final orderItems = _items.map((i) => ({
        'product_id': i['product_id'],
        'quantity': i['quantity'],
        'unit_price': i['unit_price'],
        'use_from_stock': i['use_from_stock'],
      })).toList();
      await api.post('/orders', queryParameters: {'company_id': widget.companyId}, data: {
        'title': _titleController.text,
        'description': _descController.text,
        'work_price': double.tryParse(_workPriceController.text) ?? 0,
        'assignee_id': _assigneeId,
        'deadline': _deadline?.toIso8601String(),
        'items': orderItems,
      });
      widget.onOrderCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;

    return AlertDialog(
      title: Text(t.newOrderTitle, style: TextStyle(color: colorScheme.onSurface)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: t.titleRequired, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                decoration: InputDecoration(labelText: t.descriptionLabel, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _workPriceController,
                decoration: InputDecoration(labelText: t.workPrice, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(labelText: t.assignResponsible, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface),
                items: [
                  DropdownMenuItem(value: null, child: Text(t.notAssigned)),
                  ...widget.members.map((m) => DropdownMenuItem(
                    value: m['id'],
                    child: Text(m['full_name']),
                  )),
                ],
                onChanged: (v) => _assigneeId = v,
              ),
              const SizedBox(height: 8),
              ListTile(
                title: Text(t.deadlineLabel, style: TextStyle(color: colorScheme.onSurface)),
                trailing: Text(_deadline == null ? t.notSelected : DateFormat('dd.MM.yyyy').format(_deadline!),
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
              ),
              const Divider(),
              Row(
                children: [
                  Text(t.materialsLabel, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const Spacer(),
                  if (!_loadingProducts)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final newItem = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (context) => AddMaterialDialog(
                            products: _products,
                            companyId: widget.companyId,
                          ),
                        );
                        if (newItem != null) {
                          setState(() => _items.add(newItem));
                        }
                      },
                    ),
                ],
              ),
              if (_loadingProducts)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              if (_items.isNotEmpty)
                Column(
                  children: _items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final it = entry.value;
                    return ListTile(
                      dense: true,
                      title: Text(it['product_name'], style: TextStyle(color: colorScheme.onSurface)),
                      subtitle: Text('${it['quantity']} ${t.pcs} × ${it['unit_price']}$currency = ${it['total']}$currency'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _items.removeAt(idx)),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              if (_items.isNotEmpty)
                Text('${t.materialsTotal}: ${_items.fold<double>(0, (s, i) => s + i['total']).toStringAsFixed(2)}$currency',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ElevatedButton(
          onPressed: _createOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Text(t.createButton),
        ),
      ],
    );
  }
}