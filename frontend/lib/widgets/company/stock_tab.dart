import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  int _entryInvoiceCounter = 1;
  int _writeOffInvoiceCounter = 1;

  // Контроллеры для приходной накладной
  final TextEditingController _entrySupplierController = TextEditingController();
  final TextEditingController _entryDescriptionController = TextEditingController();
  final TextEditingController _entryProductController = TextEditingController();
  final TextEditingController _entryQuantityController = TextEditingController();
  final TextEditingController _entryPriceController = TextEditingController();
  final TextEditingController _entryTotalController = TextEditingController();
  bool _useTotalPrice = false;
  List<Map<String, dynamic>> _entryItems = [];
  int? _selectedEntryProductId;
  String? _selectedEntryProductName;

  // Контроллеры для расходной накладной
  final TextEditingController _writeOffReasonController = TextEditingController();
  final TextEditingController _writeOffProductController = TextEditingController();
  final TextEditingController _writeOffQuantityController = TextEditingController();
  List<Map<String, dynamic>> _writeOffItems = [];
  int? _selectedWriteOffProductId;
  String? _selectedWriteOffProductName;
  double? _selectedWriteOffCurrentQuantity;

  // Редактирование товара
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editUnitController = TextEditingController();
  final TextEditingController _editPriceController = TextEditingController();
  int? _editingProductId;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCounters();
  }

  Future<void> _loadCounters() async {}

  void _saveCounters() {}

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/stock/products', queryParameters: {'company_id': widget.companyId});
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
      } else if (_sortBy == 'quantity') {
        cmp = (a['current_quantity'] as num).compareTo(b['current_quantity'] as num);
      } else {
        cmp = ((a['price_per_unit'] ?? 0) as num).compareTo((b['price_per_unit'] ?? 0) as num);
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

  // ------------------ Приходная накладная ------------------
  void _updatePriceOrTotal() {
    final quantity = double.tryParse(_entryQuantityController.text);
    if (quantity == null || quantity <= 0) return;

    if (_useTotalPrice) {
      final total = double.tryParse(_entryTotalController.text);
      if (total != null && total > 0) {
        final price = total / quantity;
        _entryPriceController.text = price.toStringAsFixed(2);
      } else {
        _entryPriceController.clear();
      }
    } else {
      final price = double.tryParse(_entryPriceController.text);
      if (price != null && price > 0) {
        final total = price * quantity;
        _entryTotalController.text = total.toStringAsFixed(2);
      } else {
        _entryTotalController.clear();
      }
    }
  }

  void _addItemToEntry() {
    final quantity = double.tryParse(_entryQuantityController.text);
    double? price;
    if (_useTotalPrice) {
      final total = double.tryParse(_entryTotalController.text);
      if (total == null || quantity == null || quantity <= 0) return;
      price = total / quantity;
    } else {
      price = double.tryParse(_entryPriceController.text);
    }

    if (_selectedEntryProductId == null || quantity == null || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля корректно')),
      );
      return;
    }

    setState(() {
      _entryItems.add({
        'product_id': _selectedEntryProductId,
        'product_name': _selectedEntryProductName,
        'quantity': quantity,
        'price_per_unit': price,
        'isDeleted': false,
      });
      _entryProductController.clear();
      _entryQuantityController.clear();
      _entryPriceController.clear();
      _entryTotalController.clear();
      _useTotalPrice = false;
      _selectedEntryProductId = null;
      _selectedEntryProductName = null;
    });
  }

  void _toggleEntryItemDeleted(int index) {
    setState(() {
      _entryItems[index]['isDeleted'] = !_entryItems[index]['isDeleted'];
    });
  }

  Future<void> _createStockEntry() async {
    final activeItems = _entryItems.where((item) => item['isDeleted'] == false).toList();
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет активных товаров для оприходования')),
      );
      return;
    }

    final api = ApiClient();
    try {
      for (var item in activeItems) {
        await api.post('/stock/entry', queryParameters: {'company_id': widget.companyId}, data: {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'price_per_unit': item['price_per_unit'],
          'description': _entrySupplierController.text.isNotEmpty
              ? 'Поставщик: ${_entrySupplierController.text}\n${_entryDescriptionController.text}'
              : _entryDescriptionController.text,
        });
      }
      setState(() {
        _entryItems.clear();
        _entrySupplierController.clear();
        _entryDescriptionController.clear();
        _entryInvoiceCounter++;
        _saveCounters();
      });
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Приходная накладная №$_entryInvoiceCounter создана')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  // ------------------ Расходная накладная ------------------
  void _addItemToWriteOff() {
    final quantity = double.tryParse(_writeOffQuantityController.text);
    if (_selectedWriteOffProductId == null || quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }
    if (_selectedWriteOffCurrentQuantity != null && quantity > _selectedWriteOffCurrentQuantity!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Недостаточно товара на складе')),
      );
      return;
    }
    setState(() {
      _writeOffItems.add({
        'product_id': _selectedWriteOffProductId,
        'product_name': _selectedWriteOffProductName,
        'quantity': quantity,
        'isDeleted': false,
      });
      _writeOffProductController.clear();
      _writeOffQuantityController.clear();
      _selectedWriteOffProductId = null;
      _selectedWriteOffProductName = null;
    });
  }

  void _toggleWriteOffItemDeleted(int index) {
    setState(() {
      _writeOffItems[index]['isDeleted'] = !_writeOffItems[index]['isDeleted'];
    });
  }

  Future<void> _createStockWriteOff() async {
    final activeItems = _writeOffItems.where((item) => item['isDeleted'] == false).toList();
    if (activeItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет активных товаров для списания')),
      );
      return;
    }

    final api = ApiClient();
    try {
      for (var item in activeItems) {
        await api.post('/stock/write-off', queryParameters: {'company_id': widget.companyId}, data: {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'reason': 'sale',
          'description': _writeOffReasonController.text.isNotEmpty
              ? _writeOffReasonController.text
              : 'Расход',
        });
      }
      setState(() {
        _writeOffItems.clear();
        _writeOffReasonController.clear();
        _writeOffInvoiceCounter++;
        _saveCounters();
      });
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Расходная накладная №$_writeOffInvoiceCounter создана')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  // ------------------ Удаление товара (полностью из базы) ------------------
  Future<void> _deleteProduct(int productId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text('Вы уверены, что хотите удалить товар "$productName"?\nВсе данные о приходах и расходах по этому товару будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    final api = ApiClient();
    try {
      await api.delete('/products/$productId', queryParameters: {'company_id': widget.companyId});
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Товар удалён')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    }
  }

  // ------------------ Редактирование товара ------------------
  Future<void> _editProduct(Map<String, dynamic> product) async {
    _editingProductId = product['id'];
    _editNameController.text = product['name'];
    _editUnitController.text = product['unit'];
    _editPriceController.text = product['price_per_unit']?.toString() ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать товар'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editNameController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editUnitController,
              decoration: const InputDecoration(labelText: 'Единица измерения'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _editPriceController,
              decoration: const InputDecoration(labelText: 'Цена за единицу'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final api = ApiClient();
              try {
                await api.patch('/products/${_editingProductId}',
                    queryParameters: {'company_id': widget.companyId},
                    data: {
                      'name': _editNameController.text,
                      'unit': _editUnitController.text,
                      'price_per_unit': double.tryParse(_editPriceController.text),
                    });
                Navigator.pop(context);
                _loadProducts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Товар обновлён')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  // ------------------ Добавление нового товара ------------------
  Future<void> _addProduct() async {
    final nameController = TextEditingController();
    String? unit;
    final priceController = TextEditingController();

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
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Цена за единицу'),
              keyboardType: TextInputType.number,
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
                  'price_per_unit': double.tryParse(priceController.text),
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

  // ------------------ Проверка прав на редактирование/удаление ------------------
  bool _canEdit() {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return false;
    return user.role == UserRole.founder || user.role == UserRole.superadmin;
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    final canEdit = _canEdit();

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
                          onPressed: () => _showEntryInvoiceDialog(),
                          icon: const Icon(Icons.add_box),
                          label: const Text('Приходная накладная'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showWriteOffInvoiceDialog(),
                          icon: const Icon(Icons.remove_circle),
                          label: const Text('Расходная накладная'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          const PopupMenuItem(value: 'price', child: Text('По цене')),
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
                            final avgPrice = p['price_per_unit'] ?? 0;
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueGrey.shade100,
                                  child: Text(p['name'][0].toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                title: Text(p['name'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Остаток: ${p['current_quantity']} ${p['unit']}'),
                                    const SizedBox(height: 2),
                                    Text('Ср.цена: ${avgPrice.toStringAsFixed(2)} ₽',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                                trailing: canEdit
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                            onPressed: () => _editProduct(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteProduct(p['id'], p['name']),
                                          ),
                                        ],
                                      )
                                    : null,
                                children: const [], // больше нет кнопок прихода/расхода
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ------------------ Диалог приходной накладной ------------------
  Future<void> _showEntryInvoiceDialog() async {
    _entryItems.clear();
    _entrySupplierController.clear();
    _entryDescriptionController.clear();
    _entryProductController.clear();
    _entryQuantityController.clear();
    _entryPriceController.clear();
    _entryTotalController.clear();
    _useTotalPrice = false;
    _selectedEntryProductId = null;
    _selectedEntryProductName = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Приходная накладная №${_entryInvoiceCounter + 1}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _entrySupplierController,
                      decoration: const InputDecoration(labelText: 'Поставщик (необязательно)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _entryDescriptionController,
                      decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
                      maxLines: 2,
                    ),
                    const Divider(height: 24),
                    const Text('Добавить товар', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Товар'),
                      items: _products.map((p) {
                        return DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(
                              '${p['name']} (остаток: ${p['current_quantity']} ${p['unit']})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedEntryProductId = value;
                          final product = _products.firstWhere((p) => p['id'] == value);
                          _selectedEntryProductName = product['name'];
                          _entryProductController.text = product['name'];
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _entryQuantityController,
                      decoration: const InputDecoration(labelText: 'Количество'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _updatePriceOrTotal(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: const Text('Указать общую сумму'),
                            value: _useTotalPrice,
                            onChanged: (val) {
                              setStateDialog(() {
                                _useTotalPrice = val ?? false;
                                if (!_useTotalPrice) {
                                  _entryTotalController.clear();
                                } else {
                                  _entryPriceController.clear();
                                }
                                _updatePriceOrTotal();
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                      ],
                    ),
                    if (!_useTotalPrice)
                      TextField(
                        controller: _entryPriceController,
                        decoration: const InputDecoration(labelText: 'Цена за единицу (₽)'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updatePriceOrTotal(),
                      ),
                    if (_useTotalPrice)
                      TextField(
                        controller: _entryTotalController,
                        decoration: const InputDecoration(labelText: 'Общая сумма (₽)'),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _updatePriceOrTotal(),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _addItemToEntry();
                        setStateDialog(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить товар'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                    if (_entryItems.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Товары в накладной:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: _entryItems.length,
                        itemBuilder: (context, idx) {
                          final item = _entryItems[idx];
                          final total = item['quantity'] * item['price_per_unit'];
                          final isDeleted = item['isDeleted'] ?? false;
                          return ListTile(
                            title: Text(
                              item['product_name'],
                              style: TextStyle(
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                                color: isDeleted ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Text(
                              '${item['quantity']} × ${item['price_per_unit']} ₽ = ${total.toStringAsFixed(2)} ₽',
                              style: TextStyle(
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                                color: isDeleted ? Colors.grey : null,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isDeleted ? Icons.restore : Icons.delete_outline,
                                color: isDeleted ? Colors.green : Colors.red,
                              ),
                              onPressed: () {
                                _toggleEntryItemDeleted(idx);
                                setStateDialog(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: _createStockEntry,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text('Оприходовать'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------ Диалог расходной накладной ------------------
  Future<void> _showWriteOffInvoiceDialog() async {
    _writeOffItems.clear();
    _writeOffReasonController.clear();
    _writeOffProductController.clear();
    _writeOffQuantityController.clear();
    _selectedWriteOffProductId = null;
    _selectedWriteOffProductName = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Расходная накладная №${_writeOffInvoiceCounter + 1}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _writeOffReasonController,
                      decoration: const InputDecoration(labelText: 'Причина расхода (необязательно)'),
                      maxLines: 2,
                    ),
                    const Divider(height: 24),
                    const Text('Добавить товар', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Товар'),
                      items: _products.map((p) {
                        return DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(
                              '${p['name']} (остаток: ${p['current_quantity']} ${p['unit']})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedWriteOffProductId = value;
                          final product = _products.firstWhere((p) => p['id'] == value);
                          _selectedWriteOffProductName = product['name'];
                          _selectedWriteOffCurrentQuantity = product['current_quantity'];
                          _writeOffProductController.text = product['name'];
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _writeOffQuantityController,
                      decoration: const InputDecoration(labelText: 'Количество'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _addItemToWriteOff();
                        setStateDialog(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить товар'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                    if (_writeOffItems.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Товары в накладной:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: _writeOffItems.length,
                        itemBuilder: (context, idx) {
                          final item = _writeOffItems[idx];
                          final isDeleted = item['isDeleted'] ?? false;
                          return ListTile(
                            title: Text(
                              item['product_name'],
                              style: TextStyle(
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                                color: isDeleted ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Text(
                              '${item['quantity']} шт',
                              style: TextStyle(
                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                                color: isDeleted ? Colors.grey : null,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isDeleted ? Icons.restore : Icons.delete_outline,
                                color: isDeleted ? Colors.green : Colors.red,
                              ),
                              onPressed: () {
                                _toggleWriteOffItemDeleted(idx);
                                setStateDialog(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: _createStockWriteOff,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Списать'),
              ),
            ],
          );
        },
      ),
    );
  }
}