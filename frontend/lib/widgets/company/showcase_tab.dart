import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reorderable_grid/reorderable_grid.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../models/showcase_item.dart';
import 'recipe_editor.dart';

class ShowcaseTab extends ConsumerStatefulWidget {
  final int companyId;
  const ShowcaseTab({super.key, required this.companyId});

  @override
  ConsumerState<ShowcaseTab> createState() => _ShowcaseTabState();
}

class _ShowcaseTabState extends ConsumerState<ShowcaseTab> {
  List<ShowcaseItem> _items = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  final ApiClient _api = ApiClient();
  bool _canEdit = false;
  List<Map<String, dynamic>> _bulkSaleItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([_loadItems(), _loadCategories(), _checkPermissions()]);
    setState(() => _loading = false);
  }

  Future<void> _loadItems() async {
    try {
      final res = await _api.get('/showcase', queryParameters: {'company_id': widget.companyId});
      _items = (res.data as List).map((json) => ShowcaseItem.fromJson(json)).toList();
    } catch (e) {
      print('Load items error: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.get('/categories', queryParameters: {'company_id': widget.companyId});
      _categories = res.data;
    } catch (e) {
      print('Load categories error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;
    if (user.role == UserRole.founder) {
      _canEdit = true;
      return;
    }
    _canEdit = false;
  }

  Future<void> _saveOrder(List<ShowcaseItem> newItems) async {
    final ids = newItems.map((i) => i.id).toList();
    try {
      await _api.post('/showcase/reorder', queryParameters: {'company_id': widget.companyId}, data: ids);
    } catch (e) {
      print('Reorder error: $e');
    }
  }

  Future<void> _openReorderDialog() async {
    List<ShowcaseItem> tempItems = List.from(_items);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Изменить порядок'),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: ReorderableListView.builder(
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = tempItems.removeAt(oldIndex);
                  tempItems.insert(newIndex, item);
                  setStateDialog(() {});
                },
                itemCount: tempItems.length,
                itemBuilder: (context, index) {
                  final item = tempItems[index];
                  return ListTile(
                    key: Key('${item.id}'),
                    leading: const Icon(Icons.drag_handle, color: Colors.grey),
                    title: Text(item.name),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  await _saveOrder(tempItems);
                  setState(() {
                    _items = tempItems;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addItem() async {
    if (!_canEdit) return;
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int? categoryId;
    List<Map<String, dynamic>> localRecipeItems = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Новый товар/услуга'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название')),
                  const SizedBox(height: 8),
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Цена'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: categoryId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Без категории')),
                      ..._categories.map((c) => DropdownMenuItem(value: c['id'], child: Text('${c['icon'] ?? '📁'} ${c['name']}'))),
                    ],
                    onChanged: (v) => categoryId = v,
                    decoration: const InputDecoration(labelText: 'Категория (необязательно)'),
                  ),
                  const SizedBox(height: 8),
                  RecipeEditor(
                    companyId: widget.companyId,
                    initialItems: localRecipeItems,
                    onChanged: (newItems) {
                      localRecipeItems = newItems;
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text);
                  if (name.isEmpty || price == null) return;
                  final recipeJson = localRecipeItems.isNotEmpty
                      ? jsonEncode(localRecipeItems.map((i) => {
                          'product_id': i['product_id'],
                          'quantity': i['quantity'],
                        }).toList())
                      : null;
                  try {
                    await _api.post('/showcase', queryParameters: {'company_id': widget.companyId}, data: {
                      'name': name,
                      'price': price,
                      'category_id': categoryId,
                      'recipe': recipeJson,
                    });
                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                  }
                },
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editItem(ShowcaseItem item) async {
    if (!_canEdit) return;
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    int? categoryId = item.categoryId;
    List<Map<String, dynamic>> localRecipeItems = [];
    if (item.recipe != null && item.recipe!.isNotEmpty) {
      try {
        final decoded = jsonDecode(item.recipe!);
        if (decoded is List) {
          localRecipeItems = decoded.map((r) => {
            'product_id': r['product_id'],
            'product_name': '',
            'quantity': (r['quantity'] as num).toDouble(),
          }).toList();
        }
      } catch (e) {
        print('Error parsing recipe: $e');
      }
    }
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Редактировать'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название')),
                  const SizedBox(height: 8),
                  TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Цена'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: categoryId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Без категории')),
                      ..._categories.map((c) => DropdownMenuItem(value: c['id'], child: Text('${c['icon'] ?? '📁'} ${c['name']}'))),
                    ],
                    onChanged: (v) => categoryId = v,
                    decoration: const InputDecoration(labelText: 'Категория (необязательно)'),
                  ),
                  const SizedBox(height: 8),
                  RecipeEditor(
                    companyId: widget.companyId,
                    initialItems: localRecipeItems,
                    onChanged: (newItems) {
                      localRecipeItems = newItems;
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final price = double.tryParse(priceController.text);
                  if (name.isEmpty || price == null) return;
                  final recipeJson = localRecipeItems.isNotEmpty
                      ? jsonEncode(localRecipeItems.map((i) => {
                          'product_id': i['product_id'],
                          'quantity': i['quantity'],
                        }).toList())
                      : null;
                  try {
                    await _api.patch('/showcase/${item.id}', queryParameters: {'company_id': widget.companyId}, data: {
                      'name': name,
                      'price': price,
                      'category_id': categoryId,
                      'recipe': recipeJson,
                    });
                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(ShowcaseItem item) async {
    if (!_canEdit) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить элемент?'),
        content: const Text('Действие необратимо.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('/showcase/${item.id}', queryParameters: {'company_id': widget.companyId});
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _sellItem(ShowcaseItem item) async {
    double quantity = 1.0;
    double salePrice = item.price;
    final accountsRes = await _api.get('/accounts', queryParameters: {'company_id': widget.companyId});
    final accounts = accountsRes.data as List;
    int? cashAccountId = accounts.firstWhere((a) => a['type'] == 'cash', orElse: () => null)?['id'];
    int? bankAccountId = accounts.firstWhere((a) => a['type'] == 'bank', orElse: () => null)?['id'];
    int? selectedAccountId = cashAccountId;
    DateTime date = DateTime.now();
    String counterparty = '';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Продажа: ${item.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: quantity.toString(),
                          decoration: const InputDecoration(labelText: 'Количество'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final q = double.tryParse(v) ?? 1;
                            if (q <= 0) return;
                            quantity = q;
                            salePrice = item.price * quantity;
                            setStateDialog(() {});
                          },
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              quantity += 1;
                              salePrice = item.price * quantity;
                              setStateDialog(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (quantity > 1) {
                                quantity -= 1;
                                salePrice = item.price * quantity;
                                setStateDialog(() {});
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Итого: ${salePrice.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setStateDialog(() => selectedAccountId = cashAccountId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedAccountId == cashAccountId ? Colors.blue.shade200 : Colors.grey.shade200,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Наличные'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setStateDialog(() => selectedAccountId = bankAccountId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedAccountId == bankAccountId ? Colors.blue.shade200 : Colors.grey.shade200,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Банк'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Дата'),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(date)),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                      if (picked != null) setStateDialog(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => counterparty = v,
                    decoration: const InputDecoration(labelText: 'Контрагент (необязательно)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите способ оплаты')));
                    return;
                  }
                  List<Map<String, dynamic>> items = [];
                  if (item.recipe != null && item.recipe!.isNotEmpty) {
                    try {
                      final recipe = jsonDecode(item.recipe!) as List;
                      for (var r in recipe) {
                        final productId = r['product_id'];
                        final recipeQty = (r['quantity'] as num).toDouble();
                        final totalQty = recipeQty * quantity;
                        items.add({
                          'product_id': productId,
                          'quantity': totalQty,
                          'price_per_unit': 0,
                        });
                      }
                    } catch (e) {
                      print('Recipe parse error: $e');
                    }
                  }
                  final data = {
                    'type': 'income',
                    'amount': salePrice,
                    'date': date.toIso8601String(),
                    'account_id': selectedAccountId,
                    'description': 'Продажа с витрины: ${item.name} (${quantity.toStringAsFixed(2)} шт)',
                    'counterparty': counterparty.isNotEmpty ? counterparty : null,
                    'items': items,
                    'category_id': item.categoryId,
                  };
                  try {
                    await _api.post('/transactions', queryParameters: {'company_id': widget.companyId}, data: data);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Продажа оформлена')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                  }
                },
                child: const Text('Продать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openBulkSaleDialog() async {
  _bulkSaleItems = _items.map((item) => {
    'id': item.id,
    'name': item.name,
    'price': item.price,
    'quantity': 0.0,
    'recipe': item.recipe,
  }).toList();
  
  // Создаём контроллеры для каждого товара
  Map<int, TextEditingController> controllers = {};
  for (int i = 0; i < _bulkSaleItems.length; i++) {
    final controller = TextEditingController(text: '0');
    controllers[i] = controller;
  }

  int? cashAccountId, bankAccountId, selectedAccountId;
  DateTime date = DateTime.now();
  String counterparty = '';
  final accountsRes = await _api.get('/accounts', queryParameters: {'company_id': widget.companyId});
  final accounts = accountsRes.data as List;
  cashAccountId = accounts.firstWhere((a) => a['type'] == 'cash', orElse: () => null)?['id'];
  bankAccountId = accounts.firstWhere((a) => a['type'] == 'bank', orElse: () => null)?['id'];
  selectedAccountId = cashAccountId;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Продажа списком'),
          content: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _bulkSaleItems.length,
                    itemBuilder: (context, index) {
                      final item = _bulkSaleItems[index];
                      final controller = controllers[index]!;
                      // Синхронизируем контроллер, если quantity изменилась извне (например, через кнопки)
                      if (controller.text != item['quantity'].toString()) {
                        controller.text = item['quantity'].toString();
                      }
                      return ListTile(
                        title: Text(item['name']),
                        subtitle: Text('${item['price']} ₽'),
                        trailing: SizedBox(
                          width: 130,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 20),
                                onPressed: () {
                                  double newVal = (item['quantity'] as double) - 1;
                                  if (newVal < 0) newVal = 0;
                                  setStateDialog(() {
                                    item['quantity'] = newVal;
                                    controller.text = newVal.toString();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                                  onChanged: (v) {
                                    final q = double.tryParse(v) ?? 0;
                                    setStateDialog(() {
                                      item['quantity'] = q;
                                    });
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () {
                                  double newVal = (item['quantity'] as double) + 1;
                                  setStateDialog(() {
                                    item['quantity'] = newVal;
                                    controller.text = newVal.toString();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setStateDialog(() => selectedAccountId = cashAccountId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedAccountId == cashAccountId ? Colors.blue.shade200 : Colors.grey.shade200,
                        ),
                        child: const Text('Наличные'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setStateDialog(() => selectedAccountId = bankAccountId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedAccountId == bankAccountId ? Colors.blue.shade200 : Colors.grey.shade200,
                        ),
                        child: const Text('Банк'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Дата'),
                  trailing: Text(DateFormat('dd.MM.yyyy').format(date)),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) setStateDialog(() => date = picked);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => counterparty = v,
                  decoration: const InputDecoration(labelText: 'Контрагент (необязательно)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                final selectedItems = _bulkSaleItems.where((i) => i['quantity'] > 0).toList();
                if (selectedItems.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите хотя бы один товар')));
                  return;
                }
                if (selectedAccountId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите способ оплаты')));
                  return;
                }
                List<Map<String, dynamic>> items = [];
                double totalAmount = 0;
                for (var si in selectedItems) {
                  final qty = si['quantity'];
                  final price = si['price'];
                  final total = qty * price;
                  totalAmount += total;
                  if (si['recipe'] != null && si['recipe'].isNotEmpty) {
                    try {
                      final recipe = jsonDecode(si['recipe']);
                      for (var r in recipe) {
                        items.add({
                          'product_id': r['product_id'],
                          'quantity': r['quantity'] * qty,
                          'price_per_unit': 0,
                        });
                      }
                    } catch (e) {
                      print('Recipe parse error: $e');
                    }
                  }
                }
                final data = {
                  'type': 'income',
                  'amount': totalAmount,
                  'date': date.toIso8601String(),
                  'account_id': selectedAccountId,
                  'description': 'Массовая продажа с витрины (${selectedItems.map((i) => '${i['name']} ${i['quantity']} шт').join(', ')})',
                  'counterparty': counterparty.isNotEmpty ? counterparty : null,
                  'items': items,
                };
                try {
                  await _api.post('/transactions', queryParameters: {'company_id': widget.companyId}, data: data);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Продажа оформлена')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                }
              },
              child: const Text('Продать'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showMenu(ShowcaseItem item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _sellItem(item);
                          },
                          icon: const Icon(Icons.sell),
                          label: const Text('Продать'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    if (_canEdit)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _editItem(item);
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Редактировать'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteItem(item);
                              },
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String getCategoryName(int? categoryId) {
    if (categoryId == null) return '';
    try {
      final cat = _categories.firstWhere((c) => c['id'] == categoryId);
      return cat['name'] ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    int crossAxisCount = MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2);

    return Column(
      children: [
        if (_canEdit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Создать товар/услугу витрины'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openBulkSaleDialog,
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Продажа списком'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openReorderDialog,
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Порядок'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 3.5,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final categoryName = getCategoryName(item.categoryId);
              return GestureDetector(
                onTap: () => _showMenu(item),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.price.toStringAsFixed(2)} ₽',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ],
                        ),
                        if (categoryName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              categoryName,
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
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