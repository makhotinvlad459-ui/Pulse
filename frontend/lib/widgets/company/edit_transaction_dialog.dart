import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/api_client.dart';

class EditTransactionDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final int companyId;
  final List<dynamic> accounts;
  final List<dynamic> categories;
  final Future<void> Function() onSuccess;
  final bool isFounder;
  const EditTransactionDialog({
    super.key,
    required this.transaction,
    required this.companyId,
    required this.accounts,
    required this.categories,
    required this.onSuccess,
    required this.isFounder,
  });

  @override
  State<EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<EditTransactionDialog> {
  late String _type;
  late double _amount;
  late DateTime _date;
  late int _accountId;
  late int? _categoryId;
  late int? _transferToAccountId;
  late String _description;
  late String _counterparty;
  List<Map<String, dynamic>> _selectedProducts = [];
  bool _loading = false;
  XFile? _photo;
  PlatformFile? _webFile;
  bool _hasExistingAttachment = false;

  @override
  void initState() {
    super.initState();
    _type = widget.transaction['type'] ?? 'income';
    _amount = (widget.transaction['amount'] as num?)?.toDouble() ?? 0;
    _date = widget.transaction['date'] != null ? DateTime.parse(widget.transaction['date']) : DateTime.now();
    _accountId = widget.transaction['account_id'] ?? 0;
    _categoryId = widget.transaction['category_id'];
    _transferToAccountId = widget.transaction['transfer_to_account_id'];
    _description = widget.transaction['description'] ?? '';
    _counterparty = widget.transaction['counterparty'] ?? '';
    _hasExistingAttachment = widget.transaction['attachment_url'] != null;

    final items = widget.transaction['items'] as List?;
    if (items != null) {
      _selectedProducts = items.map((item) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        final pricePerUnit = (item['price_per_unit'] as num?)?.toDouble() ?? 0;
        final productName = item['product_name']?.toString() ?? 'Товар';
        final total = quantity * pricePerUnit;
        return {
          'product_id': item['product_id'] ?? 0,
          'product_name': productName,
          'quantity': quantity,
          'price_per_unit': pricePerUnit,
          'total': total,
        };
      }).toList();
    }

    final accountIds = widget.accounts.map((a) => a['id'] as int).toList();
    if (!accountIds.contains(_accountId) && widget.accounts.isNotEmpty) {
      _accountId = widget.accounts[0]['id'];
    }
    if (_transferToAccountId != null && !accountIds.contains(_transferToAccountId)) {
      _transferToAccountId = null;
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
      if (result != null) {
        setState(() {
          _webFile = result.files.first;
          _hasExistingAttachment = false;
        });
      }
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) setState(() {
        _photo = picked;
        _hasExistingAttachment = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      await _pickFile();
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) setState(() {
        _photo = picked;
        _hasExistingAttachment = false;
      });
    }
  }

  Future<void> _deleteAttachment() async {
    setState(() {
      _hasExistingAttachment = false;
      _photo = null;
      _webFile = null;
    });
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

  void _editProduct(int index) async {
    final product = _selectedProducts[index];
    final quantityController = TextEditingController(text: product['quantity'].toString());
    final totalController = TextEditingController(text: product['total'].toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать товар'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              if (q == null || t == null || q <= 0 || t <= 0) return;
              final pricePerUnit = t / q;
              setState(() {
                _selectedProducts[index] = {
                  ...product,
                  'quantity': q,
                  'total': t,
                  'price_per_unit': pricePerUnit,
                };
              });
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final api = ApiClient();
    Map<String, dynamic> data = {
      'type': _type,
      'amount': _selectedProducts.isNotEmpty ? _calculatedAmount : _amount,
      'date': _date.toIso8601String(),
      'account_id': _accountId,
      'description': _description,
      'counterparty': _counterparty.isNotEmpty ? _counterparty : null,
      'delete_attachment': !_hasExistingAttachment && _photo == null && _webFile == null,
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
      data['transfer_to_account_id'] = _transferToAccountId;
    }
    try {
      await api.patch('/transactions/${widget.transaction['id']}',
          queryParameters: {'company_id': widget.companyId}, data: data);
      if ((_photo != null || _webFile != null) && !_hasExistingAttachment) {
        if (_photo != null) {
          await api.uploadPhoto('/transactions/${widget.transaction['id']}/upload', _photo!,
              queryParameters: {'company_id': widget.companyId});
        } else if (_webFile != null && _webFile!.bytes != null) {
          await api.uploadPhotoBytes('/transactions/${widget.transaction['id']}/upload',
              _webFile!.bytes!, _webFile!.name,
              queryParameters: {'company_id': widget.companyId});
        }
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

  Future<void> _deleteTransaction() async {
    String title, content, confirmText;
    if (widget.isFounder) {
      title = 'Удалить операцию';
      content = 'Операция будет удалена навсегда. Восстановление невозможно.';
      confirmText = 'Удалить';
    } else {
      title = 'Скрыть операцию';
      content = 'Операция будет скрыта из отчётов, но останется в истории. Вы сможете восстановить её позже.';
      confirmText = 'Скрыть';
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText, style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    final api = ApiClient();
    try {
      await api.delete('/transactions/${widget.transaction['id']}',
          queryParameters: {'company_id': widget.companyId});
      await widget.onSuccess();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isFounder ? 'Операция удалена' : 'Операция скрыта')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showAmountField = _selectedProducts.isEmpty;
    final effectiveAmount = showAmountField ? _amount : _calculatedAmount;

    if (widget.accounts.isEmpty) {
      return AlertDialog(
        title: const Text('Ошибка'),
        content: const Text('Нет доступных счетов для редактирования.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть'))],
      );
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_type == 'income' ? 'Редактировать приход (продажа)' : (_type == 'expense' ? 'Редактировать расход (покупка)' : 'Редактировать перевод')),
      content: Container(
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
                initialValue: _counterparty,
                decoration: const InputDecoration(labelText: 'Контрагент (необязательно)', border: OutlineInputBorder()),
                onChanged: (v) => _counterparty = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _accountId,
                items: widget.accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(value: a['id'], child: Text(a['name']))).toList(),
                onChanged: (v) {
                  setState(() {
                    _accountId = v!;
                    if (_type == 'transfer') {
                      final available = widget.accounts.where((a) => a['id'] != _accountId).toList();
                      if (available.isNotEmpty) _transferToAccountId = available[0]['id'];
                      else _transferToAccountId = null;
                    }
                  });
                },
                decoration: const InputDecoration(labelText: 'Счёт', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (showAmountField)
                TextFormField(
                  initialValue: _amount.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Сумма', border: OutlineInputBorder()),
                  onChanged: (v) => _amount = double.tryParse(v) ?? 0,
                ),
              if (!showAmountField)
                Text('Сумма: ${effectiveAmount.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  items: widget.categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem<int>(value: c['id'], child: Text('${c['icon'] ?? '📁'} ${c['name']}'))).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  decoration: const InputDecoration(labelText: 'Категория (необязательно)', border: OutlineInputBorder()),
                ),
              if (_type == 'transfer')
                DropdownButtonFormField<int>(
                  value: _transferToAccountId,
                  items: widget.accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(value: a['id'], child: Text(a['name']))).toList(),
                  onChanged: (v) => setState(() => _transferToAccountId = v),
                  decoration: const InputDecoration(labelText: 'Счёт получатель', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder()),
                onChanged: (v) => _description = v,
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                onPressed: () => _editProduct(idx),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeProduct(idx),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
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
              if (_hasExistingAttachment && _photo == null && _webFile == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.attachment, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Есть вложение'),
                      TextButton(onPressed: _deleteAttachment, child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                    ],
                  ),
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: _deleteTransaction, child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}