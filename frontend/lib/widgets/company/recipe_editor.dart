import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class RecipeEditor extends StatefulWidget {
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
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
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

  Future<void> _addIngredient() async {
    List<dynamic> products = [];
    final colorScheme = Theme.of(context).colorScheme;
    try {
      final res = await _api.get('/products', queryParameters: {'company_id': widget.companyId});
      products = res.data;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки товаров: $e')));
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
            title: Text('Добавить ингредиент', style: TextStyle(color: colorScheme.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Товар',
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
                    return DropdownMenuItem<int>(
                      value: p['id'],
                      child: Text('${p['name']} (остаток: ${p['current_quantity']} ${p['unit']})'),
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
                    labelText: 'Количество',
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
                  child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant))),
              ElevatedButton(
                onPressed: () {
                  final q = double.tryParse(quantityController.text);
                  if (selectedProductId == null || q == null || q <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
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
                child: const Text('Добавить'),
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
    final colorScheme = Theme.of(context).colorScheme;

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
                label: const Text('Добавить ингредиент'),
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
          Text('Ингредиенты:', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _items.asMap().entries.map((entry) {
              final idx = entry.key;
              final ing = entry.value;
              return Chip(
                label: Text('${ing['product_name']} (${ing['quantity']} шт)',
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