import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';

class ManageEmployeesDialog extends StatefulWidget {
  final int companyId;
  final VoidCallback onSuccess;
  const ManageEmployeesDialog(
      {super.key, required this.companyId, required this.onSuccess});

  @override
  State<ManageEmployeesDialog> createState() => _ManageEmployeesDialogState();
}

class _ManageEmployeesDialogState extends State<ManageEmployeesDialog> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedRole = 'employee'; // 'employee' или 'manager'
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final response = await api.get('/companies/${widget.companyId}/members');
      setState(() {
        _members = List<Map<String, dynamic>>.from(response.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _adding = true);
    final api = ApiClient();
    try {
      final response = await api.post(
        '/companies/${widget.companyId}/members',
        queryParameters: {
          'phone': _phoneController.text.trim(),
          'full_name': _fullNameController.text.trim(),
        },
      );
      final data = response.data;
      final userId = data['user_id'];
      // Если выбрана роль manager, то после добавления назначаем управляющим
      if (_selectedRole == 'manager') {
        await api.put('/companies/${widget.companyId}/manager',
            data: {'user_id': userId});
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пользователь назначен управляющим')));
      } else {
        if (data.containsKey('password')) {
          _showPasswordDialog(
              _fullNameController.text.trim(), data['password']);
        }
      }
      _phoneController.clear();
      _fullNameController.clear();
      await _loadMembers();
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _adding = false);
    }
  }

  void _showPasswordDialog(String fullName, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Пароль для $fullName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Логин: телефон\nПароль: $password'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: password));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пароль скопирован')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Копировать пароль'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<void> _resetPassword(int userId, String fullName) async {
    final api = ApiClient();
    try {
      final response = await api.post(
          '/companies/${widget.companyId}/members/$userId/reset-password');
      final newPassword = response.data['new_password'];
      _showPasswordDialog(fullName, newPassword);
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _removeMember(int userId, String fullName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить $fullName?'),
        content: const Text('Сотрудник потеряет доступ к компании.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/companies/${widget.companyId}/members/$userId');
      await _loadMembers();
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _setAsManager(int userId, String fullName) async {
    final api = ApiClient();
    try {
      await api.put('/companies/${widget.companyId}/manager',
          data: {'user_id': userId});
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fullName назначен управляющим')));
      await _loadMembers();
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _demoteToEmployee(int userId) async {
    final api = ApiClient();
    try {
      await api.patch('/companies/${widget.companyId}/members/$userId/role',
          data: {'role_in_company': 'employee'});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Роль изменена на сотрудника')));
      await _loadMembers();
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            AppBar(
              title: const Text('Управление сотрудниками'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(labelText: 'ФИО'),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Введите ФИО' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration:
                                const InputDecoration(labelText: 'Телефон'),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Введите телефон'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedRole,
                          items: const [
                            DropdownMenuItem(
                                value: 'employee', child: Text('Сотрудник')),
                            DropdownMenuItem(
                                value: 'manager', child: Text('Управляющий')),
                          ],
                          onChanged: (v) => setState(() => _selectedRole = v!),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _adding ? null : _addMember,
                          child: _adding
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Добавить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final m = _members[index];
                        final isManager = m['role_in_company'] == 'manager';
                        return ListTile(
                          title: Text(m['full_name']),
                          subtitle: Text(
                              '${m['phone']} • Роль: ${isManager ? 'Управляющий' : 'Сотрудник'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isManager)
                                IconButton(
                                  icon: const Icon(Icons.star,
                                      color: Colors.orange),
                                  onPressed: () => _setAsManager(
                                      m['user_id'], m['full_name']),
                                  tooltip: 'Назначить управляющим',
                                ),
                              if (isManager)
                                IconButton(
                                  icon: const Icon(Icons.star_border,
                                      color: Colors.grey),
                                  onPressed: () =>
                                      _demoteToEmployee(m['user_id']),
                                  tooltip: 'Понизить до сотрудника',
                                ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _resetPassword(
                                    m['user_id'], m['full_name']),
                                tooltip: 'Сбросить пароль',
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () =>
                                    _removeMember(m['user_id'], m['full_name']),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
