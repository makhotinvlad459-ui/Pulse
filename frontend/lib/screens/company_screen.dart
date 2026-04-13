import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/graphite_background.dart';
import '../models/company.dart';
import '../widgets/company/account_card.dart';
import '../widgets/company/transactions_tab.dart';
import '../widgets/company/income_expense_tab.dart';
import '../widgets/company/reports_tab.dart';
import '../widgets/company/add_transaction_dialog.dart';
import '../widgets/company/edit_company_dialog.dart';
import '../widgets/company/edit_transaction_dialog.dart';
import '../widgets/company/add_account_dialog.dart';
import '../widgets/company/manage_categories_dialog.dart';
import '../widgets/company/manage_employees_dialog.dart'; // новый импорт

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
    // Определяем, может ли пользователь управлять сотрудниками
    final canManageEmployees =
        isFounder || widget.company.currentUserRole == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit')
                await showDialog(
                    context: context,
                    builder: (_) => EditCompanyDialog(
                        company: widget.company, onSuccess: _refresh));
              if (value == 'add_account')
                await showDialog(
                    context: context,
                    builder: (_) => AddAccountDialog(
                        companyId: widget.company.id, onSuccess: _refresh));
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
                        companyId: widget.company.id, onSuccess: _refresh));
              if (value == 'delete') await _confirmDeleteCompany();
            },
            itemBuilder: (context) {
              final items = [
                const PopupMenuItem(
                    value: 'edit', child: Text('Редактировать компанию')),
                const PopupMenuItem(
                    value: 'add_account', child: Text('Добавить счёт')),
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
          ),
        ],
      ),
      body: GraphiteBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(
                    height: 120,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(16),
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text('Ошибка: $e')));
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
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    if (_tabController.index == 0) {
      return FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => AddTransactionDialog(
            companyId: widget.company.id,
            onSuccess: _refresh,
            accounts: _accounts,
            categories: _categories,
          ),
        ),
        backgroundColor: Colors.blueGrey.shade300,
        child: const Icon(Icons.add),
      );
    }
    return const SizedBox.shrink();
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
