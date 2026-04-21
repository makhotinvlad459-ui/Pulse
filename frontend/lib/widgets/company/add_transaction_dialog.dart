import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/api_client.dart';

class AddTransactionDialog extends StatefulWidget {
  final int companyId;
  final Future<void> Function() onSuccess;
  final List<dynamic> accounts;
  final List<dynamic> categories;
  final String? presetType;
  final int? presetProductId;
  const AddTransactionDialog({
    super.key,
    required this.companyId,
    required this.onSuccess,
    required this.accounts,
    required this.categories,
    this.presetType,
    this.presetProductId,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  double _amount = 0;
  DateTime _date = DateTime.now();
  int? _accountId;
  int? _categoryId;
  int? _transferToAccountId;
  String _description = '';
  String _counterparty = '';
  bool _loading = false;
  XFile? _photo;
  PlatformFile? _webFile;
  List<Map<String, dynamic>> _selectedProducts = [];

  @override
  void initState() {
    super.initState();
    _type = widget.presetType ?? 'income';
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts[0]['id'];
      if (_type == 'transfer') {
        final available = widget.accounts.where((a) => a['id'] != _accountId).toList();
        if (available.isNotEmpty) _transferToAccountId = available[0]['id'];
      }
    }
    if (widget.presetProductId != null) {
      _addPresetProduct();
    }
  }

  Future<void> _addPresetProduct() async {
    final api = ApiClient();
    try {
      final res = await api.get('/products', queryParameters: {'company_id': widget.companyId});
      final products = res.data as List;
      final product = products.firstWhere((p) => p['id'] == widget.presetProductId);
      setState(() {
        _selectedProducts.add({
          'product_id': product['id'],
          'product_name': product['name'],
          'quantity': 0.0,
          'price_per_unit': 0.0,
          'total': 0.0,
        });
      });
    } catch (e) {
      print('Error loading product: $e');
    }
  }

  double get _calculatedAmount {
    double total = 0;
    for (var p in _selectedProducts) {
      total += (p['total'] as double);
    }
    return total;
  }

  Future<void> _pickFile() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles();
      if (result != null) setState(() => _webFile = result.files.first);
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() => _photo = picked);
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      await _pickFile();
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) setState(() => _photo = picked);
    }
  }

  Future<void> _addProduct() async {
    final api = ApiClient();
    List<dynamic> products = [];
    try {
      final res = await api.get('/products', queryParameters: {'company_id': widget.companyId});
      products = res.data;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки товаров: $e')));
      return;
    }

    int? selectedProductId;
    double quantity = 0;
    double total = 0;
    final quantityController = TextEditingController();
    final totalController = TextEditingController();
    Map<String, dynamic>? selectedProduct;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Добавить товар'),
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
                      selectedProduct = products.firstWhere((p) => p['id'] == v);
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Количество'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: totalController,
                  decoration: const InputDecoration(labelText: 'Сумма (₽)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () {
                  final q = double.tryParse(quantityController.text);
                  final t = double.tryParse(totalController.text);
                  if (selectedProductId == null || q == null || t == null || q <= 0 || t <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля корректно')));
                    return;
                  }
                  final pricePerUnit = t / q;
                  setState(() {
                    _selectedProducts.add({
                      'product_id': selectedProductId,
                      'product_name': selectedProduct?['name'] ?? '',
                      'quantity': q,
                      'price_per_unit': pricePerUnit,
                      'total': t,
                    });
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

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProducts.isNotEmpty) {
      _amount = _calculatedAmount;
    }
    if (_amount <= 0 && _selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите сумму или добавьте товары')));
      return;
    }
    setState(() => _loading = true);
    final api = ApiClient();
    Map<String, dynamic> data = {
      'type': _type,
      'amount': _amount,
      'date': _date.toIso8601String(),
      'account_id': _accountId,
      'description': _description,
      'counterparty': _counterparty.isNotEmpty ? _counterparty : null,
    };
    if (_type == 'income' || _type == 'expense') {
      if (_categoryId != null) data['category_id'] = _categoryId;
      if (_selectedProducts.isNotEmpty) {
        data['items'] = _selectedProducts.map((p) => {
          'product_id': p['product_id'],
          'quantity': p['quantity'],
          'price_per_unit': p['price_per_unit'],
        }).toList();
      }
    } else if (_type == 'transfer') {
      if (_transferToAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите счёт получатель')),
        );
        setState(() => _loading = false);
        return;
      }
      if (_transferToAccountId == _accountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя переводить на тот же счёт')),
        );
        setState(() => _loading = false);
        return;
      }
      data['transfer_to_account_id'] = _transferToAccountId;
    }
    try {
      final response = await api.post('/transactions',
          queryParameters: {'company_id': widget.companyId}, data: data);
      final transactionId = response.data['id'];
      if (_photo != null) {
        await api.uploadPhoto('/transactions/$transactionId/upload', _photo!,
            queryParameters: {'company_id': widget.companyId});
      } else if (_webFile != null && _webFile!.bytes != null) {
        await api.uploadPhotoBytes('/transactions/$transactionId/upload',
            _webFile!.bytes!, _webFile!.name,
            queryParameters: {'company_id': widget.companyId});
      }
      await widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Insufficient stock')) {
          errorMessage = 'Недостаточно товара на складе для продажи';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $errorMessage')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAmountField = _selectedProducts.isEmpty;
    final effectiveAmount = showAmountField ? _amount : _calculatedAmount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_type == 'income'
          ? 'Новый приход (продажа)'
          : (_type == 'expense' ? 'Новый расход (покупка)' : 'Новый перевод')),
      content: Form(
        key: _formKey,
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 550),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        style: ButtonStyle(
                          foregroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) return Colors.black;
                            return Colors.grey.shade700;
                          }),
                          backgroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) return Colors.blue.shade200;
                            return Colors.grey.shade200;
                          }),
                        ),
                        segments: const [
                          ButtonSegment(value: 'income', label: Text('Приход (Продажа)'), icon: Icon(Icons.arrow_upward)),
                          ButtonSegment(value: 'expense', label: Text('Расход (Покупка)'), icon: Icon(Icons.arrow_downward)),
                          ButtonSegment(value: 'transfer', label: Text('Перевод'), icon: Icon(Icons.swap_horiz)),
                        ],
                        selected: {_type},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _type = newSelection.first;
                            if (_type == 'transfer') {
                              final available = widget.accounts.where((a) => a['id'] != _accountId).toList();
                              if (available.isNotEmpty) _transferToAccountId = available[0]['id'];
                            } else {
                              _transferToAccountId = null;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Контрагент (необязательно)', border: OutlineInputBorder()),
                  onChanged: (v) => _counterparty = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _accountId,
                  items: widget.accounts
                      .map<DropdownMenuItem<int>>(
                          (a) => DropdownMenuItem<int>(
                                value: a['id'],
                                child: Text(a['name']),
                              ))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _accountId = v;
                      if (_type == 'transfer') {
                        final available = widget.accounts.where((a) => a['id'] != _accountId).toList();
                        if (available.isNotEmpty) _transferToAccountId = available[0]['id'];
                      }
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Счёт', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (showAmountField)
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Сумма', border: OutlineInputBorder()),
                    onChanged: (v) => _amount = double.tryParse(v) ?? 0,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Введите сумму'
                        : (double.tryParse(v) == null ? 'Введите число' : null),
                  ),
                if (_type != 'transfer') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Добавить товар'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedProducts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Товары в операции:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _selectedProducts.length,
                        itemBuilder: (context, idx) {
                          final p = _selectedProducts[idx];
                          final productName = p['product_name']?.toString() ?? 'Товар';
                          final quantity = (p['quantity'] as num?)?.toDouble() ?? 0;
                          final total = (p['total'] as num?)?.toDouble() ?? 0;
                          return ListTile(
                            dense: true,
                            title: Text(productName),
                            subtitle: Text('$quantity шт — ${total.toStringAsFixed(2)} ₽'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeProduct(idx),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Итого: ${effectiveAmount.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ],
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Дата'),
                  trailing: Text(DateFormat('dd.MM.yyyy', 'ru').format(_date)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      locale: const Locale('ru', 'RU'),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 12),
                if ((_type == 'income' || _type == 'expense') && _selectedProducts.isEmpty)
                  DropdownButtonFormField<int>(
                    value: _categoryId,
                    items: widget.categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text('${c['icon'] ?? '📁'} ${c['name']}'),
                        )).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    decoration: const InputDecoration(labelText: 'Категория (необязательно)', border: OutlineInputBorder()),
                  ),
                if (_type == 'transfer')
                  DropdownButtonFormField<int>(
                    value: _transferToAccountId,
                    items: widget.accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(
                          value: a['id'],
                          child: Text(a['name']),
                        )).toList(),
                    onChanged: (v) => setState(() => _transferToAccountId = v),
                    decoration: const InputDecoration(labelText: 'Счёт получатель', border: OutlineInputBorder()),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder()),
                  onChanged: (v) => _description = v,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Файл'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
                    ),
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Камера'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
                    ),
                  ],
                ),
                if (_photo != null || _webFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(_photo != null ? _photo!.name : _webFile!.name),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() {
                            _photo = null;
                            _webFile = null;
                          }),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}