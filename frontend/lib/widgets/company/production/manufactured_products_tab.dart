import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

class ManufacturedProductsTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  final VoidCallback onRefresh;

  const ManufacturedProductsTab({
    super.key,
    required this.companyId,
    required this.permissions,
    required this.onRefresh,
  });

  @override
  ConsumerState<ManufacturedProductsTab> createState() => _ManufacturedProductsTabState();
}

class _ManufacturedProductsTabState extends ConsumerState<ManufacturedProductsTab> {
  List<dynamic> _products = [];
  List<dynamic> _allProducts = [];
  List<String> _existingCounterparties = [];
  bool _loading = true;
  bool _loadingCounterparties = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ApiClient _api = ApiClient();
  
  // ✅ ДОБАВЛЕН ФЛАГ
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _loadData();
    _loadCounterparties();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    super.dispose();
  }

  double _parseDouble(String value) {
    if (value.isEmpty) return 0;
    String cleaned = value.replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  Future<void> _loadData() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loading = true);
    
    // ✅ УБРАЛ _loadAccounts() - он не нужен
    await Future.wait([_loadProducts(), _loadAllProducts()]);
    
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    if (_isDisposed) return;
    
    try {
      final res = await _api.get('/production/products', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() => _products = res.data);
    } catch (e) {
      if (!_isDisposed) print('Error loading products: $e');
    }
  }

  Future<void> _loadAllProducts() async {
    if (_isDisposed) return;
    
    try {
      final res = await _api.get('/products', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() => _allProducts = res.data);
    } catch (e) {
      if (!_isDisposed) print('Error loading all products: $e');
    }
  }

  Future<void> _loadCounterparties() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loadingCounterparties = true);
    try {
      final res = await _api.get('/counterparties', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() {
        _existingCounterparties = List<String>.from(res.data.map((cp) => cp['name']));
        _loadingCounterparties = false;
      });
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() => _loadingCounterparties = false);
      if (!_isDisposed) print('Error loading counterparties: $e');
    }
  }

  List<dynamic> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) =>
      p['name'].toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  bool get _canEdit => widget.permissions.contains('manage_manufactured_products');
  bool get _canSell => widget.permissions.contains('edit_production');

  String _getUnitDisplay(String unit) {
    final t = AppLocalizations.of(context)!;
    switch (unit) {
      case 'шт': return t.unitPcs;
      case 'кг': return t.unitKg;
      case 'г': return t.unitGram;
      case 'л': return t.unitLiter;
      case 'мл': return t.unitMl;
      case 'м': return t.unitMeter;
      default: return unit;
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    if (_isDisposed) return;
    if (!mounted) return;
    if (!_canEdit) return;
    
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteProductConfirmTitle),
        content: Text('${t.deleteProductConfirmContent} "${product['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    
    if (_isDisposed) return;
    if (!mounted) return;
    
    try {
      await _api.delete('/production/products/${product['id']}', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      await _loadData();
      widget.onRefresh();
      
      if (_isDisposed) return;
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.productDeleted)));
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _openSellDialog() async {
    if (_isDisposed) return;
    if (!mounted) return;
    if (!_canSell) return;
    
    final t = AppLocalizations.of(context)!;
    
    await _loadProducts();
    
    if (_isDisposed) return;
    if (!mounted) return;
    
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.noProductsForSale)),
      );
      return;
    }

    final currency = t.currencySymbol;
    
    List<Map<String, dynamic>> saleItems = [];
    final TextEditingController productSearchController = TextEditingController();
    
    int? cashAccountId, bankAccountId, selectedAccountId;
    DateTime date = DateTime.now();
    final counterpartyController = TextEditingController();
    
    final accountsRes = await _api.get('/accounts', queryParameters: {'company_id': widget.companyId});
    if (_isDisposed) return;
    if (!mounted) return;
    
    final accounts = accountsRes.data as List;
    cashAccountId = accounts.firstWhere((a) => a['type'] == 'cash', orElse: () => null)?['id'];
    bankAccountId = accounts.firstWhere((a) => a['type'] == 'bank', orElse: () => null)?['id'];
    selectedAccountId = cashAccountId;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final colorScheme = Theme.of(context).colorScheme;
          
          double total = 0;
          for (var item in saleItems) {
            total += (item['quantity'] as double) * (item['price'] as double);
          }
          
          return AlertDialog(
            title: Text(t.sellProduct, style: TextStyle(color: colorScheme.onSurface)),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      final lower = textEditingValue.text.toLowerCase();
                      return _products.where((p) => 
                        p['name'].toLowerCase().contains(lower)
                      ).map((p) => p as Map<String, dynamic>);
                    },
                    displayStringForOption: (Map<String, dynamic> option) {
                      return '${option['name']} (${option['price']}$currency)';
                    },
                    onSelected: (Map<String, dynamic> selected) {
                      setStateDialog(() {
                        final existingIndex = saleItems.indexWhere((i) => i['id'] == selected['id']);
                        if (existingIndex != -1) {
                          saleItems[existingIndex]['quantity'] = (saleItems[existingIndex]['quantity'] as double) + 1;
                        } else {
                          saleItems.add({
                            'id': selected['id'],
                            'name': selected['name'],
                            'price': selected['price'],
                            'quantity': 1.0,
                            'maxStock': selected['current_stock'],
                          });
                        }
                        productSearchController.clear();
                      });
                    },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                      textController.text = productSearchController.text;
                      textController.addListener(() {
                        if (productSearchController.text != textController.text) {
                          productSearchController.text = textController.text;
                        }
                      });
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: t.selectProduct,
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.search),
                          border: const OutlineInputBorder(),
                          suffixIcon: _loadingCounterparties
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    if (!_isDisposed && mounted) {
                                      _loadProducts();
                                    }
                                  },
                                  tooltip: t.refreshList,
                                ),
                        ),
                        style: TextStyle(color: colorScheme.onSurface),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(
                                    '${option['name']} (${option['price']}$currency)',
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: saleItems.isEmpty
                        ? Center(
                            child: Text(t.noProductsSelected, 
                              style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          )
                        : ListView.builder(
                            itemCount: saleItems.length,
                            itemBuilder: (context, index) {
                              final item = saleItems[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item['name'], 
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: colorScheme.onSurface,
                                              )),
                                            Text('${item['price']}$currency / ${t.stock}: ${item['maxStock']}',
                                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          initialValue: item['quantity'].toString(),
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: colorScheme.onSurface),
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          ),
                                          onChanged: (v) {
                                            double q = _parseDouble(v);
                                            if (q < 0) q = 0;
                                            if (q > item['maxStock']) q = item['maxStock'];
                                            setStateDialog(() {
                                              item['quantity'] = q;
                                            });
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setStateDialog(() {
                                            saleItems.removeAt(index);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  Text(
                    '${t.total}: ${total.toStringAsFixed(2)}$currency',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setStateDialog(() => selectedAccountId = cashAccountId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedAccountId == cashAccountId 
                                ? colorScheme.primary.withOpacity(0.2) 
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurface,
                          ),
                          child: Text(t.cash),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setStateDialog(() => selectedAccountId = bankAccountId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedAccountId == bankAccountId 
                                ? colorScheme.primary.withOpacity(0.2) 
                                : colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurface,
                          ),
                          child: Text(t.nonCash),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(t.date, style: TextStyle(color: colorScheme.onSurface)),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(date), 
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    dense: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() => date = picked);
                      }
                    },
                  ),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                      final lower = textEditingValue.text.toLowerCase();
                      return _existingCounterparties.where((c) => c.toLowerCase().contains(lower));
                    },
                    onSelected: (String selection) {
                      counterpartyController.text = selection;
                      setStateDialog(() {});
                    },
                    fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                      if (counterpartyController.text != textController.text) {
                        textController.text = counterpartyController.text;
                      }
                      textController.addListener(() {
                        if (counterpartyController.text != textController.text) {
                          counterpartyController.text = textController.text;
                        }
                      });
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: t.counterpartyOptional,
                          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                          suffixIcon: _loadingCounterparties
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    if (!_isDisposed && mounted) {
                                      _loadCounterparties();
                                    }
                                  },
                                  tooltip: t.refreshList,
                                ),
                        ),
                        style: TextStyle(color: colorScheme.onSurface),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option, style: TextStyle(color: colorScheme.onSurface)),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
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
                onPressed: saleItems.isEmpty ? null : () async {
                  if (selectedAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.selectPaymentMethod)),
                    );
                    return;
                  }
                  try {
                    for (var item in saleItems) {
                      final quantity = item['quantity'] as double;
                      if (quantity <= 0) continue;
                      
                      final amount = quantity * (item['price'] as double);
                      
                      await _api.post('/production/sell', 
                        queryParameters: {'company_id': widget.companyId}, 
                        data: {
                          'product_id': item['id'],
                          'quantity': quantity,
                          'amount': amount,
                          'account_id': selectedAccountId,
                          'date': date.toIso8601String(),
                          'is_paid': false,
                          'counterparty': counterpartyController.text.isEmpty ? null : counterpartyController.text,
                        },
                      );
                    }
                    
                    if (_isDisposed) return;
                    if (!mounted) return;
                    
                    Navigator.pop(context);
                    widget.onRefresh();
                    
                    if (_isDisposed) return;
                    if (!mounted) return;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.saleCompleted)),
                    );
                  } catch (e) {
                    if (_isDisposed) return;
                    if (!mounted) return;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${t.error}: $e')),
                    );
                  }
                },
                child: Text(t.sell),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createOrEditProduct([Map<String, dynamic>? existing]) async {
    if (_isDisposed) return;
    if (!mounted) return;
    if (!_canEdit) return;
    
    final isEdit = existing != null;
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: existing?['name']);
    final priceController = TextEditingController(text: existing?['price']?.toString());
    final outputUnitController = TextEditingController(text: existing?['unit'] ?? 'шт');
    List<Map<String, dynamic>> recipeItems = [];
    
    if (isEdit && existing['recipe'] != null && existing['recipe'].isNotEmpty) {
      try {
        final decoded = jsonDecode(existing['recipe']);
        if (decoded is List) {
          final productMap = {for (var m in _allProducts) m['id']: {'name': m['name'], 'unit': m['unit'] ?? 'шт'}};
          recipeItems = decoded.map((r) => {
            'product_id': r['product_id'],
            'product_name': productMap[r['product_id']]?['name'] ?? 'Неизвестный товар',
            'quantity': (r['quantity'] as num).toDouble(),
            'unit': productMap[r['product_id']]?['unit'] ?? 'шт',
          }).toList();
        }
      } catch (e) {
        if (!_isDisposed) print('Error parsing recipe: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Text(isEdit ? t.editProduct : t.createProduct, style: TextStyle(color: colorScheme.onSurface)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: t.name,
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: t.price,
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: outputUnitController,
                    decoration: InputDecoration(
                      labelText: t.unit,
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.recipe, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.green),
                        onPressed: () {
                          setStateDialog(() {
                            recipeItems.add({
                              'product_id': null,
                              'product_name': '',
                              'quantity': 1.0,
                              'unit': 'шт',
                            });
                          });
                        },
                        tooltip: t.addMaterial,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (recipeItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t.noMaterialsYet, style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    )
                  else
                    ...recipeItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Autocomplete<int>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return const Iterable<int>.empty();
                                    }
                                    final lower = textEditingValue.text.toLowerCase();
                                    return _allProducts.where((m) => 
                                      m['name'].toLowerCase().contains(lower)
                                    ).map((m) => m['id'] as int);
                                  },
                                  displayStringForOption: (int optionId) {
                                    final product = _allProducts.firstWhere((m) => m['id'] == optionId);
                                    return product['name'];
                                  },
                                  onSelected: (int productId) {
                                    final product = _allProducts.firstWhere((m) => m['id'] == productId);
                                    setStateDialog(() {
                                      recipeItems[idx]['product_id'] = product['id'];
                                      recipeItems[idx]['product_name'] = product['name'];
                                      recipeItems[idx]['unit'] = product['unit'] ?? 'шт';
                                    });
                                  },
                                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                    textController.text = item['product_name'] ?? '';
                                    return TextField(
                                      controller: textController,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        labelText: t.selectProduct,
                                        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                        border: const OutlineInputBorder(),
                                      ),
                                      style: TextStyle(color: colorScheme.onSurface),
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxHeight: 200),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final optionId = options.elementAt(index);
                                              final product = _allProducts.firstWhere((m) => m['id'] == optionId);
                                              return ListTile(
                                                title: Text(product['name'], style: TextStyle(color: colorScheme.onSurface)),
                                                onTap: () => onSelected(optionId),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextFormField(
                                  initialValue: item['quantity'].toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colorScheme.onSurface),
                                  onChanged: (v) {
                                    double q = _parseDouble(v);
                                    if (q < 0) q = 0;
                                    setStateDialog(() {
                                      recipeItems[idx]['quantity'] = q;
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  setStateDialog(() {
                                    recipeItems.removeAt(idx);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final price = _parseDouble(priceController.text);
                  final outputUnit = outputUnitController.text.trim();
                  if (name.isEmpty || price == 0 || outputUnit.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.fillAllFields)),
                    );
                    return;
                  }
                  final validRecipe = recipeItems.where((i) => i['product_id'] != null && i['quantity'] > 0).toList();
                  final recipeJson = validRecipe.isNotEmpty ? jsonEncode(validRecipe.map((i) => ({
                    'product_id': i['product_id'],
                    'quantity': i['quantity'],
                  })).toList()) : null;
                  try {
                    if (isEdit) {
                      await _api.patch('/production/products/${existing['id']}', 
                        queryParameters: {'company_id': widget.companyId}, 
                        data: {'name': name, 'price': price, 'recipe': recipeJson, 'unit': outputUnit},
                      );
                    } else {
                      await _api.post('/production/products', 
                        queryParameters: {'company_id': widget.companyId}, 
                        data: {'name': name, 'price': price, 'recipe': recipeJson, 'unit': outputUnit},
                      );
                    }
                    
                    if (_isDisposed) return;
                    if (!mounted) return;
                    
                    Navigator.pop(context);
                    await _loadData();
                    widget.onRefresh();
                  } catch (e) {
                    if (_isDisposed) return;
                    if (!mounted) return;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${t.error}: $e')),
                    );
                  }
                },
                child: Text(isEdit ? t.save : t.create),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    if (!_isDisposed && mounted) {
                      setState(() => _searchQuery = v);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: t.searchByName,
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
              if (_canSell)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ElevatedButton.icon(
                    onPressed: _openSellDialog,
                    icon: const Icon(Icons.sell),
                    label: Text(t.sell),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_canEdit)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FloatingActionButton.small(
                    onPressed: () => _createOrEditProduct(),
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                  ? Center(child: Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = _filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          Text(
                                            '${t.price}: ${p['price']}$currency',
                                            style: TextStyle(color: colorScheme.onSurfaceVariant),
                                          ),
                                          Text(
                                            '${t.stock}: ${p['current_stock']} ${_getUnitDisplay(p['unit'] ?? 'шт')}',
                                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (_canEdit)
                                  IconButton(
                                    icon: Icon(Icons.edit, color: colorScheme.primary),
                                    onPressed: () => _createOrEditProduct(p),
                                  ),
                                if (_canEdit)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteProduct(p),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}