import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CounterpartiesTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  const CounterpartiesTab({super.key, required this.companyId, required this.permissions});

  @override
  ConsumerState<CounterpartiesTab> createState() => _CounterpartiesTabState();
}

class _CounterpartiesTabState extends ConsumerState<CounterpartiesTab> {
  List<Map<String, dynamic>> _counterparties = [];
  bool _loading = true;
  String? _error;

  bool get _canView => ref.read(authProvider).user?.role == UserRole.founder ||
      widget.permissions.contains('view_counterparties');
  bool get _canEdit => ref.read(authProvider).user?.role == UserRole.founder ||
      widget.permissions.contains('manage_counterparties');

  @override
  void initState() {
    super.initState();
    // Откладываем загрузку до первого кадра, чтобы context был готов
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCounterparties();
    });
  }

  Future<void> _loadCounterparties() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ApiClient();
    // Не используем AppLocalizations.of(context) здесь, чтобы не рисковать.
    // Получим его один раз в методе build или передадим в параметры.
    try {
      final res = await api.get('/counterparties', queryParameters: {'company_id': widget.companyId});
      if (!mounted) return;
      setState(() {
        _counterparties = List<Map<String, dynamic>>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      print('Error loading counterparties: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      // Используем context после mounted
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _showStats(Map<String, dynamic> cp) async {
    final t = AppLocalizations.of(context)!;
    final api = ApiClient();
    try {
      final res = await api.get('/statistics/counterparty-stats', queryParameters: {
        'company_id': widget.companyId,
        'counterparty': cp['name'],
      });
      final data = res.data;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(cp['name']),
          content: SizedBox(
            width: 400,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.income, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${data['total_income']?.toStringAsFixed(2) ?? '0.00'} ₽',
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.expense, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${data['total_expense']?.toStringAsFixed(2) ?? '0.00'} ₽',
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.balance, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${data['balance']?.toStringAsFixed(2) ?? '0.00'} ₽',
                                  style: TextStyle(
                                      color: (data['balance'] ?? 0) >= 0 ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(t.recentTransactions, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...(data['transactions'] as List).map((tItem) => ListTile(
                    dense: true,
                    title: Text('${tItem['amount']} ₽'),
                    subtitle: Text('${tItem['type'] == 'income' ? t.income : t.expense} • ${tItem['description'] ?? ''}'),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(tItem['date']))),
                  )).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }

  Future<void> _addEditCounterparty([Map<String, dynamic>? existing]) async {
    final t = AppLocalizations.of(context)!;
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final innController = TextEditingController(text: existing?['inn'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final directorController = TextEditingController(text: existing?['director'] ?? '');
    final api = ApiClient();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? t.editCounterparty : t.newCounterparty),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: t.nameRequired)),
              const SizedBox(height: 8),
              TextField(controller: innController, decoration: InputDecoration(labelText: t.innOptional)),
              const SizedBox(height: 8),
              TextField(controller: phoneController, decoration: InputDecoration(labelText: t.phoneOptional)),
              const SizedBox(height: 8),
              TextField(controller: directorController, decoration: InputDecoration(labelText: t.directorOptional)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.enterName)));
                return;
              }
              try {
                if (isEdit) {
                  await api.put('/counterparties/${existing!['id']}', queryParameters: {'company_id': widget.companyId}, data: {
                    'name': nameController.text,
                    'inn': innController.text,
                    'phone': phoneController.text,
                    'director': directorController.text,
                  });
                } else {
                  await api.post('/counterparties', queryParameters: {'company_id': widget.companyId}, data: {
                    'name': nameController.text,
                    'inn': innController.text,
                    'phone': phoneController.text,
                    'director': directorController.text,
                  });
                }
                if (!mounted) return;
                Navigator.pop(context);
                _loadCounterparties();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
              }
            },
            child: Text(isEdit ? t.save : t.create),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCounterparty(int id, String name) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteCounterpartyTitle),
        content: Text('${t.deleteCounterpartyContent} "$name". ${t.operationsNotDeleted}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/counterparties/$id', queryParameters: {'company_id': widget.companyId});
      _loadCounterparties();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;

    if (!_canView) {
      return Center(child: Text(t.noPermissionToViewCounterparties));
    }

    if (_error != null) {
      return Center(child: Text('${t.error}: $_error'));
    }

    return Column(
      children: [
        if (_canEdit)
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: () => _addEditCounterparty(),
              icon: const Icon(Icons.add),
              label: Text(t.addCounterparty),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _counterparties.isEmpty
                  ? Center(child: Text(t.noCounterparties, style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: _counterparties.length,
                      itemBuilder: (context, index) {
                        final cp = _counterparties[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            onTap: () => _showStats(cp),
                            title: Text(cp['name'], style: TextStyle(color: colorScheme.onSurface)),
                            subtitle: Text('${t.innLabel}: ${cp['inn'] ?? '—'} | ${t.phoneLabel}: ${cp['phone'] ?? '—'} | ${t.directorLabel}: ${cp['director'] ?? '—'}'),
                            trailing: _canEdit
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _addEditCounterparty(cp),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteCounterparty(cp['id'], cp['name']),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}