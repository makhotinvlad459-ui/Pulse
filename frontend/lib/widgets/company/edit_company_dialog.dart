import 'package:flutter/material.dart';
import '../../models/company.dart';
import '../../services/api_client.dart';

class EditCompanyDialog extends StatefulWidget {
  final Company company;
  final VoidCallback onSuccess;
  const EditCompanyDialog(
      {super.key, required this.company, required this.onSuccess});

  @override
  State<EditCompanyDialog> createState() => _EditCompanyDialogState();
}

class _EditCompanyDialogState extends State<EditCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _innController;
  late TextEditingController _bankAccountController;
  late TextEditingController _managerNameController;
  late TextEditingController _managerPhoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _innController = TextEditingController(text: widget.company.inn);
    _bankAccountController =
        TextEditingController(text: widget.company.bankAccount);
    _managerNameController =
        TextEditingController(text: widget.company.managerFullName);
    _managerPhoneController =
        TextEditingController(text: widget.company.managerPhone);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ApiClient();
    try {
      await api.put('/companies/${widget.company.id}', data: {
        'name': _nameController.text,
        'inn': _innController.text,
        'bank_account': _bankAccountController.text,
        'manager_full_name': _managerNameController.text,
        'manager_phone': _managerPhoneController.text,
      });
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Компания обновлена')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать компанию'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Название'),
                  validator: (v) => v!.isEmpty ? 'Введите название' : null),
              TextFormField(
                  controller: _innController,
                  decoration: const InputDecoration(labelText: 'ИНН'),
                  validator: (v) => v!.isEmpty ? 'Введите ИНН' : null),
              TextFormField(
                  controller: _bankAccountController,
                  decoration: const InputDecoration(labelText: 'Р/счёт'),
                  validator: (v) => v!.isEmpty ? 'Введите р/счёт' : null),
              TextFormField(
                  controller: _managerNameController,
                  decoration:
                      const InputDecoration(labelText: 'Управляющий (ФИО)'),
                  validator: (v) => v!.isEmpty ? 'Введите ФИО' : null),
              TextFormField(
                  controller: _managerPhoneController,
                  decoration: const InputDecoration(labelText: 'Телефон'),
                  validator: (v) => v!.isEmpty ? 'Введите телефон' : null),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
            onPressed: _saving ? null : _save, child: const Text('Сохранить')),
      ],
    );
  }
}
