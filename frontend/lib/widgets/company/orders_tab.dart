import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../providers/auth_provider.dart';
import 'orders/order_details_dialog.dart';
import 'orders/create_order_dialog.dart';

class OrdersTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  final bool isFounder;

  const OrdersTab({
    super.key,
    required this.companyId,
    required this.permissions,
    required this.isFounder,
  });

  @override
  ConsumerState<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<OrdersTab> {
  List<dynamic> _orders = [];
  bool _loading = true;
  List<Map<String, dynamic>> _companyMembers = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadCompanyMembers();
  }

  Future<void> _loadCompanyMembers() async {
    final api = ApiClient();
    try {
      final res = await api.get('/orders/company/${widget.companyId}/members');
      setState(() {
        _companyMembers = List<Map<String, dynamic>>.from(res.data);
      });
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/orders', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _orders = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      String errorMsg = e.toString();
      if (errorMsg.contains('403')) {
        errorMsg = 'У вас нет прав для просмотра заказов';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $errorMsg')),
      );
    }
  }

  List<Map<String, dynamic>> get _pendingOrders =>
      _orders.where((o) => o['status'] == 'pending').cast<Map<String, dynamic>>().toList();
  List<Map<String, dynamic>> get _acceptedOrders =>
      _orders.where((o) => o['status'] == 'accepted').cast<Map<String, dynamic>>().toList();
  List<Map<String, dynamic>> get _completedOrders =>
      _orders.where((o) => o['status'] == 'completed').cast<Map<String, dynamic>>().toList();
  List<Map<String, dynamic>> get _failedOrders =>
      _orders.where((o) => o['status'] == 'failed').cast<Map<String, dynamic>>().toList();

  bool get _canView => widget.isFounder || widget.permissions.contains('view_orders');
  bool get _canEdit => widget.isFounder || widget.permissions.contains('edit_orders');

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    final api = ApiClient();
    try {
      await api.post('/orders/$orderId/status', queryParameters: {'company_id': widget.companyId}, data: {'status': newStatus});
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _deleteOrder(int orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заказ?'),
        content: const Text('Заказ будет удалён безвозвратно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/orders/$orderId', queryParameters: {'company_id': widget.companyId});
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void _showCreateOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateOrderDialog(
        companyId: widget.companyId,
        members: _companyMembers,
        onOrderCreated: _loadOrders,
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(
        order: order,
        companyId: widget.companyId,
        permissions: widget.permissions,
        isFounder: widget.isFounder,
        onOrderUpdated: _loadOrders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_canView) {
      return const Center(child: Text('Нет прав для просмотра заказов'));
    }
    return Column(
      children: [
        if (_canEdit)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _showCreateOrderDialog,
              icon: const Icon(Icons.add),
              label: const Text('Создать заказ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_pendingOrders.isNotEmpty)
                        _buildSection('Ожидают', _pendingOrders, Colors.orange, colorScheme),
                      if (_acceptedOrders.isNotEmpty)
                        _buildSection('Приняты', _acceptedOrders, Colors.blue, colorScheme),
                      if (_completedOrders.isNotEmpty)
                        _buildSection('Выполнены', _completedOrders, Colors.green, colorScheme),
                      if (_failedOrders.isNotEmpty)
                        _buildSection('Провалены', _failedOrders, Colors.red, colorScheme),
                      if (_orders.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Нет заказов', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Map<String, dynamic>> orders, Color color, ColorScheme colorScheme) {
    final canEditAny = _canEdit;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text('$title (${orders.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
          ],
        ),
        children: orders.map((order) {
          final isAssignee = order['assignee_id'] == ref.read(authProvider).user?.id;
          final canEditOrder = canEditAny && (order['status'] == 'pending' || order['status'] == 'accepted');
          final canAccept = canEditOrder && order['status'] == 'pending';
          final canComplete = canEditOrder && order['status'] == 'accepted';
          final canFail = canEditOrder && (order['status'] == 'pending' || order['status'] == 'accepted');
          final canDelete = canEditAny && (order['status'] == 'pending' || order['status'] == 'completed' || order['status'] == 'failed');
          final total = order['total_amount'] as num;
          final paid = order['paid_amount'] as num;
          final remaining = total - paid;
          final isFullyPaid = remaining <= 0;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: colorScheme.surfaceContainerHighest,
            child: ExpansionTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text('#${order['id']} ${order['title']}', 
                        style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                  ),
                  if (isFullyPaid)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Работы: ${order['work_price']} ₽', style: TextStyle(fontSize: 12)),
                  Text('Материалы: ${(total - (order['work_price'] as num)).toStringAsFixed(2)} ₽', style: TextStyle(fontSize: 12)),
                  Text('Оплачено: ${paid.toStringAsFixed(2)} ₽', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              trailing: canDelete
                  ? IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteOrder(order['id']),
                    )
                  : null,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order['description'] != null)
                        Text('📄 ${order['description']}', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      if (order['assignee_name'] != null)
                        Text('👤 Назначен: ${order['assignee_name']}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      if (order['deadline'] != null)
                        Text('⏰ Дедлайн: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(order['deadline']))}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      Text('💰 Остаток: ${remaining.toStringAsFixed(2)} ₽',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: remaining > 0 ? Colors.red : Colors.green)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (canAccept && (isAssignee || canEditOrder))
                            ElevatedButton(
                              onPressed: () => _updateOrderStatus(order['id'], 'accepted'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              child: const Text('Принять'),
                            ),
                          if (canComplete && (isAssignee || canEditOrder))
                            ElevatedButton(
                              onPressed: () => _updateOrderStatus(order['id'], 'completed'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: const Text('Выполнить'),
                            ),
                          if (canFail && (isAssignee || canEditOrder))
                            ElevatedButton(
                              onPressed: () => _updateOrderStatus(order['id'], 'failed'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: const Text('Провалить'),
                            ),
                          ElevatedButton(
                            onPressed: () => _showOrderDetails(order),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                            child: const Text('Детали'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}