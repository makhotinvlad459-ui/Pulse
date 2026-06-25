import 'package:flutter/material.dart';
import '../../../services/api_client.dart';
import '../../../l10n/app_localizations.dart';

class JournalCompleteDialog extends StatefulWidget {
  final int companyId;

  const JournalCompleteDialog({super.key, required this.companyId});

  @override
  State<JournalCompleteDialog> createState() => _JournalCompleteDialogState();
}

class _JournalCompleteDialogState extends State<JournalCompleteDialog> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  int? _selectedAccountId;
  
  // ✅ ДОБАВЛЕН ФЛАГ
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _loadAccounts();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (_isDisposed) return;
    
    final api = ApiClient();
    try {
      final res = await api.get('/accounts', queryParameters: {'company_id': widget.companyId});
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() {
        _accounts = List<Map<String, dynamic>>.from(res.data);
        _loading = false;
        if (_accounts.isNotEmpty) _selectedAccountId = _accounts.first['id'];
      });
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(t.selectAccountForIncome, style: TextStyle(color: colorScheme.onSurface)),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: _accounts.map((acc) {
                final icon = acc['type'] == 'cash' ? Icons.money : Icons.account_balance;
                return RadioListTile<int>(
                  title: Text(acc['name']),
                  subtitle: Text('${t.balanceLabel}: ${acc['balance']} ${t.currencySymbol}'),
                  value: acc['id'],
                  groupValue: _selectedAccountId,
                  onChanged: (value) {
                    if (!_isDisposed && mounted) {
                      setState(() => _selectedAccountId = value);
                    }
                  },
                  secondary: Icon(icon, color: colorScheme.primary),
                );
              }).toList(),
            ),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
          child: Text(t.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedAccountId != null) {
              if (mounted) Navigator.pop(context, _selectedAccountId);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.selectAccount)));
              }
            }
          },
          child: Text(t.complete),
        ),
      ],
    );
  }
}