import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class AddAccountDialog extends ConsumerStatefulWidget {
  final int companyId;
  final VoidCallback onSuccess;
  const AddAccountDialog(
      {super.key, required this.companyId, required this.onSuccess});

  @override
  ConsumerState<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<AddAccountDialog> {
  final _nameController = TextEditingController();
  bool _includeInProfitLoss = true;
  bool _loading = false;

  Future<void> _submit() async {
    final t = AppLocalizations.of(context)!;
    if (_nameController.text.isEmpty) return;
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      await api.post('/accounts/', queryParameters: {
        'company_id': widget.companyId
      }, data: {
        'name': _nameController.text,
        'type': 'other',
        'include_in_profit_loss': _includeInProfitLoss,
      });
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(t.newCustomAccount, style: TextStyle(color: colorScheme.onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: t.accountName, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
              style: TextStyle(color: colorScheme.onSurface)),
          SwitchListTile(
            title: Text(t.includeInProfitLoss, style: TextStyle(color: colorScheme.onSurface)),
            value: _includeInProfitLoss,
            onChanged: (v) => setState(() => _includeInProfitLoss = v),
          ),
          Text(
            t.profitLossHint,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: Text(t.create)),
      ],
    );
  }
}