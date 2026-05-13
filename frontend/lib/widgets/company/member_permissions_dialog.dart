import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class MemberPermissionsDialog extends ConsumerStatefulWidget {
  final int companyId;
  final int memberId;
  final String memberName;
  final List<String> currentPermissions;
  final VoidCallback onSuccess;
  final bool isFounder;
  final Set<String> currentUserPermissions;

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
  ConsumerState<MemberPermissionsDialog> createState() => _MemberPermissionsDialogState();
}

class _MemberPermissionsDialogState extends ConsumerState<MemberPermissionsDialog> {
  late Map<String, bool> _permissionsState;
  List<dynamic> _allPermissions = [];
  bool _loading = true;

  final Map<String, List<String>> _groupKeys = {
    'operations': ['view_operations', 'create_transaction', 'edit_transaction'],
    'showcase': ['view_showcase', 'edit_showcase', 'sell_from_showcase'],
    'chat_tasks': ['view_chat', 'send_messages', 'view_tasks', 'create_task', 'edit_task'],
    'stock': ['view_products', 'create_product', 'edit_product', 'view_materials', 'create_material', 'edit_material'],
    'reports': ['view_reports'],
    'management': ['manage_employees', 'manage_permissions', 'view_accounts', 'create_account', 'manage_categories', 'edit_company', 'view_archive'],
    'documents': ['view_documents', 'create_documents', 'edit_documents'],
    'counterparties': ['view_counterparties', 'edit_counterparties'],
    'orders': ['view_orders', 'edit_orders'],
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
    final t = AppLocalizations.of(context)!;
    try {
      await api.updateMemberPermissions(widget.companyId, widget.memberId, selected);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.permissionsSaved)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  String _translatePermissionName(String name, AppLocalizations t) {
    switch (name) {
      case 'view_operations': return t.permViewOperations;
      case 'create_transaction': return t.permCreateTransaction;
      case 'edit_transaction': return t.permEditTransaction;
      case 'view_counterparties': return t.permViewCounterparties;
      case 'edit_counterparties': return t.permEditCounterparties;
      case 'view_showcase': return t.permViewShowcase;
      case 'edit_showcase': return t.permEditShowcase;
      case 'sell_from_showcase': return t.permSellFromShowcase;
      case 'view_chat': return t.permViewChat;
      case 'send_messages': return t.permSendMessages;
      case 'view_tasks': return t.permViewTasks;
      case 'create_task': return t.permCreateTask;
      case 'edit_task': return t.permEditTask;
      case 'view_products': return t.permViewProducts;
      case 'create_product': return t.permCreateProduct;
      case 'edit_product': return t.permEditProduct;
      case 'view_materials': return t.permViewMaterials;
      case 'create_material': return t.permCreateMaterial;
      case 'edit_material': return t.permEditMaterial;
      case 'view_reports': return t.permViewReports;
      case 'manage_employees': return t.permManageEmployees;
      case 'manage_permissions': return t.permManagePermissions;
      case 'view_accounts': return t.permViewAccounts;
      case 'create_account': return t.permCreateAccount;
      case 'manage_categories': return t.permManageCategories;
      case 'edit_company': return t.permEditCompany;
      case 'view_archive': return t.permViewArchive;
      case 'view_documents': return t.permViewDocuments;
      case 'create_documents': return t.permCreateDocuments;
      case 'edit_documents': return t.permEditDocuments;
      case 'view_orders': return t.permViewOrders;
      case 'edit_orders': return t.permEditOrders;
      default: return name;
    }
  }

  String _getGroupTitle(String groupKey, AppLocalizations t) {
    switch (groupKey) {
      case 'operations': return t.groupOperations;
      case 'showcase': return t.groupShowcase;
      case 'chat_tasks': return t.groupChatTasks;
      case 'stock': return t.groupStock;
      case 'reports': return t.groupReports;
      case 'management': return t.groupManagement;
      case 'documents': return t.groupDocuments;
      case 'counterparties': return t.groupCounterparties;
      case 'orders': return t.groupOrders;
      default: return groupKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final isFounderOrHasFull = widget.isFounder || widget.currentUserPermissions.isEmpty;
    final Set<String> allowedPermissions = isFounderOrHasFull
        ? _groupKeys.values.expand((list) => list).toSet()
        : widget.currentUserPermissions;

    final filteredGroups = _groupKeys.entries.where((entry) {
      return entry.value.any((perm) => allowedPermissions.contains(perm));
    }).toList();

    return AlertDialog(
      title: Text('${t.employeePermissions}: ${widget.memberName}', style: TextStyle(color: colorScheme.onSurface)),
      content: _loading
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: double.maxFinite,
              height: 500,
              child: ListView(
                children: filteredGroups.map((entry) {
                  final groupKey = entry.key;
                  final permNames = entry.value;
                  final groupPerms = _allPermissions.where((p) => permNames.contains(p['name']) && allowedPermissions.contains(p['name'])).toList();
                  if (groupPerms.isEmpty) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: colorScheme.surface,
                    child: ExpansionTile(
                      title: Text(_getGroupTitle(groupKey, t), style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      children: groupPerms.map((p) {
                        final name = p['name'] as String;
                        final enabled = true;
                        return CheckboxListTile(
                          title: Text(_translatePermissionName(name, t), style: TextStyle(color: colorScheme.onSurface)),
                          // subtitle убран, чтобы избежать дублирования
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Text(t.save),
        ),
      ],
    );
  }
}