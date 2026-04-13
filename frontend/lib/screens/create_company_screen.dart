import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() =>
      _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _innController = TextEditingController();
  final _nameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final List<Map<String, String>> _employees = [];
  bool _isLoading = false;

  void _addEmployee() =>
      setState(() => _employees.add({'full_name': '', 'phone': ''}));
  void _removeEmployee(int i) => setState(() => _employees.removeAt(i));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final api = ApiClient();
      final response = await api.post('/companies', data: {
        'inn': _innController.text,
        'name': _nameController.text,
        'bank_account': _bankAccountController.text,
        'manager_full_name': _managerNameController.text,
        'manager_phone': _managerPhoneController.text,
        'employees': _employees
            .where((e) => e['full_name']!.isNotEmpty && e['phone']!.isNotEmpty)
            .toList(),
      });
      final credentials = response.data['employees_credentials'] as List? ?? [];
      if (mounted) {
        if (credentials.isNotEmpty) {
          _showCredentialsDialog(credentials);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog(List<dynamic> credentials) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Пароли сотрудников'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: credentials.length,
            itemBuilder: (context, index) {
              final emp = credentials[index];
              final role = emp['role'] ?? 'employee';
              final roleText = role == 'manager' ? 'Управляющий' : 'Сотрудник';
              return ListTile(
                title: Text('${emp['full_name']} ($roleText)'),
                subtitle: Text(
                    'Телефон: ${emp['phone']}\nПароль: ${emp['password']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: emp['password']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Пароль скопирован')),
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая компания')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
                controller: _innController,
                decoration: const InputDecoration(labelText: 'ИНН'),
                validator: (v) => v!.isEmpty ? 'Введите ИНН' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название'),
                validator: (v) => v!.isEmpty ? 'Введите название' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _bankAccountController,
                decoration: const InputDecoration(labelText: 'Р/счёт'),
                validator: (v) => v!.isEmpty ? 'Введите р/счёт' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _managerNameController,
                decoration:
                    const InputDecoration(labelText: 'Управляющий (ФИО)'),
                validator: (v) => v!.isEmpty ? 'Введите ФИО' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _managerPhoneController,
                decoration:
                    const InputDecoration(labelText: 'Телефон управляющего'),
                validator: (v) => v!.isEmpty ? 'Введите телефон' : null),
            const SizedBox(height: 20),
            const Text('Сотрудники (необязательно):',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ..._employees.asMap().entries.map((e) {
              int idx = e.key;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: e.value['full_name'],
                        decoration: const InputDecoration(labelText: 'ФИО'),
                        onChanged: (v) => _employees[idx]['full_name'] = v,
                      ),
                      TextFormField(
                        initialValue: e.value['phone'],
                        decoration: const InputDecoration(labelText: 'Телефон'),
                        onChanged: (v) => _employees[idx]['phone'] = v,
                      ),
                      Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeEmployee(idx))),
                    ],
                  ),
                ),
              );
            }),
            TextButton.icon(
                onPressed: _addEmployee,
                icon: const Icon(Icons.add),
                label: const Text('Добавить сотрудника')),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit, child: const Text('Создать компанию')),
          ],
        ),
      ),
    );
  }
}
