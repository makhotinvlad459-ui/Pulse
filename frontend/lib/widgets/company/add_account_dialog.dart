import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class AddAccountDialog extends StatefulWidget {
  final int companyId;
  final VoidCallback onSuccess;
  const AddAccountDialog(
      {super.key, required this.companyId, required this.onSuccess});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final _nameController = TextEditingController();
  String _type = 'other';
  bool _includeInProfitLoss = true;
  bool _loading = false;

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      await api.post('/accounts', queryParameters: {
        'company_id': widget.companyId
      }, data: {
        'name': _nameController.text,
        'type': _type,
        'include_in_profit_loss': _includeInProfitLoss,
      });
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
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
    return AlertDialog(
      title: const Text('Новый счёт'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название счёта')),
          DropdownButtonFormField<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Наличные')),
              DropdownMenuItem(value: 'bank', child: Text('Банк')),
              DropdownMenuItem(value: 'other', child: Text('Другой')),
            ],
            onChanged: (v) => setState(() => _type = v!),
            decoration: const InputDecoration(labelText: 'Тип'),
          ),
          SwitchListTile(
            title: const Text('Учитывать в прибыли/убытке'),
            value: _includeInProfitLoss,
            onChanged: (v) => setState(() => _includeInProfitLoss = v),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
            onPressed: _loading ? null : _submit, child: const Text('Создать')),
      ],
    );
  }
}
