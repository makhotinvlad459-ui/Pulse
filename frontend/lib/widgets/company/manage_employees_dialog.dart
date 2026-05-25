import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user.dart';
import 'member_permissions_dialog.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ManageEmployeesDialog extends ConsumerStatefulWidget {
  final int companyId;
  final VoidCallback onSuccess;
  const ManageEmployeesDialog(
      {super.key, required this.companyId, required this.onSuccess});

  @override
  ConsumerState<ManageEmployeesDialog> createState() => _ManageEmployeesDialogState();
}

class _ManageEmployeesDialogState extends ConsumerState<ManageEmployeesDialog> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedRole = 'employee';
  bool _adding = false;
  Set<String> _currentUserPermissions = {};
  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded && mounted) {
      _dataLoaded = true;
      _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final myPerms = await api.getMyPermissions(widget.companyId);
      _currentUserPermissions = Set<String>.from(myPerms['permissions']);

      final response = await api.get('/companies/${widget.companyId}/members');
      List<Map<String, dynamic>> members = List<Map<String, dynamic>>.from(response.data);
      final authState = ref.read(authProvider);
      final currentUserId = authState.user?.id;
      members.removeWhere((m) => m['is_founder'] == true || m['user_id'] == currentUserId);
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _adding = true);
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;
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
            SnackBar(content: Text(t.userAssignedAsManager)));
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
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    } finally {
      setState(() => _adding = false);
    }
  }

  void _showPasswordDialog(String fullName, String password) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t.passwordFor} $fullName', style: TextStyle(color: colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${t.loginLabel}: ${t.phoneLabel}', style: TextStyle(color: colorScheme.onSurface)),
            Text('${t.passwordLabel}: $password', style: TextStyle(color: colorScheme.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: password));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.passwordCopied)));
              },
              icon: const Icon(Icons.copy),
              label: Text(t.copyPassword),
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
              child: Text(t.close, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ],
      ),
    );
  }

  Future<void> _resetPassword(int userId, String fullName) async {
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;
    try {
      final response = await api.post(
          '/companies/${widget.companyId}/members/$userId/reset-password');
      final newPassword = response.data['new_password'];
      _showPasswordDialog(fullName, newPassword);
      widget.onSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _removeMember(int userId, String fullName) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t.deleteEmployee} $fullName?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(t.employeeWillLoseAccess),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.delete, style: const TextStyle(color: Colors.red))),
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
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  Future<void> _editMember(Map<String, dynamic> member) async {
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: member['full_name']);
    final phoneController = TextEditingController(text: member['phone']);
    String currentRole = member['role_in_company'];
    String selectedRole = currentRole;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${t.editEmployee} ${member['full_name']}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: t.fullName),
                validator: (v) => v == null || v.isEmpty ? t.enterFullName : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(labelText: t.phoneLabel),
                validator: (v) => v == null || v.isEmpty ? t.enterPhone : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: [
                  DropdownMenuItem(value: 'employee', child: Text(t.employeeRole)),
                  DropdownMenuItem(value: 'manager', child: Text(t.managerRole)),
                ],
                onChanged: (v) => selectedRole = v!,
                decoration: InputDecoration(labelText: t.roleLabel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final api = ApiClient();
              try {
                await api.put('/companies/${widget.companyId}/members/${member['user_id']}', data: {
                  'full_name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'role_in_company': selectedRole,
                });
                
                // Обновляем локальный список мгновенно
                setState(() {
                  final index = _members.indexWhere((m) => m['user_id'] == member['user_id']);
                  if (index != -1) {
                    _members[index]['full_name'] = nameController.text.trim();
                    _members[index]['phone'] = phoneController.text.trim();
                    _members[index]['role_in_company'] = selectedRole;
                  }
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.employeeUpdated)),
                );
                Navigator.pop(context);
                widget.onSuccess();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${t.error}: $e')),
                );
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    );
  }

  bool get _canManageEmployees => _currentUserPermissions.contains('manage_employees');
  bool get _canManagePermissions => _currentUserPermissions.contains('manage_permissions');

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: isSmallScreen ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - 100,
        ),
        color: colorScheme.surface,
        child: Column(
          children: [
            AppBar(
              title: Text(t.manageEmployees),
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
                child: isSmallScreen
                    ? Column(
                        children: [
                          TextFormField(
                            controller: _fullNameController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: t.fullName,
                              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? t.enterFullName : null,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: t.phoneLabel,
                              labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: colorScheme.outline),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? t.enterPhone : null,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedRole,
                                  items: [
                                    DropdownMenuItem(value: 'employee', child: Text(t.employeeRole)),
                                    DropdownMenuItem(value: 'manager', child: Text(t.managerRole)),
                                  ],
                                  onChanged: (v) => setState(() => _selectedRole = v!),
                                  decoration: InputDecoration(
                                    labelText: t.roleLabel,
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(color: colorScheme.outline),
                                    ),
                                  ),
                                  dropdownColor: colorScheme.surface,
                                  style: TextStyle(color: colorScheme.onSurface),
                                ),
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
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(t.add),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fullNameController,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: InputDecoration(
                                labelText: t.fullName,
                                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: colorScheme.outline),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? t.enterFullName : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              style: TextStyle(color: colorScheme.onSurface),
                              decoration: InputDecoration(
                                labelText: t.phoneLabel,
                                labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: colorScheme.outline),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty ? t.enterPhone : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedRole,
                            items: [
                              DropdownMenuItem(value: 'employee', child: Text(t.employeeRole)),
                              DropdownMenuItem(value: 'manager', child: Text(t.managerRole)),
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
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(t.add),
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
                        final roleText = isManager ? t.managerRole : t.employeeRole;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            title: Text(m['full_name'], style: TextStyle(color: colorScheme.onSurface)),
                            subtitle: Text('${m['phone']} • $roleText', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_canManageEmployees || isFounder)
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editMember(m),
                                    tooltip: t.editEmployee,
                                  ),
                                if (_canManagePermissions || isFounder)
                                  IconButton(
                                    icon: Icon(Icons.security, color: Colors.blue),
                                    onPressed: () async {
                                      final api = ApiClient();
                                      final res = await api.getCompanyPermissions(widget.companyId);
                                      final membersList = res;
                                      final thisMember = membersList.firstWhere(
                                        (member) => member['member_id'] == m['id'],
                                        orElse: () => null,
                                      );
                                      if (thisMember == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(t.failedToLoadPermissions)));
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
                                          currentUserPermissions: _currentUserPermissions,
                                        ),
                                      );
                                    },
                                    tooltip: t.managePermissionsTooltip,
                                  ),
                                if (_canManageEmployees || isFounder)
                                  IconButton(
                                    icon: Icon(Icons.refresh, color: Colors.blueGrey),
                                    onPressed: () => _resetPassword(m['user_id'], m['full_name']),
                                    tooltip: t.resetPasswordTooltip,
                                  ),
                                if (_canManageEmployees || isFounder)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeMember(m['user_id'], m['full_name']),
                                    tooltip: t.deleteEmployeeTooltip,
                                  ),
                              ],
                            ),
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