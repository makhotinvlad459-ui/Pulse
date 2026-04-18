import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/matrix_rain.dart';
import '../models/company.dart';
import '../widgets/company/account_card.dart';
import '../widgets/company/transactions_tab.dart';
import '../widgets/company/income_expense_tab.dart';
import '../widgets/company/reports_tab.dart';
import '../widgets/company/edit_company_dialog.dart';
import '../widgets/company/add_account_dialog.dart';
import '../widgets/company/manage_categories_dialog.dart';
import '../widgets/company/manage_employees_dialog.dart';
import '../widgets/company/chat_and_tasks_tab.dart';
import '../screens/archive_screen.dart';

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
  int? _archiveAccountId;
  int _pendingTasksCount = 0;
  int _unreadMessagesCount = 0;
  WebSocketChannel? _userChannel;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru_RU', null);
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _connectUserWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userChannel?.sink.close();
    if (_hasChanges) Navigator.pop(context, true);
    super.dispose();
  }

  Future<void> _connectUserWebSocket() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;
    final api = ApiClient();
    final token = await api.getToken();
    if (token == null) return;

    final baseUrl = ApiClient.baseUrl;
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    final wsUrl = '$wsBase/ws/user/${user.id}?token=$token';
    print('🟢 CompanyScreen connecting user WS: $wsUrl');

    _userChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _userChannel!.stream.listen((message) {
      print('🟢 CompanyScreen user WS message: $message');
      final data = jsonDecode(message);
      if (data['type'] == 'update_counters') {
        if (data['company_id'] == widget.company.id) {
          _refreshCounters();
        }
      }
    }, onError: (error) {
      print('🔴 CompanyScreen user WS error: $error');
    });
  }

  Future<void> _refreshCounters() async {
    final api = ApiClient();
    try {
      final countsRes = await api.get('/notifications/unread-counts');
      final counts = countsRes.data as Map<String, dynamic>;
      final companyIdStr = widget.company.id.toString();
      if (counts.containsKey(companyIdStr)) {
        final companyCounts = counts[companyIdStr] as Map<String, dynamic>;
        setState(() {
          _unreadMessagesCount = companyCounts['unread_messages'] ?? 0;
          _pendingTasksCount = companyCounts['pending_tasks'] ?? 0;
        });
      } else {
        setState(() {
          _unreadMessagesCount = 0;
          _pendingTasksCount = 0;
        });
      }
    } catch (e) {
      print('Error refreshing counters: $e');
    }
  }

  void _onPendingTasksChanged(int pending) {
    if (mounted) setState(() => _pendingTasksCount = pending);
  }

  void _onUnreadMessagesChanged(int unread) {
    if (mounted) setState(() => _unreadMessagesCount = unread);
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
        Map<String, dynamic>? archive;
        for (var acc in accountsList) {
          if (acc['name'] == 'Архив') {
            archive = acc;
            break;
          }
        }
        _archiveAccountId = archive?['id'];
        _accounts = accountsList.where((a) => a['name'] != 'Архив').toList();
        _transactions = transactionsRes.data;
        _categories = categoriesRes.data;
        _loading = false;
      });
      await _refreshCounters();
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

  void _openArchive() {
    if (_archiveAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Архивный счёт не найден.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          companyId: widget.company.id,
          archiveAccountId: _archiveAccountId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    final currentUserRole = widget.company.currentUserRole;
    final isManager = currentUserRole == 'manager';

    final bool showEditCompany = isFounder;
    final bool showAddAccount = isFounder || isManager;
    final bool showManageCategories = isFounder || isManager;
    final bool showManageEmployees = isFounder || isManager;
    final bool showArchive =
        (isFounder || isManager) && _archiveAccountId != null;
    final bool showDeleteCompany = isFounder;
    final bool showMenu = isFounder || isManager;

    final double rainHeight = 200;

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
                      if (showMenu)
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit' && showEditCompany)
                              await showDialog(
                                  context: context,
                                  builder: (_) => EditCompanyDialog(
                                      company: widget.company,
                                      onSuccess: _refresh));
                            if (value == 'add_account' && showAddAccount)
                              await showDialog(
                                  context: context,
                                  builder: (_) => AddAccountDialog(
                                      companyId: widget.company.id,
                                      onSuccess: _refresh));
                            if (value == 'manage_categories' &&
                                showManageCategories)
                              await showDialog(
                                  context: context,
                                  builder: (_) => ManageCategoriesDialog(
                                      companyId: widget.company.id,
                                      onSuccess: _refresh,
                                      categories: _categories));
                            if (value == 'manage_employees' &&
                                showManageEmployees)
                              await showDialog(
                                  context: context,
                                  builder: (_) => ManageEmployeesDialog(
                                      companyId: widget.company.id,
                                      onSuccess: _refresh));
                            if (value == 'archive' && showArchive)
                              _openArchive();
                            if (value == 'delete' && showDeleteCompany)
                              await _confirmDeleteCompany();
                          },
                          itemBuilder: (context) {
                            final items = <PopupMenuItem<String>>[];
                            if (showEditCompany) {
                              items.add(const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Редактировать компанию')));
                            }
                            if (showAddAccount) {
                              items.add(const PopupMenuItem(
                                  value: 'add_account',
                                  child: Text('Добавить счёт')));
                            }
                            if (showManageCategories) {
                              items.add(const PopupMenuItem(
                                  value: 'manage_categories',
                                  child: Text('Управление категориями')));
                            }
                            if (showManageEmployees) {
                              items.add(const PopupMenuItem(
                                  value: 'manage_employees',
                                  child: Text('Управление сотрудниками')));
                            }
                            if (showArchive) {
                              items.add(const PopupMenuItem(
                                  value: 'archive', child: Text('Архив')));
                            }
                            if (showDeleteCompany) {
                              items.add(const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Удалить компанию',
                                      style: TextStyle(color: Colors.red))));
                            }
                            return items;
                          },
                          icon: Icon(Icons.more_vert,
                              color: Colors.grey.shade800),
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
                                isFounder: isFounder,
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
                        tabs: [
                          const Tab(text: 'Операции'),
                          const Tab(text: 'Приход/Расход'),
                          const Tab(text: 'График'),
                          Tab(
                            text: (_unreadMessagesCount + _pendingTasksCount) >
                                    0
                                ? 'Чат/Задачи (${_unreadMessagesCount + _pendingTasksCount})'
                                : 'Чат/Задачи',
                          ),
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
                            ChatAndTasksTab(
                              companyId: widget.company.id,
                              isManager: isManager,
                              onPendingTasksChanged: _onPendingTasksChanged,
                              onUnreadMessagesChanged: _onUnreadMessagesChanged,
                            ),
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
