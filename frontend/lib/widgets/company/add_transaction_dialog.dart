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
  const AddTransactionDialog({
    super.key,
    required this.companyId,
    required this.onSuccess,
    required this.accounts,
    required this.categories,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'income';
  double _amount = 0;
  DateTime _date = DateTime.now();
  int? _accountId;
  int? _categoryId;
  int? _transferToAccountId;
  String _description = '';
  bool _loading = false;
  XFile? _photo;
  PlatformFile? _webFile;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _accountId = widget.accounts[0]['id'];
      // Если изначально тип transfer, выбираем получателя
      if (_type == 'transfer') {
        final available =
            widget.accounts.where((a) => a['id'] != _accountId).toList();
        if (available.isNotEmpty) _transferToAccountId = available[0]['id'];
      }
    }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сумма должна быть больше 0')));
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
    };
    if (_type == 'income' || _type == 'expense') {
      if (_categoryId != null) data['category_id'] = _categoryId;
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
    // ОТЛАДКА
    print('=== Sending data: $data');
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_type == 'income'
          ? 'Новый доход'
          : (_type == 'expense' ? 'Новый расход' : 'Новый перевод')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
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
                          final available = widget.accounts
                              .where((a) => a['id'] != _accountId)
                              .toList();
                          if (available.isNotEmpty) {
                            _transferToAccountId = available[0]['id'];
                          } else {
                            _transferToAccountId = null;
                          }
                        }
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Счёт', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Доход')),
                      DropdownMenuItem(value: 'expense', child: Text('Расход')),
                      DropdownMenuItem(
                          value: 'transfer', child: Text('Перевод')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _type = v!;
                        if (_type == 'transfer') {
                          final available = widget.accounts
                              .where((a) => a['id'] != _accountId)
                              .toList();
                          if (available.isNotEmpty) {
                            _transferToAccountId = available[0]['id'];
                          }
                        } else {
                          _transferToAccountId = null;
                        }
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Тип', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Сумма', border: OutlineInputBorder()),
              onChanged: (v) => _amount = double.tryParse(v) ?? 0,
              validator: (v) => v == null || v.isEmpty
                  ? 'Введите сумму'
                  : (double.tryParse(v) == null ? 'Введите число' : null),
            ),
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
            if (_type == 'income' || _type == 'expense')
              DropdownButtonFormField<int>(
                value: _categoryId,
                items: widget.categories
                    .map<DropdownMenuItem<int>>((c) => DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text('${c['icon'] ?? '📁'} ${c['name']}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: const InputDecoration(
                    labelText: 'Категория (необязательно)',
                    border: OutlineInputBorder()),
              ),
            if (_type == 'transfer')
              DropdownButtonFormField<int>(
                value: _transferToAccountId,
                items: widget.accounts
                    .map<DropdownMenuItem<int>>((a) => DropdownMenuItem<int>(
                          value: a['id'],
                          child: Text(a['name']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _transferToAccountId = v),
                decoration: const InputDecoration(
                    labelText: 'Счёт получатель', border: OutlineInputBorder()),
              ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                  labelText: 'Описание', border: OutlineInputBorder()),
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
                ),
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Камера'),
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
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: const Text('Сохранить')),
      ],
    );
  }
}
