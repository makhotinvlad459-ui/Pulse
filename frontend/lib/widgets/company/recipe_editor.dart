import 'package:flutter/material.dart';
import 'dart:convert';
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
            title: const Text('Добавить ингредиент'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Товар'),
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
                  decoration: const InputDecoration(labelText: 'Количество'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isNotEmpty) ...[
          const Text('Ингредиенты:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _items.asMap().entries.map((entry) {
              final idx = entry.key;
              final ing = entry.value;
              return Chip(
                label: Text('${ing['product_name']} (${ing['quantity']} шт)'),
                onDeleted: () => _removeIngredient(idx),
                deleteIcon: const Icon(Icons.close, size: 16),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}