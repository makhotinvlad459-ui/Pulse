import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AddMaterialDialog extends ConsumerStatefulWidget {
  final List<dynamic> products;
  final int companyId;

  const AddMaterialDialog({super.key, required this.products, required this.companyId});

  @override
  ConsumerState<AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends ConsumerState<AddMaterialDialog> {
  String _searchQuery = '';
  List<dynamic> _filteredProducts = [];
  int? _selectedProductId;
  String _selectedProductName = '';
  double _quantity = 1;
  double _totalPrice = 0;
  bool _useFromStock = false;

  @override
  void initState() {
    super.initState();
    _filteredProducts = [];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(t.addMaterialTitle, style: TextStyle(color: colorScheme.onSurface)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    if (value.isNotEmpty) {
                      _filteredProducts = widget.products.where((p) => p['name'].toLowerCase().contains(value.toLowerCase())).toList();
                    } else {
                      _filteredProducts = [];
                    }
                  });
                },
                decoration: InputDecoration(labelText: t.searchMaterialHint, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              if (_filteredProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (ctx, idx) {
                      final prod = _filteredProducts[idx];
                      return ListTile(
                        title: Text(prod['name'], style: TextStyle(color: colorScheme.onSurface)),
                        subtitle: Text('${prod['unit']} / ${t.remainingStockLower}: ${prod['current_quantity']}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        onTap: () {
                          setState(() {
                            _selectedProductId = prod['id'];
                            _selectedProductName = prod['name'];
                            _totalPrice = 0;
                            _searchQuery = '';
                            _filteredProducts = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              if (_selectedProductId != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  title: Text('${t.selectedLabel}: $_selectedProductName', style: TextStyle(color: colorScheme.onSurface)),
                  trailing: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _selectedProductId = null;
                      _selectedProductName = '';
                      _totalPrice = 0;
                    }),
                  ),
                ),
              ],
              if (_selectedProductId == null) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _createNewProduct,
                  icon: const Icon(Icons.add),
                  label: Text(t.createNewMaterialButton),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => _quantity = double.tryParse(v) ?? 0,
                decoration: InputDecoration(labelText: t.quantityRequired, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => _totalPrice = double.tryParse(v) ?? 0,
                decoration: InputDecoration(labelText: t.totalPriceRequired, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                keyboardType: TextInputType.number,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _useFromStock,
                    onChanged: (v) => setState(() => _useFromStock = v ?? false),
                  ),
                  const SizedBox(width: 8),
                  Text(t.useFromStockLabel, style: TextStyle(color: colorScheme.onSurface)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ElevatedButton(
          onPressed: _submit,
          child: Text(t.add),
        ),
      ],
    );
  }

  Future<void> _createNewProduct() async {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final nameController = TextEditingController();
    String unit = 'шт';
    double price = 0;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.newMaterialTitle, style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: t.nameRequired, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
              style: TextStyle(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: unit,
              decoration: InputDecoration(labelText: t.unitRequired, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
              dropdownColor: colorScheme.surface,
              style: TextStyle(color: colorScheme.onSurface),
              items: ['шт', 'кг', 'г', 'л', 'мл', 'м', 'см', 'упаковка'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => unit = v!,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(labelText: t.pricePerUnitHint, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
              keyboardType: TextInputType.number,
              style: TextStyle(color: colorScheme.onSurface),
              onChanged: (v) => price = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.enterMaterialName)));
                return;
              }
              final api = ApiClient();
              try {
                final productRes = await api.post('/products/', queryParameters: {'company_id': widget.companyId}, data: {
                  'name': nameController.text,
                  'unit': unit,
                  'type': 'material',
                });
                final newProduct = productRes.data;
                setState(() {
                  _selectedProductId = newProduct['id'];
                  _selectedProductName = newProduct['name'];
                  _totalPrice = price;
                });
                Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
              }
            },
            child: Text(t.create),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final t = AppLocalizations.of(context)!;
    if (_selectedProductId == null || _quantity <= 0 || _totalPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectMaterialAndQuantity)));
      return;
    }
    final unitPrice = _totalPrice / _quantity;
    Navigator.pop(context, {
      'product_id': _selectedProductId,
      'product_name': _selectedProductName,
      'quantity': _quantity,
      'unit_price': unitPrice,
      'use_from_stock': _useFromStock,
      'total': _totalPrice,
    });
  }
}