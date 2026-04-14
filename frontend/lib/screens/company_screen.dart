import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/matrix_rain.dart';
import '../models/company.dart';
import '../widgets/company/account_card.dart';
import '../widgets/company/transactions_tab.dart';
import '../widgets/company/income_expense_tab.dart';
import '../widgets/company/reports_tab.dart';
import '../widgets/company/add_transaction_dialog.dart';
import '../widgets/company/edit_company_dialog.dart';
import '../widgets/company/add_account_dialog.dart';
import '../widgets/company/manage_categories_dialog.dart';
import '../widgets/company/manage_employees_dialog.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  final Company company;
  const CompanyScreen({super.key, required this.company});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _accounts = [];
  List<dynamic> _transactions = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru_RU', null);
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = ApiClient();
    try {
      final accountsRes = await api
          .get('/accounts', queryParameters: {'company_id': widget.company.id});
      final transactionsRes = await api.get('/transactions',
          queryParameters: {'company_id': widget.company.id});
      final categoriesRes = await api.get('/categories',
          queryParameters: {'company_id': widget.company.id});
      setState(() {
        final accountsList =
            (accountsRes.data as List).cast<Map<String, dynamic>>();
        accountsList.sort((a, b) {
          int orderA = a['type'] == 'cash' ? 0 : (a['type'] == 'bank' ? 1 : 2);
          int orderB = b['type'] == 'cash' ? 0 : (b['type'] == 'bank' ? 1 : 2);
          if (orderA != orderB) return orderA.compareTo(orderB);
          return a['id'].compareTo(b['id']);
        });
        _accounts = accountsList;
        _transactions = transactionsRes.data;
        _categories = categoriesRes.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
    }
  }

  Future<void> _refresh() async {
    await _loadData();
    setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_hasChanges) Navigator.pop(context, true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    final canManageEmployees =
        isFounder || widget.company.currentUserRole == 'manager';

    final double rainHeight = 200; // подберите под свою шапку

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFF2F2F2),
            child: CustomPaint(
              painter: _LightGridPainter(),
              size: Size.infinite,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: rainHeight,
            child: MatrixRain(color: Colors.black, opacity: 0.3),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon:
                            Icon(Icons.arrow_back, color: Colors.grey.shade800),
                        onPressed: () => Navigator.pop(context, _hasChanges),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit')
                            await showDialog(
                                context: context,
                                builder: (_) => EditCompanyDialog(
                                    company: widget.company,
                                    onSuccess: _refresh));
                          if (value == 'add_account')
                            await showDialog(
                                context: context,
                                builder: (_) => AddAccountDialog(
                                    companyId: widget.company.id,
                                    onSuccess: _refresh));
                          if (value == 'manage_categories')
                            await showDialog(
                                context: context,
                                builder: (_) => ManageCategoriesDialog(
                                    companyId: widget.company.id,
                                    onSuccess: _refresh,
                                    categories: _categories));
                          if (value == 'manage_employees')
                            await showDialog(
                                context: context,
                                builder: (_) => ManageEmployeesDialog(
                                    companyId: widget.company.id,
                                    onSuccess: _refresh));
                          if (value == 'delete') await _confirmDeleteCompany();
                        },
                        itemBuilder: (context) {
                          final items = [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать компанию')),
                            const PopupMenuItem(
                                value: 'add_account',
                                child: Text('Добавить счёт')),
                            const PopupMenuItem(
                                value: 'manage_categories',
                                child: Text('Управление категориями')),
                          ];
                          if (canManageEmployees) {
                            items.add(const PopupMenuItem(
                                value: 'manage_employees',
                                child: Text('Управление сотрудниками')));
                          }
                          items.add(const PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить компанию',
                                  style: TextStyle(color: Colors.red))));
                          return items;
                        },
                        icon:
                            Icon(Icons.more_vert, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    widget.company.name,
                    style: GoogleFonts.orbitron(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _accounts
                          .map((acc) => AccountCard(
                                account: acc,
                                onDelete: () async {
                                  final api = ApiClient();
                                  try {
                                    await api.delete('/accounts/${acc['id']}',
                                        queryParameters: {
                                          'company_id': widget.company.id
                                        });
                                    await _refresh();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Ошибка: $e')));
                                  }
                                },
                              ))
                          .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Операции'),
                          Tab(text: 'Приход/Расход'),
                          Tab(text: 'График'),
                        ],
                        labelColor: Colors.grey.shade800,
                        unselectedLabelColor: Colors.grey.shade500,
                        indicatorColor: Colors.grey.shade800,
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            TransactionsTab(
                              companyId: widget.company.id,
                              onRefresh: _refresh,
                              accounts: _accounts,
                              categories: _categories,
                              isFounder: isFounder,
                            ),
                            IncomeExpenseTab(
                                companyId: widget.company.id,
                                categories: _categories),
                            ReportsTab(companyId: widget.company.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB удалён – теперь кнопка добавления находится внутри TransactionsTab
    );
  }

  Future<void> _confirmDeleteCompany() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить компанию?'),
        content: const Text('Все данные компании будут безвозвратно удалены.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final api = ApiClient();
      try {
        await api.delete('/companies/${widget.company.id}');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Компания удалена')));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}

class _LightGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300.withOpacity(0.5)
      ..strokeWidth = 0.5;
    const double spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
