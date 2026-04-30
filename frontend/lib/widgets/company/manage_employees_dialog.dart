import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import 'member_permissions_dialog.dart';

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
  String _selectedRole = 'employee';
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
      List<Map<String, dynamic>> members = List<Map<String, dynamic>>.from(response.data);
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authProvider);
      final currentUserId = authState.user?.id;
      // Исключаем учредителя (is_founder == true) и текущего пользователя
      members.removeWhere((m) => m['is_founder'] == true || m['user_id'] == currentUserId);
      setState(() {
        _members = members;
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
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Пароль для $fullName', style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Логин: телефон', style: TextStyle(color: colorScheme.onSurface)),
            Text('Пароль: $password', style: TextStyle(color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: password));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пароль скопирован')));
              },
              icon: const Icon(Icons.copy),
              label: const Text('Копировать пароль'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Закрыть', style: TextStyle(color: colorScheme.onSurfaceVariant))),
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
        title: Text('Удалить $fullName?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: const Text('Сотрудник потеряет доступ к компании.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
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

  Future<bool> _canManageEmployees() async {
    final api = ApiClient();
    try {
      final myPerms = await api.getMyPermissions(widget.companyId);
      final permsList = List<String>.from(myPerms['permissions']);
      return permsList.contains('manage_employees');
    } catch (e) {
      return false;
    }
  }

  Future<bool> _canManagePermissions() async {
    final api = ApiClient();
    try {
      final myPerms = await api.getMyPermissions(widget.companyId);
      final permsList = List<String>.from(myPerms['permissions']);
      return permsList.contains('manage_permissions');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final container = ProviderScope.containerOf(context);
    final authState = container.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 600),
        color: colorScheme.surface,
        child: Column(
          children: [
            AppBar(
              title: const Text('Управление сотрудниками'),
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colorScheme.onSurface))
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
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'ФИО',
                              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.primary),
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Введите ФИО' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'Телефон',
                              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.primary),
                              ),
                            ),
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
                          dropdownColor: colorScheme.surface,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _adding ? null : _addMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
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
                  : FutureBuilder<(bool, bool)>(
                      future: Future.wait([_canManageEmployees(), _canManagePermissions()])
                          .then((results) => (results[0], results[1])),
                      builder: (context, snapshot) {
                        final canManageEmployees = isFounder || (snapshot.data?.$1 ?? false);
                        final canManagePermissions = isFounder || (snapshot.data?.$2 ?? false);
                        return ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final m = _members[index];
                            return ListTile(
                              title: Text(m['full_name'], style: TextStyle(color: colorScheme.onSurface)),
                              subtitle: Text(m['phone'], style: TextStyle(color: colorScheme.onSurfaceVariant)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canManagePermissions)
                                    IconButton(
                                      icon: Icon(Icons.security, color: Colors.blue),
                                      onPressed: () async {
                                        final api = ApiClient();
                                        final res = await api.getCompanyPermissions(widget.companyId);
                                        final membersList = res as List;
                                        final thisMember = membersList.firstWhere(
                                          (member) => member['member_id'] == m['id'],
                                          orElse: () => null,
                                        );
                                        if (thisMember == null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Не удалось загрузить права сотрудника')));
                                          return;
                                        }
                                        final currentPermissions = List<String>.from(thisMember['permissions'] ?? []);
                                        await showDialog(
                                          context: context,
                                          builder: (_) => MemberPermissionsDialog(
                                            companyId: widget.companyId,
                                            memberId: m['id'],
                                            memberName: m['full_name'],
                                            currentPermissions: currentPermissions,
                                            onSuccess: () {
                                              widget.onSuccess();
                                            },
                                            isFounder: false,
                                          ),
                                        );
                                      },
                                      tooltip: 'Управление правами',
                                    ),
                                  if (canManageEmployees)
                                    IconButton(
                                      icon: Icon(Icons.refresh, color: Colors.blueGrey),
                                      onPressed: () => _resetPassword(m['user_id'], m['full_name']),
                                      tooltip: 'Сбросить пароль',
                                    ),
                                  if (canManageEmployees)
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeMember(m['user_id'], m['full_name']),
                                      tooltip: 'Удалить сотрудника',
                                    ),
                                ],
                              ),
                            );
                          },
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