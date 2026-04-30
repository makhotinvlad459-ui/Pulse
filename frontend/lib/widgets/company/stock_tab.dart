import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class StockTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;

  const StockTab({
    super.key,
    required this.companyId,
    required this.permissions,
  });

  @override
  ConsumerState<StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<StockTab> {
  List<dynamic> _products = [];
  bool _loading = true;
  String _activeType = 'product'; // 'product' or 'material'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _materialUnits = ['шт', 'м', 'мм', 'см', 'дюймы', 'кг', 'г', 'л', 'мл', 'упаковка'];

  // Проверки прав
  bool get _canViewProducts {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    return isFounder || widget.permissions.contains('view_products');
  }

  bool get _canViewMaterials {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    return isFounder || widget.permissions.contains('view_materials');
  }

  bool get _canCreateProduct {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    return isFounder || widget.permissions.contains('create_product');
  }

  bool get _canEditProduct {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    return isFounder || widget.permissions.contains('edit_product');
  }

  bool get _canCreateMaterial {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    return isFounder || widget.permissions.contains('create_material');
  }

  bool get _canEditMaterial {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    return isFounder || widget.permissions.contains('edit_material');
  }

  bool get _canCreate => _activeType == 'product' ? _canCreateProduct : _canCreateMaterial;
  bool get _canEdit => _activeType == 'product' ? _canEditProduct : _canEditMaterial;

  // Доступные для просмотра типы
  List<String> get _availableTypes {
    final types = <String>[];
    if (_canViewProducts) types.add('product');
    if (_canViewMaterials) types.add('material');
    return types;
  }

  @override
  void initState() {
    super.initState();
    // Если пользователь может видеть только один тип, устанавливаем его
    final available = _availableTypes;
    if (available.isNotEmpty && !available.contains(_activeType)) {
      _activeType = available.first;
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final res = await api.get('/products/', queryParameters: {
        'company_id': widget.companyId,
        'type': _activeType,
      });
      setState(() {
        _products = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  List<dynamic> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) =>
        p['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (p['label']?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  Future<void> _addOrEditProduct([Map<String, dynamic>? existing]) async {
    if (!_canCreate && existing == null) return;
    final isEdit = existing != null;
    if (isEdit && !_canEdit) return;

    final nameController = TextEditingController(text: existing?['name'] ?? '');
    String? unit = existing?['unit'];
    final labelController = TextEditingController(text: existing?['label'] ?? '');
    final sizeController = TextEditingController(text: existing?['size'] ?? '');
    final barcodeController = TextEditingController(text: existing?['barcode'] ?? '');
    final supplierController = TextEditingController(text: existing?['supplier'] ?? '');

    final colorScheme = Theme.of(context).colorScheme;
    final units = _activeType == 'product'
        ? ['шт', 'кг', 'г', 'л', 'мл', 'упаковка']
        : _materialUnits;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Редактировать' : 'Новый ${_activeType == 'product' ? 'товар' : 'материал'}',
            style: TextStyle(color: colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Название*', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: unit,
                decoration: InputDecoration(labelText: 'Единица измерения*', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                dropdownColor: colorScheme.surface,
                style: TextStyle(color: colorScheme.onSurface),
                items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (v) => unit = v,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: labelController,
                decoration: InputDecoration(labelText: 'Артикул / метка (необязательно)', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sizeController,
                decoration: InputDecoration(labelText: 'Размер (необязательно)', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: barcodeController,
                decoration: InputDecoration(labelText: 'Штрихкод / маркировка (необязательно)', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: supplierController,
                decoration: InputDecoration(labelText: 'Поставщик (необязательно)', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || unit == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните название и единицу измерения')));
                return;
              }
              final api = ApiClient();
              try {
                if (isEdit) {
                  await api.patch('/products/${existing!['id']}', queryParameters: {'company_id': widget.companyId}, data: {
                    'name': nameController.text,
                    'unit': unit,
                    'label': labelController.text,
                    'size': sizeController.text,
                    'barcode': barcodeController.text,
                    'supplier': supplierController.text,
                  });
                } else {
                  await api.post('/products/', queryParameters: {'company_id': widget.companyId}, data: {
                    'name': nameController.text,
                    'unit': unit,
                    'type': _activeType,
                    'label': labelController.text,
                    'size': sizeController.text,
                    'barcode': barcodeController.text,
                    'supplier': supplierController.text,
                  });
                }
                Navigator.pop(context);
                _loadProducts();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: Text(isEdit ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableTypes = _availableTypes;

    if (availableTypes.isEmpty) {
      return const Center(child: Text('Нет прав для просмотра склада'));
    }

    // Если доступен только один тип, показываем список без переключателя
    final showTypeSelector = availableTypes.length > 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (showTypeSelector)
                SegmentedButton<String>(
                  style: ButtonStyle(
                    foregroundColor: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.selected)) return colorScheme.onPrimary;
                      return colorScheme.onSurface;
                    }),
                    backgroundColor: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.selected)) return colorScheme.primary;
                      return colorScheme.surfaceContainerHighest;
                    }),
                  ),
                  segments: const [
                    ButtonSegment(value: 'product', label: Text('Товары'), icon: Icon(Icons.inventory)),
                    ButtonSegment(value: 'material', label: Text('Материалы'), icon: Icon(Icons.handyman)),
                  ],
                  selected: {_activeType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _activeType = newSelection.first;
                      _loadProducts();
                    });
                  },
                ),
              const Spacer(),
              if (_canCreate)
                FloatingActionButton.small(
                  onPressed: () => _addOrEditProduct(),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск по названию или артикулу',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                  ? Center(child: Text('Нет данных', style: TextStyle(color: colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = _filteredProducts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: colorScheme.surface,
                          child: InkWell(
                            onTap: _canEdit ? () => _addOrEditProduct(p) : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: colorScheme.primaryContainer,
                                        child: Text(p['name'][0].toUpperCase(),
                                            style: TextStyle(color: colorScheme.onPrimaryContainer)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p['name'],
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
                                            if (p['label'] != null && p['label'].isNotEmpty)
                                              Text('Артикул: ${p['label']}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                          ],
                                        ),
                                      ),
                                      Text('${p['current_quantity']} ${p['unit']}',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (p['size'] != null && p['size'].isNotEmpty)
                                        Chip(label: Text('Размер: ${p['size']}'), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      if (p['barcode'] != null && p['barcode'].isNotEmpty)
                                        Chip(label: Text('Штрихкод: ${p['barcode']}'), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                      if (p['supplier'] != null && p['supplier'].isNotEmpty)
                                        Chip(label: Text('Поставщик: ${p['supplier']}'), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}