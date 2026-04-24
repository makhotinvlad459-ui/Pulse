import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class ManageCategoriesDialog extends StatefulWidget {
  final int companyId;
  final VoidCallback onSuccess;
  final List<dynamic> categories;
  const ManageCategoriesDialog({
    super.key,
    required this.companyId,
    required this.onSuccess,
    required this.categories,
  });

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = '💰';
  bool _loading = false;
  late List<dynamic> _localCategories;

  final List<String> _icons = [
    '💼',
    '💰',
    '🏦',
    '📈',
    '📉',
    '💳',
    '💸',
    '💵',
    '💶',
    '💷',
    '👥',
    '👤',
    '🤝',
    '👨‍💼',
    '👩‍💼',
    '🛒',
    '📦',
    '🚚',
    '📊',
    '📋',
    '🗂️',
    '📎',
    '🍔',
    '🍕',
    '☕',
    '🥗',
    '🚗',
    '⛽',
    '✈️',
    '🏠',
    '🔧',
    '💡',
    '📱',
    '🎓',
    '💊',
    '🎁',
    '⚖️',
    '🖥️',
    '🎨',
    '🌱',
    '🐾',
    '💪',
    '🎬',
    '📚',
    '🔨'
  ];

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  Future<void> _addCategory() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final response = await api.post('/categories/', queryParameters: {
        'company_id': widget.companyId
      }, data: {
        'name': _nameController.text,
        'type': 'income',
        'icon': _selectedIcon,
      });
      // Добавляем новую категорию в локальный список
      final newCategory = response.data;
      setState(() {
        _localCategories.add(newCategory);
      });
      _nameController.clear();
      widget.onSuccess(); // уведомляем родителя, что данные изменились
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Категория добавлена')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final api = ApiClient();
    try {
      await api.delete('/categories/$id',
          queryParameters: {'company_id': widget.companyId});
      setState(() {
        _localCategories.removeWhere((c) => c['id'] == id);
      });
      widget.onSuccess();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Категория удалена')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Управление категориями'),
      content: SizedBox(
        width: 500,
        height: 500,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Название'))),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedIcon,
                  items: _icons
                      .map((icon) =>
                          DropdownMenuItem(value: icon, child: Text(icon)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedIcon = v!),
                ),
                const SizedBox(width: 8),
                _loading
                    ? const SizedBox(
                        width: 24, child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _addCategory, child: const Text('Добавить')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _localCategories.length,
                itemBuilder: (context, index) {
                  final c = _localCategories[index];
                  if (c['is_system']) return const SizedBox.shrink();
                  return ListTile(
                    leading: Text(c['icon'] ?? '📁'),
                    title: Text(c['name']),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCategory(c['id'])),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть')),
      ],
    );
  }
}
