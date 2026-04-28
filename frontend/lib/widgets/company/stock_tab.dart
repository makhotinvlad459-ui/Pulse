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
      final res = await api.get('/products/', queryParameters: {'company_id': widget.companyId});
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
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Новый товар', style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
              ),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Единица измерения',
                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
              ),
              dropdownColor: colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || unit == null) return;
              final api = ApiClient();
              try {
                await api.post('/products/', queryParameters: {'company_id': widget.companyId}, data: {
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
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: Colors.transparent, // прозрачный, чтобы просвечивал фон экрана
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
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.sort, color: colorScheme.onSurface),
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
                      ? Center(
                          child: Text('Нет товаров', style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: colorScheme.surface,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.primaryContainer,
                                  child: Text(p['name'][0].toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      )),
                                ),
                                title: Text(p['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: colorScheme.onSurface,
                                    )),
                                subtitle: Text('Остаток: ${p['current_quantity']} ${p['unit']}',
                                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
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