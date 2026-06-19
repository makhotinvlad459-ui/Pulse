import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'counterparties/counterparty_detail_screen.dart';

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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _canView => ref.read(authProvider).user?.role == UserRole.founder ||
      widget.permissions.contains('view_counterparties');
  bool get _canEdit => ref.read(authProvider).user?.role == UserRole.founder ||
      widget.permissions.contains('manage_counterparties');

  List<Map<String, dynamic>> get _filteredCounterparties {
    if (_searchQuery.isEmpty) return _counterparties;
    return _counterparties.where((cp) =>
        cp['name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCounterparties();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCounterparties() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ApiClient();
    try {
      // Загружаем контрагентов
      final res = await api.get('/counterparties', queryParameters: {'company_id': widget.companyId});
      if (!mounted) return;
      
      final List<Map<String, dynamic>> counterparties = List<Map<String, dynamic>>.from(res.data);
      
      // Для каждого контрагента загружаем статистику с учётом оплаты
      for (var i = 0; i < counterparties.length; i++) {
        try {
          final stats = await api.get('/statistics/counterparty-stats', queryParameters: {
            'company_id': widget.companyId,
            'counterparty': counterparties[i]['name'],
          });
          counterparties[i]['total_income'] = stats.data['total_income'] ?? 0;
          counterparties[i]['total_expense'] = stats.data['total_expense'] ?? 0;
          counterparties[i]['balance'] = stats.data['balance'] ?? 0;
          counterparties[i]['unpaid_income'] = stats.data['unpaid_income'] ?? 0;  // неоплаченные доходы
          counterparties[i]['unpaid_expense'] = stats.data['unpaid_expense'] ?? 0;  // неоплаченные расходы
        } catch (e) {
          print('Error loading stats for ${counterparties[i]['name']}: $e');
        }
      }
      
      setState(() {
        _counterparties = counterparties;
        _loading = false;
      });
    } catch (e) {
      print('Error loading counterparties: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) {
        final t = AppLocalizations.of(context)!;
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
                  await api.put('/counterparties/${existing['id']}', queryParameters: {'company_id': widget.companyId}, data: {
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
    final currency = t.currencySymbol;

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: t.searchByNameOrArticle,
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredCounterparties.isEmpty
                  ? Center(child: Text(
                      _searchQuery.isEmpty 
                          ? t.noCounterparties 
                          : t.noMatches,
                      style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: _filteredCounterparties.length,
                      itemBuilder: (context, index) {
                        final cp = _filteredCounterparties[index];
                        final balance = cp['balance'] ?? 0;
                        final unpaidIncome = cp['unpaid_income'] ?? 0;
                        final unpaidExpense = cp['unpaid_expense'] ?? 0;
                        final totalDebt = unpaidIncome - unpaidExpense;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CounterpartyDetailScreen(
                                    companyId: widget.companyId,
                                    counterparty: cp,
                                    permissions: widget.permissions,
                                  ),
                                ),
                              );
                            },
                            title: Text(cp['name'], style: TextStyle(color: colorScheme.onSurface)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t.innLabel}: ${cp['inn'] ?? '—'} | ${t.phoneLabel}: ${cp['phone'] ?? '—'} | ${t.directorLabel}: ${cp['director'] ?? '—'}'),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 12,
                                  children: [
                                    Text('💰 ${t.balance}: ${balance.toStringAsFixed(2)}$currency',
                                        style: TextStyle(
                                          color: balance >= 0 ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        )),
                                    if (totalDebt != 0)
                                      Text('⚠️ ${t.debt}: ${totalDebt.abs().toStringAsFixed(2)}$currency',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          )),
                                  ],
                                ),
                              ],
                            ),
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