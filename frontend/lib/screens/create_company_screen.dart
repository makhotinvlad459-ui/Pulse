import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../providers/locale_provider.dart';
import '../screens/subscription_screen.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() =>
      _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
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
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;

    // 1. Проверяем, может ли пользователь создавать новую компанию
    try {
      final statusRes = await api.get('/subscription/status');
      final data = statusRes.data;
      final canCreate = data['can_create_company'] as bool;
      if (!canCreate) {
        setState(() => _isLoading = false);
        _showLimitDialog();
        return;
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // Если запрос статуса не удался, всё равно пробуем создать (может, бэкенд ещё не обновлён)
      // Но лучше прервать и показать ошибку.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
      return;
    }

    // 2. Создаём компанию
    try {
      final response = await api.post('/companies/', data: {
        'name': _nameController.text,
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
      if (mounted) {
        String errorMsg = e.toString();
        // Если бэкенд вернул 403 с сообщением о лимите – показываем диалог
        if (errorMsg.contains('Company limit reached')) {
          _showLimitDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.error}: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLimitDialog() {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t.companyLimitReached),
        content: Text(t.companyLimitMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.close),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // закрываем диалог
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: Text(t.buySubscription),
          ),
        ],
      ),
    );
  }

  void _showCredentialsDialog(List<dynamic> credentials) {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(t.employeePasswords),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: credentials.length,
            itemBuilder: (context, index) {
              final emp = credentials[index];
              final role = emp['role'] ?? 'employee';
              final roleText = role == 'manager' ? t.managerRole : t.employeeRole;
              return ListTile(
                title: Text('${emp['full_name']} ($roleText)'),
                subtitle: Text('${t.phoneLabel}: ${emp['phone']}\n${t.passwordLabel}: ${emp['password']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: emp['password']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t.passwordCopied)),
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
            child: Text(t.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.newCompany),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
                controller: _nameController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: t.companyName,
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
                validator: (v) => v!.isEmpty ? t.enterCompanyName : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _managerNameController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: t.managerFullName,
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
                validator: (v) => v!.isEmpty ? t.enterFullName : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _managerPhoneController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: t.managerPhoneLogin,
                  helperText: t.phoneHelperText,
                  helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),
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
                validator: (v) {
                  if (v == null || v.isEmpty) return t.enterPhone;
                  if (v.length < 6) return t.min6Chars;
                  return null;
                }),
            const SizedBox(height: 20),
            Text(t.employeesOptional,
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
                        decoration: InputDecoration(labelText: t.fullName),
                        onChanged: (v) => _employees[idx]['full_name'] = v,
                      ),
                      TextFormField(
                        initialValue: e.value['phone'],
                        decoration: InputDecoration(labelText: t.phoneLogin),
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
                label: Text(t.addEmployee)),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit, child: Text(t.createCompany)),
          ],
        ),
      ),
    );
  }
}