import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../services/api_client.dart';
import '../../../services/image_compression.dart';
import 'add_material_dialog.dart';

class OrderDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final int companyId;
  final Set<String> permissions;
  final bool isFounder;
  final VoidCallback onOrderUpdated;

  const OrderDetailsDialog({
    super.key,
    required this.order,
    required this.companyId,
    required this.permissions,
    required this.isFounder,
    required this.onOrderUpdated,
  });

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  late Map<String, dynamic> _fullOrder;
  late TextEditingController _workPriceController;
  List<dynamic> _products = [];
  bool _isEditable = false;

  bool get _canEdit => widget.isFounder || widget.permissions.contains('edit_orders');
  bool get _canView => widget.isFounder || widget.permissions.contains('view_orders');

  @override
  void initState() {
    super.initState();
    _fullOrder = Map.from(widget.order);
    _workPriceController = TextEditingController(
        text: (_fullOrder['work_price'] ?? 0).toString());
    _isEditable = _fullOrder['status'] == 'pending' ||
        _fullOrder['status'] == 'accepted';
    if (_isEditable && _canEdit) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    final api = ApiClient();
    try {
      final res = await api.get('/products/',
          queryParameters: {'company_id': widget.companyId});
      setState(() {
        _products = res.data;
      });
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  Future<void> _refreshOrder() async {
    final api = ApiClient();
    try {
      final res = await api.get('/orders/${widget.order['id']}',
          queryParameters: {'company_id': widget.companyId});
      setState(() {
        _fullOrder = res.data;
        _workPriceController.text =
            (_fullOrder['work_price'] ?? 0).toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e')));
    }
  }

  Future<void> _updateItemPaid(int itemId, bool isPaid) async {
    final api = ApiClient();
    try {
      await api.patch('/orders/items/$itemId',
          queryParameters: {'company_id': widget.companyId},
          data: {'is_paid': isPaid});
      await _refreshOrder();
      widget.onOrderUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  // Диалог выбора камеры или галереи для прикрепления файла
  Future<void> _addAttachment() async {
    if (!_canEdit) return;

    final currentAttachments = _fullOrder['attachments'] ?? [];
    if (currentAttachments.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Нельзя прикрепить более 10 файлов к заказу')),
      );
      return;
    }

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите источник'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Камера'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Галерея'),
          ),
        ],
      ),
    );
    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;
    final compressed = await ImageCompression.compressImage(pickedFile);
    final api = ApiClient();
    try {
      await api.uploadPhoto('/orders/${widget.order['id']}/attachments',
          compressed, queryParameters: {'company_id': widget.companyId});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Файл прикреплён')));
      await _refreshOrder();
      widget.onOrderUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _showAttachment(String url) async {
    final api = ApiClient();
    try {
      final response = await api.getFile(url);
      final bytes = response.data as List<int>;
      final uint8list = Uint8List.fromList(bytes);
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Просмотр файла', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image.memory(uint8list),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки файла: $e')));
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    final api = ApiClient();
    try {
      await api.post('/orders/${widget.order['id']}/status',
          queryParameters: {'company_id': widget.companyId},
          data: {'status': newStatus});
      widget.onOrderUpdated();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final orderId = widget.order['id'];
    double calculatedMaterialsTotal = 0;
    double materialsPaid = 0;
    for (var item in _fullOrder['items'] ?? []) {
      double itemTotal = (item['total'] as num).toDouble();
      calculatedMaterialsTotal += itemTotal;
      if (item['is_paid'] == true) materialsPaid += itemTotal;
    }
    final isFullyPaid = (_fullOrder['total_amount'] - _fullOrder['paid_amount']) <= 0;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text('Заказ #${_fullOrder['id']}: ${_fullOrder['title']}',
                style: TextStyle(color: colorScheme.onSurface)),
          ),
          if (isFullyPaid)
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_fullOrder['description'] != null)
                Text('Описание: ${_fullOrder['description']}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Text('Статус: ${_statusName(_fullOrder['status'])}',
                  style: TextStyle(color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              if (_isEditable && _canEdit)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _workPriceController,
                        decoration: InputDecoration(
                            labelText: 'Цена работы',
                            labelStyle:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () async {
                        final api = ApiClient();
                        try {
                          await api.patch('/orders/$orderId',
                              queryParameters: {'company_id': widget.companyId},
                              data: {
                                'work_price':
                                    double.tryParse(_workPriceController.text) ?? 0,
                              });
                          await _refreshOrder();
                          widget.onOrderUpdated();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')));
                        }
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text('Цена работы: ${_fullOrder['work_price']} ₽',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              Text('Сумма материалов: ${calculatedMaterialsTotal.toStringAsFixed(2)} ₽',
                  style: TextStyle(color: colorScheme.onSurface)),
              Text('Оплачено материалов: ${materialsPaid.toStringAsFixed(2)} ₽',
                  style: TextStyle(color: Colors.green)),
              Text('Общая сумма заказа: ${_fullOrder['total_amount']} ₽',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              Text('Оплачено всего: ${_fullOrder['paid_amount']} ₽',
                  style: TextStyle(color: colorScheme.onSurface)),
              Text(
                  'Остаток к оплате: ${(_fullOrder['total_amount'] - _fullOrder['paid_amount']).toStringAsFixed(2)} ₽',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: (_fullOrder['total_amount'] - _fullOrder['paid_amount']) > 0
                          ? Colors.red
                          : Colors.green)),
              const Divider(),
              Row(
                children: [
                  Text('Материалы',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  if (_isEditable && _canEdit) const Spacer(),
                  if (_isEditable && _canEdit)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final newItem = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (context) => AddMaterialDialog(
                            products: _products,
                            companyId: widget.companyId,
                          ),
                        );
                        if (newItem != null) {
                          final api = ApiClient();
                          try {
                            await api.post('/orders/$orderId/items',
                                queryParameters: {'company_id': widget.companyId},
                                data: {
                                  'product_id': newItem['product_id'],
                                  'quantity': newItem['quantity'],
                                  'unit_price': newItem['unit_price'],
                                  'use_from_stock': newItem['use_from_stock'],
                                });
                            await _refreshOrder();
                            widget.onOrderUpdated();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ошибка: $e')));
                          }
                        }
                      },
                    ),
                ],
              ),
              if (_fullOrder['items'] != null && _fullOrder['items'].isNotEmpty)
                Column(
                  children: (_fullOrder['items'] as List).map((item) {
                    final itemId = item['id'];
                    final productName = item['product_name'];
                    final quantity = item['quantity'];
                    final total = item['total'];
                    final isPaid = item['is_paid'] ?? false;
                    return ListTile(
                      dense: true,
                      title: Text(productName,
                          style: TextStyle(color: colorScheme.onSurface)),
                      subtitle: Text(
                        '$quantity × ${item['unit_price']} ₽ = $total ₽',
                        softWrap: true,               // чтобы не разрывало по буквам
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEditable && _canEdit)
                            Row(
                              children: [
                                Checkbox(
                                  value: isPaid,
                                  onChanged: (value) {
                                    _updateItemPaid(itemId, value ?? false);
                                  },
                                ),
                                const Text('Оплачено'),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message:
                                      'Отметка оплаты материала не создаёт финансовую операцию.\nДля реального движения денег используйте кнопку "Добавить оплату".',
                                  child: const Icon(Icons.help_outline,
                                      size: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          if (_isEditable && _canEdit)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                final totalController = TextEditingController(
                                    text: total.toString());
                                double newTotalPrice = total;
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Изменить общую цену',
                                        style: TextStyle(
                                            color: colorScheme.onSurface)),
                                    content: TextField(
                                      controller: totalController,
                                      decoration: const InputDecoration(
                                          labelText: 'Новая общая цена (₽)'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => newTotalPrice =
                                          double.tryParse(v) ?? 0,
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text('Отмена',
                                              style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant))),
                                      ElevatedButton(
                                        onPressed: () async {
                                          if (newTotalPrice <= 0) return;
                                          final newUnitPrice =
                                              newTotalPrice / quantity;
                                          final api = ApiClient();
                                          try {
                                            await api.patch(
                                                '/orders/items/$itemId',
                                                queryParameters: {
                                                  'company_id':
                                                      widget.companyId
                                                },
                                                data: {
                                                  'unit_price': newUnitPrice,
                                                });
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            await _refreshOrder();
                                            widget.onOrderUpdated();
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Ошибка: $e')));
                                          }
                                        },
                                        child: const Text('Сохранить'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          if (_isEditable && _canEdit)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final api = ApiClient();
                                try {
                                  await api.delete('/orders/items/$itemId',
                                      queryParameters: {
                                        'company_id': widget.companyId
                                      });
                                  await _refreshOrder();
                                  widget.onOrderUpdated();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Ошибка: $e')));
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const Divider(),
              Row(
                children: [
                  Text('Оплаты',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  if (_canEdit) const Spacer(),
                  if (_canEdit)
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _showAddPaymentDialog(),
                    ),
                ],
              ),
              if (_fullOrder['payments'] != null &&
                  _fullOrder['payments'].isNotEmpty)
                Column(
                  children: (_fullOrder['payments'] as List).map((payment) {
                    return ListTile(
                      dense: true,
                      title: Text('${payment['amount']} ₽',
                          style: TextStyle(color: colorScheme.onSurface)),
                      subtitle: Text(DateFormat('dd.MM.yyyy')
                          .format(DateTime.parse(payment['payment_date']))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_canEdit)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final api = ApiClient();
                                try {
                                  await api.delete(
                                      '/orders/$orderId/payments/${payment['id']}',
                                      queryParameters: {
                                        'company_id': widget.companyId
                                      });
                                  await _refreshOrder();
                                  widget.onOrderUpdated();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Ошибка: $e')));
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              if (_canEdit)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton.icon(
                    onPressed: _addAttachment,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Сделать фото / прикрепить файл'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey),
                  ),
                ),
              if (_fullOrder['attachments'] != null &&
                  _fullOrder['attachments'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Прикреплённые файлы:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._fullOrder['attachments'].map<Widget>((att) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.image),
                        title: Text(att['file_url'].split('/').last),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              onPressed: () => _showAttachment(att['file_url']),
                              tooltip: 'Просмотреть',
                            ),
                            if (_canEdit)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Удалить файл?'),
                                      content: const Text(
                                          'Файл будет удалён безвозвратно.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Отмена')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Удалить',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                  final api = ApiClient();
                                  try {
                                    await api.delete(
                                        '/orders/${widget.order['id']}/attachments/${att['id']}',
                                        queryParameters: {
                                          'company_id': widget.companyId
                                        });
                                    await _refreshOrder();
                                    widget.onOrderUpdated();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Ошибка: $e')));
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              if (widget.order['status'] == 'accepted' && _canEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus('completed'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    child: const Text('Выполнить заказ'),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Закрыть',
                style: TextStyle(color: colorScheme.onSurfaceVariant))),
      ],
    );
  }

  void _showAddPaymentDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    double amount = 0;
    DateTime paymentDate = DateTime.now();
    String comment = '';
    int? selectedAccountId;
    String counterparty = '';

    final api = ApiClient();
    List<dynamic> accounts = [];
    try {
      final res = await api.get('/accounts', queryParameters: {'company_id': widget.companyId});
      accounts = res.data;
      if (accounts.isNotEmpty) selectedAccountId = accounts[0]['id'];
    } catch (e) {
      print('Error loading accounts: $e');
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStatePayment) {
          return AlertDialog(
            title: Text('Добавить оплату', style: TextStyle(color: colorScheme.onSurface)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Сумма*'),
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colorScheme.onSurface),
                    onChanged: (v) => amount = double.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text('Дата оплаты', style: TextStyle(color: colorScheme.onSurface)),
                    trailing: Text(DateFormat('dd.MM.yyyy').format(paymentDate),
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setStatePayment(() => paymentDate = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedAccountId,
                    items: accounts.map((acc) => DropdownMenuItem<int>(
                      value: acc['id'],
                      child: Text('${acc['name']} (${acc['balance']} ₽)'),
                    )).toList(),
                    onChanged: (v) => selectedAccountId = v,
                    decoration: const InputDecoration(labelText: 'Счёт получения оплаты*'),
                    style: TextStyle(color: colorScheme.onSurface),
                    dropdownColor: colorScheme.surface,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Комментарий (необязательно)'),
                    style: TextStyle(color: colorScheme.onSurface),
                    onChanged: (v) => comment = v,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Контрагент (необязательно)'),
                    style: TextStyle(color: colorScheme.onSurface),
                    onChanged: (v) => counterparty = v,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (amount <= 0 || selectedAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Введите сумму и выберите счёт')),
                    );
                    return;
                  }
                  final api = ApiClient();
                  try {
                    await api.post(
                      '/orders/${widget.order['id']}/payments',
                      queryParameters: {'company_id': widget.companyId},
                      data: {
                        'amount': amount,
                        'payment_date': paymentDate.toIso8601String(),
                        'comment': comment,
                        'account_id': selectedAccountId,
                        'counterparty': counterparty,
                      },
                    );
                    if (context.mounted) Navigator.pop(context);
                    await _refreshOrder();
                    widget.onOrderUpdated();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e')),
                    );
                  }
                },
                child: const Text('Добавить'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusName(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает';
      case 'accepted':
        return 'Принят';
      case 'completed':
        return 'Выполнен';
      case 'failed':
        return 'Провален';
      default:
        return status;
    }
  }
}