import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ManageCategoriesDialog extends ConsumerStatefulWidget {
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
  ConsumerState<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends ConsumerState<ManageCategoriesDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = '💰';
  bool _loading = false;
  late List<dynamic> _localCategories;

  final List<String> _icons = [
    '💼', '💰', '🏦', '📈', '📉', '💳', '💸', '💵', '💶', '💷',
    '👥', '👤', '🤝', '👨‍💼', '👩‍💼', '🛒', '📦', '🚚', '📊', '📋',
    '🗂️', '📎', '🍔', '🍕', '☕', '🥗', '🚗', '⛽', '✈️', '🏠',
    '🔧', '💡', '📱', '🎓', '💊', '🎁', '⚖️', '🖥️', '🎨', '🌱',
    '🐾', '💪', '🎬', '📚', '🔨'
  ];

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  Future<void> _addCategory() async {
    if (_nameController.text.isEmpty) return;
    final t = AppLocalizations.of(context)!;
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
      final newCategory = response.data;
      setState(() {
        _localCategories.add(newCategory);
      });
      _nameController.clear();
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.categoryAdded)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final t = AppLocalizations.of(context)!;
    final api = ApiClient();
    try {
      await api.delete('/categories/$id',
          queryParameters: {'company_id': widget.companyId});
      setState(() {
        _localCategories.removeWhere((c) => c['id'] == id);
      });
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.categoryDeleted)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(t.manageCategories, style: TextStyle(color: colorScheme.onSurface)),
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
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: t.nameLabel,
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
                        ))),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedIcon,
                  items: _icons
                      .map((icon) =>
                          DropdownMenuItem(value: icon, child: Text(icon, style: const TextStyle(fontSize: 24))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedIcon = v!),
                  dropdownColor: colorScheme.surface,
                ),
                const SizedBox(width: 8),
                _loading
                    ? const SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _addCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        child: Text(t.add)),
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
                    leading: Text(c['icon'] ?? '📁', style: const TextStyle(fontSize: 24)),
                    title: Text(c['name'], style: TextStyle(color: colorScheme.onSurface)),
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
            child: Text(t.close, style: TextStyle(color: colorScheme.onSurfaceVariant))),
      ],
    );
  }
}