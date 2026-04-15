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
  bool _loading = false;
  XFile? _photo;
  PlatformFile? _webFile;
  bool _hasExistingAttachment = false;

  @override
  void initState() {
    super.initState();
    _type = widget.transaction['type'];
    _amount = (widget.transaction['amount'] as num).toDouble();
    _date = DateTime.parse(widget.transaction['date']);
    _accountId = widget.transaction['account_id'];
    _categoryId = widget.transaction['category_id'];
    _transferToAccountId = widget.transaction['transfer_to_account_id'];
    _description = widget.transaction['description'] ?? '';
    _hasExistingAttachment = widget.transaction['attachment_url'] != null;

    // Проверяем, существует ли выбранный счёт в списке accounts
    final accountIds = widget.accounts.map((a) => a['id'] as int).toList();
    if (!accountIds.contains(_accountId) && widget.accounts.isNotEmpty) {
      // Если счёт удалён, выбираем первый доступный счёт
      _accountId = widget.accounts[0]['id'];
    }
    // Для перевода проверяем счёт-получатель
    if (_transferToAccountId != null &&
        !accountIds.contains(_transferToAccountId)) {
      _transferToAccountId = null;
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
      if (picked != null)
        setState(() {
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
      if (picked != null)
        setState(() {
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

  Future<void> _save() async {
    setState(() => _loading = true);
    final api = ApiClient();
    Map<String, dynamic> data = {
      'type': _type,
      'amount': _amount,
      'date': _date.toIso8601String(),
      'account_id': _accountId,
      'description': _description,
      'delete_attachment':
          !_hasExistingAttachment && _photo == null && _webFile == null,
    };
    if (_type == 'income' || _type == 'expense') {
      if (_categoryId != null) data['category_id'] = _categoryId;
    } else if (_type == 'transfer') {
      data['transfer_to_account_id'] = _transferToAccountId;
    }
    try {
      await api.patch('/transactions/${widget.transaction['id']}',
          queryParameters: {'company_id': widget.companyId}, data: data);
      if ((_photo != null || _webFile != null) && !_hasExistingAttachment) {
        if (_photo != null) {
          await api.uploadPhoto(
              '/transactions/${widget.transaction['id']}/upload', _photo!,
              queryParameters: {'company_id': widget.companyId});
        } else if (_webFile != null && _webFile!.bytes != null) {
          await api.uploadPhotoBytes(
              '/transactions/${widget.transaction['id']}/upload',
              _webFile!.bytes!,
              _webFile!.name,
              queryParameters: {'company_id': widget.companyId});
        }
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

  Future<void> _deleteTransaction() async {
    String title, content, confirmText;
    if (widget.isFounder) {
      title = 'Удалить операцию';
      content = 'Операция будет удалена навсегда. Восстановление невозможно.';
      confirmText = 'Удалить';
    } else {
      title = 'Скрыть операцию';
      content =
          'Операция будет скрыта из отчётов, но останется в истории. Вы сможете восстановить её позже.';
      confirmText = 'Скрыть';
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText, style: TextStyle(color: Colors.red))),
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
        SnackBar(
            content: Text(
                widget.isFounder ? 'Операция удалена' : 'Операция скрыта')),
      );
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
    // Если список счетов пуст, показываем сообщение
    if (widget.accounts.isEmpty) {
      return AlertDialog(
        title: const Text('Ошибка'),
        content: const Text('Нет доступных счетов для редактирования.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_type == 'income'
          ? 'Редактировать доход'
          : (_type == 'expense'
              ? 'Редактировать расход'
              : 'Редактировать перевод')),
      content: SingleChildScrollView(
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
                    onChanged: (v) => setState(() => _accountId = v!),
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
                    onChanged: (v) => setState(() => _type = v!),
                    decoration: const InputDecoration(
                        labelText: 'Тип', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _amount.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Сумма', border: OutlineInputBorder()),
              onChanged: (v) => _amount = double.tryParse(v) ?? 0,
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
              initialValue: _description,
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
            if (_hasExistingAttachment && _photo == null && _webFile == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.attachment, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text('Есть вложение'),
                    TextButton(
                      onPressed: _deleteAttachment,
                      child: const Text('Удалить',
                          style: TextStyle(color: Colors.red)),
                    ),
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
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        TextButton(
            onPressed: _deleteTransaction,
            child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ElevatedButton(
            onPressed: _loading ? null : _save, child: const Text('Сохранить')),
      ],
    );
  }
}
