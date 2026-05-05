import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

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

  bool get _canEdit => ref.read(authProvider).user?.role == UserRole.founder ||
      widget.permissions.contains('manage_counterparties');

  @override
  void initState() {
    super.initState();
    _loadCounterparties();
  }

  Future<void> _loadCounterparties() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/counterparties', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _counterparties = List<Map<String, dynamic>>.from(res.data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  // Диалог статистики контрагента (доход, расход, баланс, список операций)
  Future<void> _showStats(Map<String, dynamic> cp) async {
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
                              const Text('Доход:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${data['total_income']?.toStringAsFixed(2) ?? '0.00'} ₽',
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Расход:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('${data['total_expense']?.toStringAsFixed(2) ?? '0.00'} ₽',
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Баланс:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  const Text('Последние операции:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...(data['transactions'] as List).map((t) => ListTile(
                    dense: true,
                    title: Text('${t['amount']} ₽'),
                    subtitle: Text('${t['type'] == 'income' ? 'Приход' : 'Расход'} • ${t['description'] ?? ''}'),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(t['date']))),
                  )).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки статистики: $e')));
      }
    }
  }

  Future<void> _addEditCounterparty([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final innController = TextEditingController(text: existing?['inn'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    final directorController = TextEditingController(text: existing?['director'] ?? '');
    final api = ApiClient();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Редактировать контрагента' : 'Новый контрагент'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название*')),
              const SizedBox(height: 8),
              TextField(controller: innController, decoration: const InputDecoration(labelText: 'ИНН (необязательно)')),
              const SizedBox(height: 8),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Телефон (необязательно)')),
              const SizedBox(height: 8),
              TextField(controller: directorController, decoration: const InputDecoration(labelText: 'Директор (необязательно)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название')));
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
                Navigator.pop(context);
                _loadCounterparties();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            },
            child: Text(isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCounterparty(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить контрагента?'),
        content: Text('Контрагент "$name" будет удалён. Это не удалит связанные операции.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/counterparties/$id', queryParameters: {'company_id': widget.companyId});
      _loadCounterparties();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_canEdit)
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: () => _addEditCounterparty(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить контрагента'),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _counterparties.isEmpty
                  ? Center(child: Text('Нет контрагентов', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: _counterparties.length,
                      itemBuilder: (context, index) {
                        final cp = _counterparties[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: ListTile(
                            onTap: () => _showStats(cp),   // ← открываем статистику по тапу
                            title: Text(cp['name'], style: TextStyle(color: colorScheme.onSurface)),
                            subtitle: Text('ИНН: ${cp['inn'] ?? '—'} | Тел: ${cp['phone'] ?? '—'} | Директор: ${cp['director'] ?? '—'}'),
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