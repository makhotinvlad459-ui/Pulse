import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class ChatAndTasksTab extends ConsumerStatefulWidget {
  final int companyId;
  final bool isManager;
  final Function(int unreadMessages)? onUnreadMessagesChanged;
  final Function(int pendingTasks)? onPendingTasksChanged;

  const ChatAndTasksTab({
    super.key,
    required this.companyId,
    this.isManager = false,
    this.onUnreadMessagesChanged,
    this.onPendingTasksChanged,
  });

  @override
  ConsumerState<ChatAndTasksTab> createState() => _ChatAndTasksTabState();
}

class _ChatAndTasksTabState extends ConsumerState<ChatAndTasksTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loadingMessages = true;
  bool _loadingTasks = true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastVisit;

  WebSocketChannel? _chatChannel;
  WebSocketChannel? _tasksChannel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEmployees().then((_) async {
      await _loadChatMessages();
      await _loadTasks();
      _connectWebSockets();
      if (_tabController.index == 0) {
        await _markChatRead();
        _lastVisit = DateTime.now();
      }
    });
    _tabController.addListener(() async {
      if (_tabController.index == 0) {
        await _markChatRead();
        _lastVisit = DateTime.now();
        await _loadChatMessages();
      } else if (_tabController.index == 1) {
        await _loadTasks();
      }
    });
  }

  @override
  void dispose() {
    _chatChannel?.sink.close();
    _tasksChannel?.sink.close();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _connectWebSockets() async {
    final api = ApiClient();
    final token = await api.getToken();
    if (token == null) return;

    final baseUrl = ApiClient.baseUrl;
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    final chatUrl = '$wsBase/ws/chat/${widget.companyId}?token=$token';
    final tasksUrl = '$wsBase/ws/tasks/${widget.companyId}?token=$token';

    _chatChannel = WebSocketChannel.connect(Uri.parse(chatUrl));
    _chatChannel!.stream.listen((data) {
      _handleChatEvent(data);
    }, onError: (error) {
      print('Chat WebSocket error: $error');
    });

    _tasksChannel = WebSocketChannel.connect(Uri.parse(tasksUrl));
    _tasksChannel!.stream.listen((data) {
      _handleTaskEvent(data);
    }, onError: (error) {
      print('Tasks WebSocket error: $error');
    });
  }

  void _handleChatEvent(dynamic rawData) {
    final data = rawData is String ? jsonDecode(rawData) : rawData;
    final type = data['type'];
    setState(() {
      switch (type) {
        case 'new_message':
          _messages.add(data['message']);
          _scrollToBottom();
          break;
        case 'edit_message':
          final messageId = data['message_id'];
          final newText = data['new_message'];
          final index = _messages.indexWhere((m) => m['id'] == messageId);
          if (index != -1) {
            _messages[index]['message'] = newText;
            _messages[index]['edited'] = true;
            _messages[index]['updated_at'] = data['updated_at'];
          }
          break;
        case 'clear_chat':
          _messages.clear();
          break;
      }
      _updateUnreadCount();
    });
  }

  void _handleTaskEvent(dynamic rawData) {
    final data = rawData is String ? jsonDecode(rawData) : rawData;
    final type = data['type'];
    setState(() {
      switch (type) {
        case 'new_task':
          final newTask = data['task'];
          _tasks.insert(0, newTask);
          break;
        case 'update_task_status':
          final taskId = data['task_id'];
          final newStatus = data['new_status'];
          final index = _tasks.indexWhere((t) => t['id'] == taskId);
          if (index != -1) {
            _tasks[index]['status'] = newStatus;
            _tasks[index]['updated_at'] = data['updated_at'];
          }
          break;
        case 'delete_task':
          final taskId = data['task_id'];
          _tasks.removeWhere((t) => t['id'] == taskId);
          break;
      }
      _updatePendingCount();
    });
  }

  void _updateUnreadCount() {
    int unread = 0;
    if (_lastVisit != null) {
      unread = _messages
          .where((msg) => DateTime.parse(msg['created_at']).isAfter(_lastVisit!))
          .length;
    }
    widget.onUnreadMessagesChanged?.call(unread);
  }

  void _updatePendingCount() {
    final pendingCount = _tasks.where((t) => t['status'] == 'pending').length;
    widget.onPendingTasksChanged?.call(pendingCount);
  }

  Future<void> _markChatRead() async {
    final api = ApiClient();
    try {
      await api.post('/chat/company/${widget.companyId}/mark-read');
    } catch (e) {
      print('Error marking chat read: $e');
    }
  }

  Future<void> _loadEmployees() async {
    final api = ApiClient();
    try {
      final res = await api.get('/companies/${widget.companyId}/members');
      final members = List<Map<String, dynamic>>.from(res.data);
      setState(() {
        _employees = members;
      });
    } catch (e) {
      print('Error loading employees: $e');
    }
  }

  Future<void> _loadChatMessages() async {
    final api = ApiClient();
    try {
      final res = await api.get('/chat/company/${widget.companyId}');
      final newMessages = List<Map<String, dynamic>>.from(res.data);
      setState(() {
        _messages = newMessages;
        _loadingMessages = false;
      });
      _updateUnreadCount();
      _scrollToBottom();
      if (_tabController.index == 0) {
        await _markChatRead();
        _lastVisit = DateTime.now();
      }
    } catch (e) {
      setState(() => _loadingMessages = false);
      print('Error loading chat: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadTasks() async {
    final api = ApiClient();
    try {
      final res = await api.get('/tasks', queryParameters: {'company_id': widget.companyId});
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(res.data);
        _loadingTasks = false;
      });
      _updatePendingCount();
    } catch (e) {
      setState(() => _loadingTasks = false);
      print('Error loading tasks: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final api = ApiClient();
    try {
      await api.post('/chat/company/${widget.companyId}', data: {'message': text});
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить чат?'),
        content: const Text('Все сообщения будут удалены безвозвратно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Очистить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/chat/company/${widget.companyId}/clear');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _editMessage(Map<String, dynamic> msg) async {
    final controller = TextEditingController(text: msg['message']);
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать сообщение', style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Новый текст', hintStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
            style: TextStyle(color: colorScheme.onSurface),
            maxLines: 3),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant))),
          ElevatedButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) return;
              final api = ApiClient();
              try {
                await api.patch('/chat/message/${msg['id']}',
                    data: {'message': newText});
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Загрузка списка сотрудников... Попробуйте позже')));
      return;
    }
    final titleController = TextEditingController();
    final descController = TextEditingController();
    int? assigneeId;
    DateTime? deadline;
    final formKey = GlobalKey<FormState>();
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Новая задача', style: TextStyle(color: colorScheme.onSurface)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Название', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                      style: TextStyle(color: colorScheme.onSurface),
                      validator: (v) => v!.isEmpty ? 'Введите название' : null),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: descController,
                      decoration: InputDecoration(labelText: 'Описание', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                      style: TextStyle(color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: 'Назначить', labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(color: colorScheme.onSurface),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не назначено')),
                      ..._employees.map((e) => DropdownMenuItem(
                          value: e['user_id'], child: Text(e['full_name']))),
                    ],
                    onChanged: (v) => assigneeId = v,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text('Дедлайн', style: TextStyle(color: colorScheme.onSurface)),
                    trailing: Text(deadline == null ? 'Не выбран' : DateFormat('dd.MM.yyyy').format(deadline!),
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null)
                        setStateDialog(() => deadline = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена', style: TextStyle(color: colorScheme.onSurfaceVariant))),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final api = ApiClient();
                  try {
                    await api.post('/tasks', queryParameters: {
                      'company_id': widget.companyId
                    }, data: {
                      'title': titleController.text,
                      'description': descController.text,
                      'assignee_id': assigneeId,
                      'deadline': deadline?.toIso8601String(),
                    });
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateTaskStatus(int taskId, String newStatus) async {
    final api = ApiClient();
    try {
      await api.patch('/tasks/$taskId/status',
          queryParameters: {'company_id': widget.companyId},
          data: {'status': newStatus});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _deleteTask(int taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить задачу?'),
        content: const Text('Задача будет удалена безвозвратно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/tasks/$taskId',
          queryParameters: {'company_id': widget.companyId});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  String _statusName(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидают';
      case 'accepted':
        return 'Приняты';
      case 'completed':
        return 'Выполнены';
      case 'failed':
        return 'Провалены';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _pendingTasks =>
      _tasks.where((t) => t['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _completedTasks =>
      _tasks.where((t) => t['status'] == 'completed').toList();
  List<Map<String, dynamic>> get _failedTasks =>
      _tasks.where((t) => t['status'] == 'failed').toList();
  List<Map<String, dynamic>> get _acceptedTasks =>
      _tasks.where((t) => t['status'] == 'accepted').toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final isFounder = currentUser?.role == UserRole.founder;
    final canCreateTask = true;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Чат'), Tab(text: 'Задачи')],
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Чат
              Column(
                children: [
                  if (isFounder)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.red),
                        onPressed: _clearChat,
                        tooltip: 'Очистить чат',
                      ),
                    ),
                  Expanded(
                    child: _loadingMessages
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg['user_id'] == currentUser?.id;
                              final displayName = msg['user_full_name'];
                              return _buildMessageBubble(isMe, displayName, msg, isFounder, colorScheme);
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Введите сообщение...',
                              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: IconButton(
                            icon: Icon(Icons.send, color: colorScheme.onPrimaryContainer),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Задачи
              Column(
                children: [
                  if (canCreateTask)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: _createTask,
                        icon: const Icon(Icons.add),
                        label: const Text('Новая задача'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _loadingTasks
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                if (_pendingTasks.isNotEmpty)
                                  _buildTaskSection('Ожидают', _pendingTasks,
                                      Colors.orange, currentUser, isFounder, colorScheme),
                                if (_acceptedTasks.isNotEmpty)
                                  _buildTaskSection('Приняты', _acceptedTasks,
                                      Colors.blue, currentUser, isFounder, colorScheme),
                                if (_completedTasks.isNotEmpty)
                                  _buildTaskSection(
                                      'Выполнены',
                                      _completedTasks,
                                      Colors.green,
                                      currentUser,
                                      isFounder,
                                      colorScheme),
                                if (_failedTasks.isNotEmpty)
                                  _buildTaskSection('Провалены', _failedTasks,
                                      Colors.red, currentUser, isFounder, colorScheme),
                                if (_tasks.isEmpty)
                                  Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text('Нет задач', style: TextStyle(color: colorScheme.onSurfaceVariant))),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
      bool isMe, String displayName, Map<String, dynamic> msg, bool isFounder, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                displayName,
                style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isMe ? colorScheme.primary : colorScheme.onSurface),
              ),
              if (msg['edited'] == true) ...[
                const SizedBox(width: 4),
                Text('(изменено)',
                    style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              ],
              const Spacer(),
              if (isMe || isFounder)
                IconButton(
                  icon: Icon(Icons.edit, size: 16, color: colorScheme.onSurfaceVariant),
                  onPressed: () => _editMessage(msg),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isMe ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1))
              ],
            ),
            child: Text(msg['message'],
                style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface)),
          ),
          const SizedBox(height: 4),
          Text(DateFormat('HH:mm').format(DateTime.parse(msg['created_at'])),
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTaskSection(String title, List<Map<String, dynamic>> tasks,
      Color color, User? currentUser, bool isFounder, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
                width: 14,
                height: 14,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text('$title (${tasks.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
          ],
        ),
        children: tasks.map((task) {
          final isAssignee = task['assignee_id'] == currentUser?.id;
          final isAuthor = task['author_id'] == currentUser?.id;
          final canDelete = isFounder || isAuthor || widget.isManager;
          final authorName = task['author_name'];
          final assigneeName = task['assignee_name'];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: colorScheme.surfaceContainerHighest,
            child: ExpansionTile(
              title: Row(
                children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: _statusColor(task['status']),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(task['title'],
                          style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
                ],
              ),
              subtitle: Text('Автор: $authorName',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task['description'] != null)
                        Text('📄 ${task['description']}',
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      if (assigneeName != null)
                        Text('👤 Назначена: $assigneeName',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      if (task['deadline'] != null)
                        Text('⏰ Дедлайн: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(task['deadline']))}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (task['status'] == 'pending' && isAssignee)
                            ElevatedButton(
                              onPressed: () => _updateTaskStatus(task['id'], 'accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Принять'),
                            ),
                          if (task['status'] == 'accepted' && isAssignee)
                            ElevatedButton(
                              onPressed: () => _updateTaskStatus(task['id'], 'completed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Выполнить'),
                            ),
                          if (task['status'] == 'accepted' && isAssignee)
                            ElevatedButton(
                              onPressed: () => _updateTaskStatus(task['id'], 'failed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Провалить'),
                            ),
                          if (canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTask(task['id']),
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