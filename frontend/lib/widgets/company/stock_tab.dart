import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';

class StockTab extends ConsumerStatefulWidget {
  final int companyId;
  const StockTab({super.key, required this.companyId});

  @override
  ConsumerState<StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<StockTab> {
  List<dynamic> _products = [];
  bool _loading = true;
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/products', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _products = res.data;
        _applySorting();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  void _applySorting() {
    _products.sort((a, b) {
      int cmp;
      if (_sortBy == 'name') {
        cmp = a['name'].compareTo(b['name']);
      } else {
        cmp = (a['current_quantity'] as num).compareTo(b['current_quantity'] as num);
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _changeSort(String by) {
    if (_sortBy == by) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = by;
      _sortAscending = true;
    }
    _applySorting();
    setState(() {});
  }

  Future<void> _addProduct() async {
    final nameController = TextEditingController();
    String? unit;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый товар'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Единица измерения'),
              items: const [
                DropdownMenuItem(value: 'kg', child: Text('кг')),
                DropdownMenuItem(value: 'liter', child: Text('литр')),
                DropdownMenuItem(value: 'piece', child: Text('шт')),
                DropdownMenuItem(value: 'g', child: Text('грамм')),
                DropdownMenuItem(value: 'ml', child: Text('мл')),
              ],
              onChanged: (v) => unit = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || unit == null) return;
              final api = ApiClient();
              try {
                await api.post('/products', queryParameters: {'company_id': widget.companyId}, data: {
                  'name': nameController.text,
                  'unit': unit,
                });
                Navigator.pop(context);
                _loadProducts();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить товар'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort),
                        onSelected: _changeSort,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'name', child: Text('По названию')),
                          const PopupMenuItem(value: 'quantity', child: Text('По остатку')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _products.isEmpty
                      ? const Center(child: Text('Нет товаров', style: TextStyle(fontSize: 16, color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueGrey.shade100,
                                  child: Text(p['name'][0].toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                title: Text(p['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text('Остаток: ${p['current_quantity']} ${p['unit']}'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}