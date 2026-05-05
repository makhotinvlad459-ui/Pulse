import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
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
  ConsumerState<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
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

  List<String> _existingCounterparties = [];
  bool _loadingCounterparties = false;
  final TextEditingController _counterpartyController = TextEditingController();

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
    _loadCounterparties();
  }

  double _parseAmount(String text) {
    final normalized = text.replaceFirst(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _loadCounterparties() async {
    setState(() => _loadingCounterparties = true);
    final api = ApiClient();
    try {
      final res = await api.get('/statistics/counterparties', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _existingCounterparties = List<String>.from(res.data);
        _loadingCounterparties = false;
      });
    } catch (e) {
      setState(() => _loadingCounterparties = false);
      print('Error loading counterparties: $e');
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
      if (picked != null) {
        final compressed = await ImageCompression.compressImage(picked);
        setState(() => _photo = compressed);
      }
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      await _pickFile();
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        final compressed = await ImageCompression.compressImage(picked);
        setState(() => _photo = compressed);
      }
    }
  }

  Future<void> _addProduct() async {
    final t = AppLocalizations.of(context)!;
    final api = ApiClient();
    List<dynamic> products = [];
    try {
      final res = await api.get('/products', queryParameters: {'company_id': widget.companyId});
      products = res.data;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
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
            title: Text(t.addProductTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: t.productLabel),
                  items: products.map((p) {
                    return DropdownMenuItem<int>(
                      value: p['id'],
                      child: Text('${p['name']} (${t.remainingStock}: ${p['current_quantity']} ${p['unit']})'),
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
                  decoration: InputDecoration(labelText: t.quantityLabel),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => quantity = _parseAmount(v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: totalController,
                  decoration: InputDecoration(labelText: t.totalAmountLabel),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => total = _parseAmount(v),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
              ElevatedButton(
                onPressed: () {
                  if (selectedProductId == null || quantity <= 0 || total <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fillAllFields)));
                    return;
                  }
                  final pricePerUnit = total / quantity;
                  setState(() {
                    _selectedProducts.add({
                      'product_id': selectedProductId,
                      'product_name': selectedProduct?['name'] ?? '',
                      'quantity': quantity,
                      'price_per_unit': pricePerUnit,
                      'total': total,
                    });
                  });
                  Navigator.pop(context);
                },
                child: Text(t.add),
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
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.enterAmountOrProducts)));
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
      final t = AppLocalizations.of(context)!;
      if (_transferToAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectDestAccount)));
        setState(() => _loading = false);
        return;
      }
      if (_transferToAccountId == _accountId) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.cannotTransferSame)));
        setState(() => _loading = false);
        return;
      }
      data['transfer_to_account_id'] = _transferToAccountId;
    }
    try {
      final response = await api.post('/transactions/',
          queryParameters: {'company_id': widget.companyId}, data: data);
      final transactionId = response.data['id'];
      if (_photo != null) {
        await api.uploadPhoto('/transactions/$transactionId/upload', _photo!,
            queryParameters: {'company_id': widget.companyId});
      } else if (_webFile != null && _webFile!.bytes != null) {
        await api.uploadPhotoBytes('/transactions/$transactionId/upload/',
            _webFile!.bytes!, _webFile!.name,
            queryParameters: {'company_id': widget.companyId});
      }
      await widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        final t = AppLocalizations.of(context)!;
        if (errorMessage.contains('Insufficient stock')) {
          errorMessage = t.insufficientStock;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.error}: $errorMessage')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final isSmallScreen = MediaQuery.of(context).size.width < 500;
    final showAmountField = _selectedProducts.isEmpty;
    final effectiveAmount = showAmountField ? _amount : _calculatedAmount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_type == 'income'
          ? t.newIncomeTitle
          : (_type == 'expense' ? t.newExpenseTitle : t.newTransferTitle)),
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
                          visualDensity: VisualDensity.compact,
                          textStyle: MaterialStateProperty.all(
                            TextStyle(fontSize: isSmallScreen ? 11 : 13),
                          ),
                          padding: MaterialStateProperty.all(
                            EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 8),
                          ),
                          foregroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) return Colors.black;
                            return Colors.grey.shade700;
                          }),
                          backgroundColor: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) return Colors.blue.shade200;
                            return Colors.grey.shade200;
                          }),
                        ),
                        segments: [
                          ButtonSegment(
                            value: 'income',
                            label: Text(isSmallScreen ? t.incomeShort : t.incomeFull),
                            icon: isSmallScreen ? null : const Icon(Icons.arrow_upward),
                          ),
                          ButtonSegment(
                            value: 'expense',
                            label: Text(isSmallScreen ? t.expenseShort : t.expenseFull),
                            icon: isSmallScreen ? null : const Icon(Icons.arrow_downward),
                          ),
                          ButtonSegment(
                            value: 'transfer',
                            label: Text(isSmallScreen ? t.transferShort : t.transferFull),
                            icon: isSmallScreen ? null : const Icon(Icons.swap_horiz),
                          ),
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
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    final lower = textEditingValue.text.toLowerCase();
                    return _existingCounterparties.where((c) => c.toLowerCase().contains(lower));
                  },
                  onSelected: (String selection) {
                    setState(() {
                      _counterparty = selection;
                    });
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    textController.addListener(() {
                      _counterparty = textController.text;
                    });
                    return TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: t.counterpartyOptional,
                        border: const OutlineInputBorder(),
                        suffixIcon: _loadingCounterparties
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _loadCounterparties,
                                tooltip: t.refreshList,
                              ),
                      ),
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
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
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
                  decoration: InputDecoration(labelText: t.accountLabel, border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                if (showAmountField)
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t.amountLabel, border: const OutlineInputBorder()),
                    onChanged: (v) => _amount = _parseAmount(v),
                    validator: (v) => v == null || v.isEmpty
                        ? t.enterAmount
                        : (double.tryParse(v.replaceFirst(',', '.')) == null ? t.invalidNumber : null),
                  ),
                if (_type != 'transfer') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: Text(t.addProductButton),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedProducts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(t.productsInOperation, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _selectedProducts.length,
                        itemBuilder: (context, idx) {
                          final p = _selectedProducts[idx];
                          final productName = p['product_name']?.toString() ?? t.productLabel;
                          final quantity = (p['quantity'] as num?)?.toDouble() ?? 0;
                          final total = (p['total'] as num?)?.toDouble() ?? 0;
                          return ListTile(
                            dense: true,
                            title: Text(productName),
                            subtitle: Text('$quantity ${t.pcs} — ${total.toStringAsFixed(2)} ₽'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeProduct(idx),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${t.totalLabel}: ${effectiveAmount.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ],
                const SizedBox(height: 12),
                ListTile(
                  title: Text(t.dateLabel),
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
                if (_type == 'income' || _type == 'expense')
                  DropdownButtonFormField<int>(
                    value: _categoryId,
                    items: widget.categories.map<DropdownMenuItem<int>>((c) => DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text('${c['icon'] ?? '📁'} ${c['name']}'),
                        )).toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    decoration: InputDecoration(labelText: t.categoryOptional, border: const OutlineInputBorder()),
                  ),
                if (_type == 'transfer')
                  DropdownButtonFormField<int>(
                    value: _transferToAccountId,
                    items: widget.accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(
                          value: a['id'],
                          child: Text(a['name']),
                        )).toList(),
                    onChanged: (v) => setState(() => _transferToAccountId = v),
                    decoration: InputDecoration(labelText: t.toAccountLabel, border: const OutlineInputBorder()),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: InputDecoration(labelText: t.descriptionLabel, border: const OutlineInputBorder()),
                  onChanged: (v) => _description = v,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.attach_file),
                      label: Text(t.fileButton),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
                    ),
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(t.cameraButton),
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade200, foregroundColor: Colors.black),
          child: Text(t.save),
        ),
      ],
    );
  }
}