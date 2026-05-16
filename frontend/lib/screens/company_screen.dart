import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../models/user.dart';
import '../models/company.dart';
import '../widgets/company/account_card.dart';
import '../widgets/company/transactions_tab.dart';
import '../widgets/company/reports_tab.dart';
import '../widgets/company/edit_company_dialog.dart';
import '../widgets/company/add_account_dialog.dart';
import '../widgets/company/manage_categories_dialog.dart';
import '../widgets/company/manage_employees_dialog.dart';
import '../widgets/company/chat_and_tasks_tab.dart';
import '../screens/archive_screen.dart';
import '../widgets/company/stock_tab.dart';
import '../widgets/company/showcase_tab.dart';
import '../widgets/matrix_rain.dart';
import '../providers/theme_provider.dart';
import '../widgets/company/orders_tab.dart';
import '../widgets/company/counterparties_tab.dart';
import 'package:frontend/l10n/app_localizations.dart';

class RainTheme {
  final Color color;
  final double opacity;
  final double speed;
  const RainTheme({required this.color, required this.opacity, required this.speed});
}

RainTheme getRainTheme(AppTheme theme) {
  switch (theme) {
    case AppTheme.light:
      return const RainTheme(color: Colors.grey, opacity: 0.25, speed: 0.25);
    case AppTheme.dark:
      return const RainTheme(color: Colors.grey, opacity: 0.35, speed: 0.3);
    case AppTheme.blue:
      return const RainTheme(color: Colors.blueGrey, opacity: 0.3, speed: 0.28);
    case AppTheme.green:
      return const RainTheme(color: Colors.teal, opacity: 0.35, speed: 0.3);
  }
}

Color getGridColor(AppTheme theme, ColorScheme colorScheme) {
  switch (theme) {
    case AppTheme.light:
      return colorScheme.onSurfaceVariant.withOpacity(0.15);
    case AppTheme.dark:
      return Colors.grey.shade700.withOpacity(0.25);
    case AppTheme.blue:
      return Colors.blueGrey.shade200.withOpacity(0.25);
    case AppTheme.green:
      return Colors.teal.shade800.withOpacity(0.4);
  }
}

class CompanyScreen extends ConsumerStatefulWidget {
  final Company company;
  const CompanyScreen({super.key, required this.company});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen>
    with TickerProviderStateMixin {
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

  final GlobalKey<ReportsTabState> _reportsTabKey = GlobalKey<ReportsTabState>();

  Set<String> _myPermissions = {};
  bool _permissionsLoaded = false;

  // ------------------- Перетаскиваемые вкладки -------------------
  final List<String> _allTabKeys = [
    'operations',
    'showcase',
    'chat_tasks',
    'stock',
    'reports',
    'orders',
    'counterparties',
  ];

  List<String> _tabOrder = [];
  List<Tab> _tabs = [];
  List<Widget> _tabWidgets = [];

  String _getTabTitle(String key, AppLocalizations t) {
    switch (key) {
      case 'operations': return t.tabOperations;
      case 'showcase': return t.tabShowcase;
      case 'chat_tasks': return t.tabChatTasks;
      case 'stock': return t.tabStock;
      case 'reports': return t.tabReports;
      case 'orders': return t.tabOrders;
      case 'counterparties': return t.tabCounterparties;
      default: return key;
    }
  }

  Future<void> _loadTabOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('tab_order_${widget.company.id}');
    if (saved != null && saved.isNotEmpty) {
      final validKeys = saved.where((key) => _allTabKeys.contains(key)).toList();
      for (var key in _allTabKeys) {
        if (!validKeys.contains(key)) validKeys.add(key);
      }
      setState(() {
        _tabOrder = validKeys;
      });
    } else {
      setState(() {
        _tabOrder = List.from(_allTabKeys);
      });
    }
    _rebuildTabs();
  }

  Future<void> _saveTabOrder(List<String> newOrder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tab_order_${widget.company.id}', newOrder);
    setState(() {
      _tabOrder = newOrder;
    });
    _rebuildTabs();
  }

  Future<void> _openReorderTabsDialog() async {
    List<String> tempOrder = List.from(_tabOrder);
    final t = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(t.reorderTabs),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = tempOrder.removeAt(oldIndex);
                  tempOrder.insert(newIndex, item);
                  setStateDialog(() {});
                },
                children: tempOrder.map((key) => ListTile(
                  key: Key(key),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(_getTabTitle(key, t)),
                )).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  _saveTabOrder(tempOrder);
                  Navigator.pop(context);
                },
                child: Text(t.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _rebuildTabs() {
    final t = AppLocalizations.of(context)!;
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;
    Set<String> effectivePermissions;
    if (isFounder) {
      effectivePermissions = {
        'view_operations', 'view_showcase', 'view_chat', 'view_tasks',
        'view_products', 'view_reports', 'view_documents', 'view_requests',
        'view_orders', 'edit_orders', 'view_accounts', 'view_counterparties', 'edit_counterparties'
      };
    } else {
      effectivePermissions = _myPermissions;
    }

    final List<Tab> newTabs = [];
    final List<Widget> newWidgets = [];

    for (var key in _tabOrder) {
      switch (key) {
        case 'operations':
          if (effectivePermissions.contains('view_operations')) {
            newTabs.add(Tab(icon: const Icon(Icons.receipt), text: t.tabOperations));
            newWidgets.add(TransactionsTab(
              companyId: widget.company.id,
              onRefresh: _refresh,
              accounts: _accounts,
              categories: _categories,
              isFounder: isFounder,
              permissions: effectivePermissions,
            ));
          }
          break;
        case 'showcase':
          if (effectivePermissions.contains('view_showcase')) {
            newTabs.add(Tab(icon: const Icon(Icons.storefront), text: t.tabShowcase));
            newWidgets.add(ShowcaseTab(
              companyId: widget.company.id,
              onRefresh: _refresh,
              permissions: effectivePermissions,
            ));
          }
          break;
        case 'chat_tasks':
          if (effectivePermissions.contains('view_chat') || effectivePermissions.contains('view_tasks')) {
            newTabs.add(Tab(icon: const Icon(Icons.chat_bubble), text: t.tabChatTasks));
            newWidgets.add(ChatAndTasksTab(
              companyId: widget.company.id,
              isManager: widget.company.currentUserRole == 'manager',
              onPendingTasksChanged: _onPendingTasksChanged,
              onUnreadMessagesChanged: _onUnreadMessagesChanged,
            ));
          }
          break;
        case 'stock':
          if (effectivePermissions.contains('view_products')) {
            newTabs.add(Tab(icon: const Icon(Icons.inventory), text: t.tabStock));
            newWidgets.add(StockTab(
              companyId: widget.company.id,
              permissions: effectivePermissions,
            ));
          }
          break;
        case 'reports':
          if (effectivePermissions.contains('view_reports')) {
            newTabs.add(Tab(icon: const Icon(Icons.bar_chart), text: t.tabReports));
            newWidgets.add(ReportsTab(
              key: _reportsTabKey,
              companyId: widget.company.id,
              categories: _categories,
            ));
          }
          break;
        case 'orders':
          if (effectivePermissions.contains('view_orders')) {
            newTabs.add(Tab(icon: const Icon(Icons.assignment), text: t.tabOrders));
            newWidgets.add(OrdersTab(
              companyId: widget.company.id,
              permissions: effectivePermissions,
              isFounder: isFounder,
              onDataChanged: _updateAll,
            ));
          }
          break;
        case 'counterparties':
          if (effectivePermissions.contains('view_counterparties')) {
            newTabs.add(Tab(icon: const Icon(Icons.people), text: t.tabCounterparties));
            newWidgets.add(CounterpartiesTab(
              companyId: widget.company.id,
              permissions: effectivePermissions,
            ));
          }
          break;
      }
    }

    setState(() {
      _tabs = newTabs;
      _tabWidgets = newWidgets;
      if (_tabController.length != _tabs.length) {
        _tabController.dispose();
        _tabController = TabController(length: _tabs.length, vsync: this);
      }
    });
  }
  // -------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru_RU', null);
    _tabController = TabController(length: 0, vsync: this);
    _loadData();
    _connectUserWebSocket();
    _loadTabOrder();
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
      final countsRes = await api.get('/notifications/unread-counts/');
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
      await _loadMyPermissions();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context)!.error}: $e')));
    }
  }

  Future<void> _loadMyPermissions() async {
    final api = ApiClient();
    try {
      final res = await api.getMyPermissions(widget.company.id);
      final perms = res['permissions'] as List?;
      setState(() {
        _myPermissions = (perms ?? []).cast<String>().toSet();
        _permissionsLoaded = true;
      });
    } catch (e) {
      print('Error loading permissions: $e');
      setState(() {
        _myPermissions = {};
        _permissionsLoaded = true;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadData();
    _reportsTabKey.currentState?.refreshData();
    setState(() => _hasChanges = true);
  }

  void _openArchive() {
    if (_archiveAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.archiveNotFound)),
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

  Future<void> _updateAll() async {
    await _loadData();
    await _refreshCounters();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final authState = ref.watch(authProvider);
    final currentTheme = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;

    final isFounder = authState.user?.role == UserRole.founder;
    final currentUserRole = widget.company.currentUserRole;
    final isManager = currentUserRole == 'manager';

    final gridColor = getGridColor(currentTheme, colorScheme);
    final rain = getRainTheme(currentTheme);
    final double rainHeight = 260;

    if (!_permissionsLoaded) {
      return Scaffold(
        backgroundColor: colorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    Set<String> effectivePermissions = _myPermissions;
    if (isFounder) {
      effectivePermissions = {
        'view_operations', 'view_showcase', 'view_chat', 'view_tasks',
        'view_products', 'view_reports', 'view_documents', 'view_requests',
        'view_orders', 'edit_orders', 'view_accounts', 'view_counterparties', 'edit_counterparties'
      };
    }

    final showMenu = isFounder || effectivePermissions.contains('manage_employees') || effectivePermissions.contains('manage_permissions');
    final showReorderTabs = isFounder || effectivePermissions.contains('edit_company');
    final showEditCompany = isFounder || effectivePermissions.contains('edit_company');
    final showAddAccount = isFounder || effectivePermissions.contains('create_account');
    final showManageCategories = isFounder || effectivePermissions.contains('manage_categories');
    final showManageEmployees = isFounder || effectivePermissions.contains('manage_employees');
    final showArchive = (isFounder || effectivePermissions.contains('view_archive')) && _archiveAccountId != null;
    final showDeleteCompany = isFounder;

    // Перестраиваем вкладки при получении прав
    if (_tabOrder.isNotEmpty) {
      _rebuildTabs();
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        children: [
          Container(
            color: colorScheme.background,
            child: CustomPaint(
              painter: _LightGridPainter(color: gridColor),
              size: Size.infinite,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: rainHeight,
            child: MatrixRain(
              color: rain.color,
              opacity: rain.opacity,
              speedFactor: rain.speed,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
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
                            if (value == 'manage_employees' && showManageEmployees)
                              await showDialog(
                                  context: context,
                                  builder: (_) => ManageEmployeesDialog(
                                      companyId: widget.company.id,
                                      onSuccess: _refresh));
                            if (value == 'archive' && showArchive)
                              _openArchive();
                            if (value == 'delete' && showDeleteCompany)
                              await _confirmDeleteCompany();
                            if (value == 'reorder_tabs' && showReorderTabs)
                              await _openReorderTabsDialog();
                          },
                          itemBuilder: (context) {
                            final items = <PopupMenuItem<String>>[];
                            if (showEditCompany) {
                              items.add(PopupMenuItem(
                                  value: 'edit',
                                  child: Text(t.editCompany)));
                            }
                            if (showAddAccount) {
                              items.add(PopupMenuItem(
                                  value: 'add_account',
                                  child: Text(t.addAccount)));
                            }
                            if (showManageCategories) {
                              items.add(PopupMenuItem(
                                  value: 'manage_categories',
                                  child: Text(t.manageCategories)));
                            }
                            if (showManageEmployees) {
                              items.add(PopupMenuItem(
                                  value: 'manage_employees',
                                  child: Text(t.manageEmployees)));
                            }
                            if (showArchive) {
                              items.add(PopupMenuItem(
                                  value: 'archive', child: Text(t.archive)));
                            }
                            if (showReorderTabs) {
                              items.add(PopupMenuItem(
                                  value: 'reorder_tabs',
                                  child: Text(t.reorderTabs)));
                            }
                            if (showDeleteCompany) {
                              items.add(PopupMenuItem(
                                  value: 'delete',
                                  child: Text(t.deleteCompany,
                                      style: TextStyle(color: colorScheme.error))));
                            }
                            return items;
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.menu, color: colorScheme.onSurface),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    widget.company.name,
                    style: GoogleFonts.orbitron(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_unreadMessagesCount > 0 || _pendingTasksCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_unreadMessagesCount > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${t.messages}: $_unreadMessagesCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        if (_pendingTasksCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${t.tasks}: $_pendingTasksCount',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (effectivePermissions.contains('view_accounts'))
                  SizedBox(
                    height: 100,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: _accounts
                            .map((acc) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: AccountCard(
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
                                            SnackBar(content: Text('${t.error}: $e')));
                                      }
                                    },
                                    isFounder: isFounder,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (_tabs.isNotEmpty)
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicatorColor: colorScheme.primary,
                          labelColor: colorScheme.primary,
                          unselectedLabelColor: colorScheme.onSurfaceVariant,
                          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          unselectedLabelStyle: const TextStyle(fontSize: 14),
                          tabs: _tabs,
                        ),
                      Expanded(
                        child: _tabWidgets.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : TabBarView(
                                controller: _tabController,
                                children: _tabWidgets,
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
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteCompanyConfirmTitle),
        content: Text(t.deleteCompanyConfirmContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final api = ApiClient();
      try {
        await api.delete('/companies/${widget.company.id}');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(t.companyDeleted)));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
      }
    }
  }
}

class _LightGridPainter extends CustomPainter {
  final Color color;
  const _LightGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
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