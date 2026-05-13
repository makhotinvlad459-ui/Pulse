import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class RecipeEditor extends ConsumerStatefulWidget {
  final int companyId;
  final List<Map<String, dynamic>> initialItems;
  final void Function(List<Map<String, dynamic>>) onChanged;

  const RecipeEditor({
    super.key,
    required this.companyId,
    required this.initialItems,
    required this.onChanged,
  });

  @override
  ConsumerState<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends ConsumerState<RecipeEditor> {
  List<Map<String, dynamic>> _items = [];
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialItems);
  }

  void _notifyChange() {
    widget.onChanged(_items);
  }

  String _translateUnit(String unit, AppLocalizations t) {
    switch (unit) {
      case 'шт': return t.unitPcs;
      case 'кг': return t.unitKg;
      case 'г': return t.unitGram;
      case 'л': return t.unitLiter;
      case 'мл': return t.unitMl;
      case 'м': return t.unitMeter;
      case 'см': return t.unitCm;
      case 'дюймы': return t.unitInch;
      case 'упаковка': return t.unitPack;
      default: return unit;
    }
  }

  Future<void> _addIngredient() async {
    final t = AppLocalizations.of(context)!;
    List<dynamic> products = [];
    final colorScheme = Theme.of(context).colorScheme;
    try {
      final res = await _api.get('/products', queryParameters: {'company_id': widget.companyId});
      products = res.data;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      return;
    }

    int? selectedProductId;
    double quantity = 0;
    final quantityController = TextEditingController();
    String? selectedProductName;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(t.addIngredient, style: TextStyle(color: colorScheme.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: t.productLabel,
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(color: colorScheme.onSurface),
                  items: products.map((p) {
                    final unitTranslated = _translateUnit(p['unit'], t);
                    return DropdownMenuItem<int>(
                      value: p['id'],
                      child: Text('${p['name']} (${t.remainingStock}: ${p['current_quantity']} $unitTranslated)'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setStateDialog(() {
                      selectedProductId = v;
                      selectedProductName = products.firstWhere((p) => p['id'] == v)['name'];
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: t.quantityLabel,
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
              ElevatedButton(
                onPressed: () {
                  final q = double.tryParse(quantityController.text);
                  if (selectedProductId == null || q == null || q <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fillAllFields)));
                    return;
                  }
                  setState(() {
                    _items.add({
                      'product_id': selectedProductId,
                      'product_name': selectedProductName,
                      'quantity': q,
                    });
                    _notifyChange();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: Text(t.add),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeIngredient(int index) {
    setState(() {
      _items.removeAt(index);
      _notifyChange();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: Text(t.addIngredient),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary.withOpacity(0.2),
                  foregroundColor: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isNotEmpty) ...[
          Text(t.ingredients, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _items.asMap().entries.map((entry) {
              final idx = entry.key;
              final ing = entry.value;
              return Chip(
                label: Text('${ing['product_name']} (${ing['quantity']} ${t.pcs})',
                    style: TextStyle(color: colorScheme.onSurface)),
                onDeleted: () => _removeIngredient(idx),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey),
                backgroundColor: colorScheme.surfaceContainerHighest,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}