import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../models/user.dart';
import 'package:dio/dio.dart'; 
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
import '../services/websocket_service.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../widgets/company/journal/journal_tab.dart';
import '../services/error/error_handler.dart';
import '../widgets/company/production/production_tab.dart';

class RainTheme {
  final Color color;
  final double opacity;
  final double speed;
  const RainTheme({
    required this.color,
    required this.opacity,
    required this.speed,
  });
}

RainTheme getRainTheme(AppTheme theme) {
  switch (theme) {
    case AppTheme.light:
      return const RainTheme(color: Colors.grey, opacity: 0.25, speed: 0.25);
    case AppTheme.dark:
      return const RainTheme(color: Colors.grey, opacity: 0.35, speed: 0.3);
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
  late Company _company;
  List<dynamic> _accounts = [];
  List<dynamic> _transactions = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  bool _hasChanges = false;
  int? _archiveAccountId;
  int _pendingTasksCount = 0;
  int _unreadMessagesCount = 0;

  final GlobalKey<ReportsTabState> _reportsTabKey =
      GlobalKey<ReportsTabState>();

  Set<String> _myPermissions = {};
  bool _permissionsLoaded = false;
  
  // Флаг для отмены запросов при dispose
  bool _isDisposed = false;

  // ------------------- Перетаскиваемые вкладки -------------------
  final List<String> _allTabKeys = [
    'operations',
    'journal',
    'showcase',
    'chat_tasks',
    'stock',
    'production',
    'reports',
    'orders',
    'counterparties',
  ];

  List<String> _tabOrder = [];
  List<Tab> _tabs = [];
  List<Widget> _tabWidgets = [];

  String _getTabTitle(String key, AppLocalizations t) {
    switch (key) {
      case 'operations':
        return t.tabOperations;
      case 'showcase':
        return t.tabShowcase;
      case 'chat_tasks':
        return t.tabChatTasks;
      case 'stock':
        return t.tabStock;
      case 'journal':
        return t.tabJournal;
      case 'production':
        return t.tabProduction;
      case 'reports':
        return t.tabReports;
      case 'orders':
        return t.tabOrders;
      case 'counterparties':
        return t.tabCounterparties;
      default:
        return key;
    }
  }

  // ==================== ЕДИНЫЙ МЕТОД ДЛЯ ПРАВ ДОСТУПА ====================
  Set<String> _getEffectivePermissions() {
    final authState = ref.read(authProvider);
    final isFounder = authState.user?.role == UserRole.founder;

    if (isFounder) {
      return {
        'view_operations',
        'view_showcase',
        'view_chat',
        'view_tasks',
        'view_products',
        'view_reports',
        'view_documents',
        'view_requests',
        'view_orders',
        'edit_orders',
        'view_accounts',
        'view_counterparties',
        'edit_counterparties',
        'view_journal',
        'create_journal',
        'edit_journal',
        'delete_journal',
        'complete_journal',
        'view_production',
        'create_production',
        'edit_production',
        'delete_production',
        'manage_manufactured_products',
      };
    }
    return _myPermissions;
  }

  Future<void> _loadTabOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isDisposed) return;
      
      final saved = prefs.getStringList('tab_order_${_company.id}');
      if (saved != null && saved.isNotEmpty) {
        final validKeys = saved.where((key) => _allTabKeys.contains(key)).toList();
        for (var key in _allTabKeys) {
          if (!validKeys.contains(key)) validKeys.add(key);
        }
        _tabOrder = validKeys;
      } else {
        _tabOrder = List.from(_allTabKeys);
      }
      
      if (!_isDisposed && mounted) {
        _rebuildTabs();
      }
    } catch (e) {
      // Игнорируем ошибки загрузки порядка табов
      debugPrint('Error loading tab order: $e');
      if (!_isDisposed && mounted) {
        _tabOrder = List.from(_allTabKeys);
        _rebuildTabs();
      }
    }
  }

  Future<void> _saveTabOrder(List<String> newOrder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tab_order_${_company.id}', newOrder);
      if (_isDisposed) return;
      _tabOrder = newOrder;
      if (mounted) {
        _rebuildTabs();
      }
    } catch (e) {
      debugPrint('Error saving tab order: $e');
    }
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
                children: tempOrder
                    .map((key) => ListTile(
                          key: Key(key),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(_getTabTitle(key, t)),
                        ))
                    .toList(),
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
    if (_isDisposed) return;
    if (!mounted) return;
    
    final t = AppLocalizations.of(context)!;
    final effectivePermissions = _getEffectivePermissions();

    final List<Tab> newTabs = [];
    final List<Widget> newWidgets = [];

    for (var key in _tabOrder) {
      switch (key) {
        case 'operations':
          if (effectivePermissions.contains('view_operations')) {
            newTabs.add(
                Tab(icon: const Icon(Icons.receipt), text: t.tabOperations));
            newWidgets.add(TransactionsTab(
              companyId: _company.id,
              onRefresh: _refresh,
              accounts: _accounts,
              categories: _categories,
              isFounder: ref.read(authProvider).user?.role == UserRole.founder,
              permissions: effectivePermissions,
            ));
          }
          break;
        case 'showcase':
          if (effectivePermissions.contains('view_showcase')) {
            newTabs.add(
                Tab(icon: const Icon(Icons.storefront), text: t.tabShowcase));
            newWidgets.add(ShowcaseTab(
              companyId: _company.id,
              onRefresh: _refresh,
              permissions: effectivePermissions,
            ));
          }
          break;
        case 'production':
          if (effectivePermissions.contains('view_production')) {
            newTabs.add(Tab(icon: const Icon(Icons.factory), text: t.tabProduction));
            newWidgets.add(ProductionTab(
              companyId: _company.id,
              permissions: effectivePermissions,
              onRefresh: _refresh,
            ));
          }
          break;
        case 'journal':
          if (effectivePermissions.contains('view_journal')) {
            newTabs.add(Tab(icon: const Icon(Icons.calendar_month), text: t.tabJournal));
            newWidgets.add(JournalTab(
              companyId: _company.id,
              permissions: effectivePermissions,
              onRefresh: _refresh,
            ));
          }
          break;
        case 'chat_tasks':
          if (effectivePermissions.contains('view_chat') ||
              effectivePermissions.contains('view_tasks')) {
            newTabs.add(
                Tab(icon: const Icon(Icons.chat_bubble), text: t.tabChatTasks));
            newWidgets.add(ChatAndTasksTab(
              companyId: _company.id,
              isManager: _company.currentUserRole == 'manager',
              onPendingTasksChanged: _onPendingTasksChanged,
              onUnreadMessagesChanged: _onUnreadMessagesChanged,
            ));
          }
          break;
        case 'stock':
          if (effectivePermissions.contains('view_products')) {
            newTabs
                .add(Tab(icon: const Icon(Icons.inventory), text: t.tabStock));
            newWidgets.add(StockTab(
              companyId: _company.id,
              permissions: effectivePermissions,
            ));
          }
          break;
        case 'reports':
          if (effectivePermissions.contains('view_reports')) {
            newTabs.add(
                Tab(icon: const Icon(Icons.bar_chart), text: t.tabReports));
            newWidgets.add(ReportsTab(
              key: _reportsTabKey,
              companyId: _company.id,
              categories: _categories,
            ));
          }
          break;
        case 'orders':
          if (effectivePermissions.contains('view_orders')) {
            newTabs.add(
                Tab(icon: const Icon(Icons.assignment), text: t.tabOrders));
            newWidgets.add(OrdersTab(
              companyId: _company.id,
              permissions: effectivePermissions,
              isFounder: ref.read(authProvider).user?.role == UserRole.founder,
              onDataChanged: _updateAll,
            ));
          }
          break;
        case 'counterparties':
          if (effectivePermissions.contains('view_counterparties')) {
            newTabs.add(
                Tab(icon: const Icon(Icons.people), text: t.tabCounterparties));
            newWidgets.add(CounterpartiesTab(
              companyId: _company.id,
              permissions: effectivePermissions,
            ));
          }
          break;
      }
    }

    // Обновляем состояние только если есть изменения
    if (_tabs.length != newTabs.length || _tabs != newTabs) {
      // Удаляем старый контроллер перед созданием нового
      if (_tabController.length != newTabs.length) {
        _tabController.dispose();
        _tabController = TabController(length: newTabs.length, vsync: this);
      }

      setState(() {
        _tabs = newTabs;
        _tabWidgets = newWidgets;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _company = widget.company;
    _isDisposed = false;
    initializeDateFormatting('ru_RU', null);
    _tabController = TabController(length: 0, vsync: this);
    _loadData();
    _initWebSocket();
    _loadTabOrder();
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Закрываем WebSocket соединения с try-catch
    try {
      WebSocketService().disconnectChat();
    } catch (e) {
      debugPrint('Error disconnecting chat: $e');
    }
    try {
      WebSocketService().disconnectTasks();
    } catch (e) {
      debugPrint('Error disconnecting tasks: $e');
    }
    
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initWebSocket() async {
    if (_isDisposed) return;
    
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;
    final api = ApiClient();
    final token = await api.getToken();
    if (token == null) return;

    // Каждое подключение в отдельном try-catch
    try {
      WebSocketService().connectUser(user.id, token);
    } catch (e) {
      debugPrint('WS User error: $e');
    }

    try {
      WebSocketService().connectChat(_company.id, token);
    } catch (e) {
      debugPrint('WS Chat error: $e');
    }

    try {
      WebSocketService().connectTasks(_company.id, token);
    } catch (e) {
      debugPrint('WS Tasks error: $e');
    }
  }

  Future<void> _refreshCounters() async {
    if (_isDisposed) return;
    
    final api = ApiClient();
    try {
      final countsRes = await api.get('/notifications/unread-counts/');
      if (_isDisposed) return;
      
      final counts = countsRes.data as Map<String, dynamic>?;
      if (counts == null) return;

      final companyIdStr = _company.id.toString();
      final companyCounts = counts[companyIdStr] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _unreadMessagesCount = companyCounts?['unread_messages'] ?? 0;
          _pendingTasksCount = companyCounts?['pending_tasks'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing counters: $e');
    }
  }

  void _onPendingTasksChanged(int pending) {
    if (!_isDisposed && mounted) {
      setState(() => _pendingTasksCount = pending);
    }
  }

  void _onUnreadMessagesChanged(int unread) {
    if (!_isDisposed && mounted) {
      setState(() => _unreadMessagesCount = unread);
    }
  }

  Future<void> _loadData() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
    setState(() => _loading = true);
    
    final api = ApiClient();
    
    try {
      // ✅ ПАРАЛЛЕЛЬНАЯ ЗАГРУЗКА ВСЕХ ДАННЫХ
      final results = await Future.wait([
        api.getCompany(_company.id),
        api.get('/accounts', queryParameters: {'company_id': _company.id}),
        api.get('/transactions', queryParameters: {'company_id': _company.id}),
        api.get('/categories', queryParameters: {'company_id': _company.id}),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );
      
      if (_isDisposed) return;
      if (!mounted) return;
      
      final updatedCompany = results[0] as Company;
      final accountsRes = results[1] as Response;
      final transactionsRes = results[2] as Response;
      final categoriesRes = results[3] as Response;
      
      setState(() {
        _company = updatedCompany;

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

      // Загружаем счетчики и права параллельно
      await Future.wait([
        _refreshCounters(),
        _loadMyPermissions(),
      ]);
      
      if (_isDisposed) return;
      if (!mounted) return;

      // Перестраиваем вкладки после загрузки данных
      _rebuildTabs();
      
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() => _loading = false);
      
      await ErrorHandler.showErrorDialog(
        context,
        e,
        onRetry: _loadData,
      );
    }
  }

  Future<void> _loadMyPermissions() async {
    if (_isDisposed) return;
    
    final api = ApiClient();
    try {
      final res = await api.getMyPermissions(_company.id);
      if (_isDisposed) return;
      if (!mounted) return;

      final perms = res['permissions'] as List?;
      setState(() {
        _myPermissions = (perms ?? []).cast<String>().toSet();
        _permissionsLoaded = true;
      });

      // Перестраиваем вкладки после загрузки прав
      if (!_isDisposed && mounted) {
        _rebuildTabs();
      }
    } catch (e) {
      debugPrint('Error loading permissions: $e');
      if (_isDisposed) return;
      if (!mounted) return;
      
      setState(() {
        _myPermissions = {};
        _permissionsLoaded = true;
      });
    }
  }

  Future<void> _refresh() async {
    if (_isDisposed) return;
    await _loadData();
    if (_isDisposed) return;
    if (mounted) {
      _reportsTabKey.currentState?.refreshData();
      setState(() => _hasChanges = true);
    }
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
          companyId: _company.id,
          archiveAccountId: _archiveAccountId!,
        ),
      ),
    );
  }

  Future<void> _updateAll() async {
    if (_isDisposed) return;
    await _loadData();
    if (_isDisposed) return;
    await _refreshCounters();
    if (_isDisposed) return;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmDeleteCompany() async {
    if (_isDisposed) return;
    if (!mounted) return;
    
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
        await api.delete('/companies/${_company.id}');
        if (_isDisposed) return;
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(t.companyDeleted)));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (_isDisposed) return;
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final authState = ref.watch(authProvider);
    final currentTheme = ref.watch(themeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;

    final isFounder = authState.user?.role == UserRole.founder;
    final effectivePermissions = _getEffectivePermissions();

    final gridColor = getGridColor(currentTheme, colorScheme);
    final rain = getRainTheme(currentTheme);
    const double rainHeight = 260;

    ref.listen(StreamProvider((ref) => WebSocketService().userStream), (previous, next) {
      next.whenData((data) {
        if (data['type'] == 'update_counters' && data['company_id'] == _company.id) {
          _refreshCounters();
        }
      });
    });

    if (!_permissionsLoaded) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Определяем видимость кнопок меню
    final showMenu = isFounder ||
        effectivePermissions.contains('manage_employees') ||
        effectivePermissions.contains('manage_permissions');
    final showReorderTabs =
        isFounder || effectivePermissions.contains('edit_company');
    final showEditCompany =
        isFounder || effectivePermissions.contains('edit_company');
    final showAddAccount =
        isFounder || effectivePermissions.contains('create_account');
    final showManageCategories =
        isFounder || effectivePermissions.contains('manage_categories');
    final showManageEmployees =
        isFounder || effectivePermissions.contains('manage_employees');
    final showArchive =
        (isFounder || effectivePermissions.contains('view_archive')) &&
            _archiveAccountId != null;
    final showDeleteCompany = isFounder;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (mounted) {
          Navigator.pop(context, _hasChanges);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          children: [
            Container(
              color: colorScheme.surface,
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
                          onPressed: () {
                            if (mounted) {
                              Navigator.pop(context, _hasChanges);
                            }
                          },
                        ),
                        const Spacer(),
                        if (showMenu)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (_isDisposed) return;
                              if (!mounted) return;
                              
                              if (value == 'edit' && showEditCompany) {
                                await showDialog(
                                  context: context,
                                  builder: (_) => EditCompanyDialog(
                                    company: _company,
                                    onSuccess: () {
                                      if (!_isDisposed && mounted) {
                                        _loadData();
                                      }
                                    },
                                  ),
                                );
                              }
                              if (value == 'add_account' && showAddAccount) {
                                await showDialog(
                                  context: context,
                                  builder: (_) => AddAccountDialog(
                                    companyId: _company.id,
                                    onSuccess: _refresh,
                                  ),
                                );
                              }
                              if (value == 'manage_categories' && showManageCategories) {
                                await showDialog(
                                  context: context,
                                  builder: (_) => ManageCategoriesDialog(
                                    companyId: _company.id,
                                    onSuccess: _refresh,
                                    categories: _categories,
                                  ),
                                );
                              }
                              if (value == 'manage_employees' && showManageEmployees) {
                                await showDialog(
                                  context: context,
                                  builder: (_) => ManageEmployeesDialog(
                                    companyId: _company.id,
                                    onSuccess: _refresh,
                                  ),
                                );
                              }
                              if (value == 'archive' && showArchive) {
                                _openArchive();
                              }
                              if (value == 'delete' && showDeleteCompany) {
                                await _confirmDeleteCompany();
                              }
                              if (value == 'reorder_tabs' && showReorderTabs) {
                                await _openReorderTabsDialog();
                              }
                            },
                            itemBuilder: (context) {
                              final items = <PopupMenuItem<String>>[];
                              if (showEditCompany) {
                                items.add(PopupMenuItem(
                                    value: 'edit', child: Text(t.editCompany)));
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
                                        style: TextStyle(
                                            color: colorScheme.error))));
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
                      _company.name,
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${t.messages}: $_unreadMessagesCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          if (_pendingTasksCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${t.tasks}: $_pendingTasksCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
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
                                        if (_isDisposed) return;
                                        if (!mounted) return;
                                        
                                        final api = ApiClient();
                                        try {
                                          await api.delete(
                                              '/accounts/${acc['id']}',
                                              queryParameters: {
                                                'company_id': _company.id
                                              });
                                          await _refresh();
                                        } catch (e) {
                                          if (!_isDisposed && mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text('${t.error}: $e')));
                                          }
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
                            labelStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
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
      ),
    );
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