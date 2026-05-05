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

class EditTransactionDialog extends ConsumerStatefulWidget {
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
  ConsumerState<EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends ConsumerState<EditTransactionDialog> {
  late String _type;
  late double _amount;
  late DateTime _date;
  late int _accountId;
  late int? _categoryId;
  late int? _transferToAccountId;
  late String _description;
  late String _counterparty;
  final TextEditingController _counterpartyController = TextEditingController();
  List<String> _existingCounterparties = [];
  bool _loadingCounterparties = false;
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
    _counterpartyController.text = _counterparty;
    _hasExistingAttachment = widget.transaction['attachment_url'] != null;

    final items = widget.transaction['items'] as List?;
    if (items != null) {
      _selectedProducts = items.map((item) {
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        final pricePerUnit = (item['price_per_unit'] as num?)?.toDouble() ?? 0;
        final productName = item['product_name']?.toString() ?? 'Product';
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
      if (picked != null) {
        final compressed = await ImageCompression.compressImage(picked);
        setState(() {
          _photo = compressed;
          _hasExistingAttachment = false;
        });
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
        setState(() {
          _photo = compressed;
          _hasExistingAttachment = false;
        });
      }
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
                  final q = quantity;
                  final tot = total;
                  if (selectedProductId == null || q <= 0 || tot <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.fillAllFields)));
                    return;
                  }
                  final pricePerUnit = tot / q;
                  setState(() {
                    _selectedProducts.add({
                      'product_id': selectedProductId,
                      'product_name': selectedProduct?['name'] ?? '',
                      'quantity': q,
                      'price_per_unit': pricePerUnit,
                      'total': tot,
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

  void _editProduct(int index) async {
    final t = AppLocalizations.of(context)!;
    final product = _selectedProducts[index];
    final quantityController = TextEditingController(text: product['quantity'].toString());
    final totalController = TextEditingController(text: product['total'].toString());
    double quantity = product['quantity'];
    double total = product['total'];
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.editProductTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              if (quantity <= 0 || total <= 0) return;
              final pricePerUnit = total / quantity;
              setState(() {
                _selectedProducts[index] = {
                  ...product,
                  'quantity': quantity,
                  'total': total,
                  'price_per_unit': pricePerUnit,
                };
              });
              Navigator.pop(context);
            },
            child: Text(t.save),
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
      'amount': _amount,
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

  Future<void> _deleteTransaction() async {
    final t = AppLocalizations.of(context)!;
    String title, content, confirmText;
    if (widget.isFounder) {
      title = t.deleteTransactionTitle;
      content = t.deleteTransactionContentPermanent;
      confirmText = t.delete;
    } else {
      title = t.hideTransactionTitle;
      content = t.hideTransactionContent;
      confirmText = t.hide;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmText, style: const TextStyle(color: Colors.red))),
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
        SnackBar(content: Text(widget.isFounder ? t.transactionDeletedPermanent : t.transactionHidden)),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    if (widget.accounts.isEmpty) {
      return AlertDialog(
        title: Text(t.error),
        content: Text(t.noAccountsAvailable),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close))],
      );
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        _type == 'income' ? t.editIncomeTitle : (_type == 'expense' ? t.editExpenseTitle : t.editTransferTitle),
        style: TextStyle(color: colorScheme.onSurface),
      ),
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
                        visualDensity: VisualDensity.compact,
                        textStyle: MaterialStateProperty.all(
                          TextStyle(fontSize: isSmallScreen ? 11 : 13),
                        ),
                        padding: MaterialStateProperty.all(
                          EdgeInsets.symmetric(horizontal: isSmallScreen ? 4 : 8),
                        ),
                        foregroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return colorScheme.onSurface;
                          return colorScheme.onSurfaceVariant;
                        }),
                        backgroundColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return colorScheme.primary.withOpacity(0.2);
                          return colorScheme.surfaceContainerHighest;
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
                items: widget.accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(
                      value: a['id'],
                      child: Text(a['name'], style: TextStyle(color: colorScheme.onSurface)),
                    )).toList(),
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
                decoration: InputDecoration(
                  labelText: t.accountLabel,
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                ),
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _amount.toString(),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.amountLabel,
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                ),
                style: TextStyle(color: colorScheme.onSurface),
                onChanged: (v) => _amount = _parseAmount(v),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(t.dateLabel, style: TextStyle(color: colorScheme.onSurface)),
                trailing: Text(DateFormat('dd.MM.yyyy', 'ru').format(_date), style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                        child: Text('${c['icon'] ?? '📁'} ${c['name']}', style: TextStyle(color: colorScheme.onSurface)),
                      )).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                  decoration: InputDecoration(
                    labelText: t.categoryOptional,
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                  ),
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              if (_type == 'transfer')
                DropdownButtonFormField<int>(
                  value: _transferToAccountId,
                  items: widget.accounts.map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(
                        value: a['id'],
                        child: Text(a['name'], style: TextStyle(color: colorScheme.onSurface)),
                      )).toList(),
                  onChanged: (v) => setState(() => _transferToAccountId = v),
                  decoration: InputDecoration(
                    labelText: t.toAccountLabel,
                    labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                  ),
                  dropdownColor: colorScheme.surface,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _description,
                decoration: InputDecoration(
                  labelText: t.descriptionLabel,
                  labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                  border: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.outline)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
                ),
                style: TextStyle(color: colorScheme.onSurface),
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
                        label: Text(t.addProductButton),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary.withOpacity(0.2),
                          foregroundColor: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedProducts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(t.productsInOperation, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
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
                          title: Text(productName, style: TextStyle(color: colorScheme.onSurface)),
                          subtitle: Text('$quantity ${t.pcs} — ${total.toStringAsFixed(2)} ₽', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, size: 18, color: colorScheme.primary),
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
                    label: Text(t.fileButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary.withOpacity(0.2),
                      foregroundColor: colorScheme.onSurface,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(t.cameraButton),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary.withOpacity(0.2),
                      foregroundColor: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (_hasExistingAttachment && _photo == null && _webFile == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.attachment, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(t.hasAttachment, style: TextStyle(color: colorScheme.onSurface)),
                      TextButton(onPressed: _deleteAttachment, child: Text(t.delete, style: const TextStyle(color: Colors.red))),
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
                      Text(_photo != null ? _photo!.name : _webFile!.name, style: TextStyle(color: colorScheme.onSurface)),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        TextButton(
          onPressed: _deleteTransaction,
          child: Text(t.delete, style: const TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Text(t.save),
        ),
      ],
    );
  }
}