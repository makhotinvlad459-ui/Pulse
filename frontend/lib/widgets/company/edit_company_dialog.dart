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
  late TextEditingController _managerNameController;
  late TextEditingController _managerPhoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _managerNameController =
        TextEditingController(text: widget.company.managerFullName);
    _managerPhoneController =
        TextEditingController(text: widget.company.managerPhone);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;
    try {
      await api.put('/companies/${widget.company.id}', data: {
        'name': _nameController.text,
        'manager_full_name': _managerNameController.text,
        'manager_phone': _managerPhoneController.text,
      });
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.companyUpdated)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(t.editCompanyTitle, style: TextStyle(color: colorScheme.onSurface)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
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
              TextFormField(
                  controller: _managerPhoneController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: t.phoneLogin,
                    hintText: t.min6Chars,
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: Text(t.save)),
      ],
    );
  }
}