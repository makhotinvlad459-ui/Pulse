import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class MemberPermissionsDialog extends StatefulWidget {
  final int companyId;
  final int memberId;
  final String memberName;
  final List<String> currentPermissions;
  final VoidCallback onSuccess;
  final bool isFounder;
  final Set<String> currentUserPermissions; // права текущего пользователя

  const MemberPermissionsDialog({
    super.key,
    required this.companyId,
    required this.memberId,
    required this.memberName,
    required this.currentPermissions,
    required this.onSuccess,
    required this.isFounder,
    required this.currentUserPermissions,
  });

  @override
  State<MemberPermissionsDialog> createState() => _MemberPermissionsDialogState();
}

class _MemberPermissionsDialogState extends State<MemberPermissionsDialog> {
  late Map<String, bool> _permissionsState;
  List<dynamic> _allPermissions = [];
  bool _loading = true;

  // Группировка прав по категориям
  final Map<String, List<String>> _groupMap = {
    'Операции': ['view_operations', 'create_transaction', 'edit_transaction'],
    'Витрина': ['view_showcase', 'edit_showcase', 'sell_from_showcase'],
    'Чат и Задачи': ['view_chat', 'send_messages', 'view_tasks', 'create_task', 'edit_task'],
    'Склад': ['view_products', 'create_product', 'edit_product', 'view_materials', 'create_material', 'edit_material'],
    'Отчеты': ['view_reports'],
    'Управление': ['manage_employees', 'manage_permissions', 'view_accounts', 'create_account', 'manage_categories', 'edit_company', 'view_archive'],
    'Документы': ['view_documents', 'create_documents', 'edit_documents'],
    'Заявки': ['view_requests', 'create_requests', 'edit_requests'],
  };

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final api = ApiClient();
    try {
      final res = await api.getAllPermissions();
      setState(() {
        _allPermissions = res;
        _permissionsState = {
          for (var p in res) p['name'] as String: widget.currentPermissions.contains(p['name'])
        };
        _loading = false;
      });
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final selected = _permissionsState.entries.where((e) => e.value).map((e) => e.key).toList();
    final api = ApiClient();
    try {
      await api.updateMemberPermissions(widget.companyId, widget.memberId, selected);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Права сохранены')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  String _translatePermissionName(String name) {
    switch (name) {
      case 'view_operations': return 'Просмотр операций';
      case 'create_transaction': return 'Создание операций';
      case 'edit_transaction': return 'Редактирование операций';
      case 'view_showcase': return 'Просмотр витрины';
      case 'edit_showcase': return 'Редактирование витрины';
      case 'sell_from_showcase': return 'Продажа с витрины';
      case 'view_chat': return 'Просмотр чата';
      case 'send_messages': return 'Отправка сообщений';
      case 'view_tasks': return 'Просмотр задач';
      case 'create_task': return 'Создание задач';
      case 'edit_task': return 'Редактирование задач';
      case 'manage_employees': return 'Управление сотрудниками';
      case 'manage_permissions': return 'Управление правами';
      case 'view_accounts': return 'Просмотр счетов';
      case 'create_account': return 'Создание счетов';
      case 'manage_categories': return 'Управление категориями';
      case 'view_reports': return 'Просмотр отчётов';
      case 'edit_company': return 'Редактирование компании';
      case 'view_archive': return 'Просмотр архива';
      case 'view_documents': return 'Просмотр документов';
      case 'create_documents': return 'Создание документов';
      case 'edit_documents': return 'Редактирование документов';
      case 'view_requests': return 'Просмотр заявок';
      case 'create_requests': return 'Создание заявок';
      case 'edit_requests': return 'Редактирование заявок';
      case 'view_products': return 'Просмотр товаров';
      case 'create_product': return 'Создание товаров';
      case 'edit_product': return 'Редактирование товаров';
      case 'view_materials': return 'Просмотр материалов';
      case 'create_material': return 'Создание материалов';
      case 'edit_material': return 'Редактирование материалов';
      default: return name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Определяем, какие права доступны для назначения
    final isFounderOrHasFull = widget.isFounder || widget.currentUserPermissions.isEmpty;
    final Set<String> allowedPermissions = isFounderOrHasFull
        ? _groupMap.values.expand((list) => list).toSet()
        : widget.currentUserPermissions;

    // Фильтруем группы: оставляем только те, где есть хотя бы один разрешённый пермишен
    final filteredGroups = _groupMap.entries.where((entry) {
      return entry.value.any((perm) => allowedPermissions.contains(perm));
    }).toList();

    return AlertDialog(
      title: Text('Права сотрудника: ${widget.memberName}', style: TextStyle(color: colorScheme.onSurface)),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: double.maxFinite,
              height: 500,
              child: ListView(
                children: filteredGroups.map((entry) {
                  final groupName = entry.key;
                  final permNames = entry.value;
                  // Отбираем только разрешённые права внутри группы
                  final groupPerms = _allPermissions.where((p) => permNames.contains(p['name']) && allowedPermissions.contains(p['name'])).toList();
                  if (groupPerms.isEmpty) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: colorScheme.surface,
                    child: ExpansionTile(
                      title: Text(groupName, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      children: groupPerms.map((p) {
                        final name = p['name'] as String;
                        final description = p['description'] as String?;
                        // Запрещаем снимать manage_permissions у учредителя (но учредитель не в списке, так что не актуально)
                        final enabled = true;
                        return CheckboxListTile(
                          title: Text(_translatePermissionName(name), style: TextStyle(color: colorScheme.onSurface)),
                          subtitle: description != null ? Text(description, style: TextStyle(color: colorScheme.onSurfaceVariant)) : null,
                          value: _permissionsState[name],
                          onChanged: enabled ? (val) => setState(() => _permissionsState[name] = val ?? false) : null,
                          activeColor: colorScheme.primary,
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}