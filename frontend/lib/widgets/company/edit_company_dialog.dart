import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/company.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class EditCompanyDialog extends ConsumerStatefulWidget {
  final Company company;
  final VoidCallback onSuccess;
  const EditCompanyDialog(
      {super.key, required this.company, required this.onSuccess});

  @override
  ConsumerState<EditCompanyDialog> createState() => _EditCompanyDialogState();
}

class _EditCompanyDialogState extends ConsumerState<EditCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _innController;
  late TextEditingController _bankAccountController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _innController = TextEditingController(text: widget.company.inn);
    _bankAccountController = TextEditingController(text: widget.company.bankAccount);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _innController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _saving = true);
  final api = ApiClient();
  final t = AppLocalizations.of(context)!;
  
  try {
    // 1. Отправляем данные на обновленный PUT-эндпоинт
    final response = await api.put('/companies/${widget.company.id}', data: {
      'name': _nameController.text,
      'inn': _innController.text,
      'bank_account': _bankAccountController.text,
    });

    // 2. Десериализуем обновленный объект компании, который вернул бэкенд
    final updatedCompany = Company.fromJson(response.data);

    widget.onSuccess();
    
    // 3. Передаем этот обновленный объект обратно в Navigator.pop!
    if (mounted) Navigator.pop(context, updatedCompany);
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: isSmallScreen ? double.infinity : 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height - 100,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: colorScheme.onPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.editCompanyTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colorScheme.onPrimary),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: t.companyName,
                        icon: Icons.business,
                        validator: (v) => v!.isEmpty ? t.enterCompanyName : null,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _innController,
                        label: t.innLabel,
                        icon: Icons.numbers,
                        keyboardType: TextInputType.number,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _bankAccountController,
                        label: t.bankAccountLabel,
                        icon: Icons.account_balance,
                        keyboardType: TextInputType.number,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    child: Text(t.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ColorScheme colorScheme,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      validator: validator,
    );
  }
}