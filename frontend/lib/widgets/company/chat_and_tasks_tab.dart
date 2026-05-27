import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import '../../services/api_client.dart';
import '../../services/image_compression.dart';
import '../../services/websocket_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user.dart';
import 'package:frontend/l10n/app_localizations.dart';

enum _MessageAction { edit, delete, cancel }

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

class _ChatAndTasksTabState extends ConsumerState<ChatAndTasksTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiClient _apiClient = ApiClient();
  final WebSocketService _wsService = WebSocketService();

  // Состояния для чата
  final List<dynamic> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _chatLoading = true;
  int? _editingMessageId;

  // Переменные для хранения вложения ПЕРЕД отправкой (Превью)
  XFile? _chatPhoto;
  PlatformFile? _chatWebFile;

  // Состояния для задач
  List<dynamic> _tasks = [];
  bool _tasksLoading = true;
  String _taskFilter = 'pending';

  // Для списков исполнителей (при создании задачи)
  List<dynamic> _members = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadMessages(),
      _loadTasks(),
      _loadCompanyMembers(),
    ]);
    _markChatAsRead();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await _apiClient.get('/chat/company/${widget.companyId}');
      if (res != null) {
        // Извлекаем данные из Dio Response, если вернулся объект ответа
        final List<dynamic> dataList = (res is List) ? res : (res.data is List ? res.data : []);
        setState(() {
          _messages.clear();
          _messages.addAll(dataList);
          _chatLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      setState(() => _chatLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final res = await _apiClient.get('/tasks/company/${widget.companyId}?status=$_taskFilter');
      if (res != null) {
        final List<dynamic> dataList = (res is List) ? res : (res.data is List ? res.data : []);
        setState(() {
          _tasks = dataList;
          _tasksLoading = false;
        });
        _updatePendingTasksCount();
      }
    } catch (_) {
      setState(() => _tasksLoading = false);
    }
  }

  Future<void> _loadCompanyMembers() async {
    try {
      final res = await _apiClient.get('/companies/${widget.companyId}/members');
      if (res != null) {
        final List<dynamic> dataList = (res is List) ? res : (res.data is List ? res.data : []);
        setState(() {
          _members = dataList;
        });
      }
    } catch (_) {}
  }

  Future<void> _markChatAsRead() async {
    try {
      await _apiClient.post('/chat/company/${widget.companyId}/mark-read');
      if (widget.onUnreadMessagesChanged != null) {
        widget.onUnreadMessagesChanged!(0);
      }
    } catch (_) {}
  }

  void _updatePendingTasksCount() {
    if (widget.onPendingTasksChanged != null) {
      int pCount = _tasks.where((t) => t['status'] == 'pending' || t['status'] == 'accepted').length;
      widget.onPendingTasksChanged!(pCount);
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

  // Выбор файлов (Скрепка)
  Future<void> _pickAttachment() async {
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _chatWebFile = result.files.first;
          _chatPhoto = null;
        });
      }
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _chatPhoto = picked;
          _chatWebFile = null;
        });
      }
    }
  }

  // Камера
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _chatPhoto = picked;
        _chatWebFile = null;
      });
    }
  }

  // Метод отправки сообщения
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _chatPhoto == null && _chatWebFile == null) return;

    String? uploadedUrl;

    if (_chatPhoto != null || _chatWebFile != null) {
      setState(() => _chatLoading = true);
      try {
        String filename = _chatPhoto != null ? _chatPhoto!.name : _chatWebFile!.name;
        List<int> bytes = _chatPhoto != null ? await _chatPhoto!.readAsBytes() : _chatWebFile!.bytes!;

        // Сжимаем байты
        final compressedBytes = await ImageCompression.compressImage(Uint8List.fromList(bytes));

        // Вызываем загрузчик. Передаем путь/эндпоинт, байты и имя файла
        final Map<String, dynamic> uploadResult = await _apiClient.uploadChatFile(
          '/chat/upload',
          compressedBytes,
          filename,
        );
        
        // Достаем url из ответа бэкенда (поменяй 'url' на свой ключ, если он другой, например 'attachment_url')
        uploadedUrl = uploadResult['url'] ?? uploadResult['attachment_url'];
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки файла: $e")),
        );
        setState(() => _chatLoading = false);
        return;
      }
    }

    try {
      if (_editingMessageId != null) {
        await _apiClient.patch('/chat/message/$_editingMessageId', data: {'message': text});
        setState(() {
          _editingMessageId = null;
          _messageController.clear();
        });
      } else {
        await _apiClient.post('/chat/company/${widget.companyId}', data: {
          'message': text,
          'attachment_url': uploadedUrl,
        });
        _messageController.clear();
        setState(() {
          _chatPhoto = null;
          _chatWebFile = null;
        });
      }
    } catch (_) {}
    setState(() => _chatLoading = false);
  }

  void _startEditing(int id, String text) {
    setState(() {
      _editingMessageId = id;
      _messageController.text = text;
    });
  }

  Future<void> _deleteMessage(int id) async {
    try {
      await _apiClient.delete('/chat/message/$id');
    } catch (_) {}
  }

  Future<void> _createTask(String title, String desc, int? assigneeId, DateTime? deadline) async {
    try {
      await _apiClient.post('/tasks/company/${widget.companyId}');
      _loadTasks();
    } catch (_) {}
  }

  Future<void> _updateTaskStatus(int taskId, String newStatus) async {
    try {
      await _apiClient.patch('/tasks/$taskId/status');
      _loadTasks();
    } catch (_) {}
  }

  Future<void> _deleteTask(int taskId) async {
    try {
      await _apiClient.delete('/tasks/$taskId');
      _loadTasks();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final currentTheme = Theme.of(context);
    final colorScheme = currentTheme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            tabs: [
              Tab(text: t?.chatTab ?? "Чат"),
              Tab(text: t?.tasksTab ?? "Задачи"),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatView(t, colorScheme, currentTheme),
          _buildTasksView(t, colorScheme, currentTheme),
        ],
      ),
    );
  }

  Widget _buildChatView(AppLocalizations? t, ColorScheme colorScheme, ThemeData currentTheme) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id ?? 0;
    final isFounder = authState.user?.role == 'founder';

    return Column(
      children: [
        Expanded(
          child: _chatLoading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, idx) {
                    final msg = _messages[idx];
                    final isMe = msg['user_id'] == currentUserId;
                    return _buildMessageBubble(msg, isMe, isFounder, t, colorScheme, currentTheme);
                  },
                ),
        ),

        // === ВИЗУАЛЬНОЕ ПРЕВЬЮ ВЛОЖЕНИЯ ПЕРЕД ОТПРАВКОЙ ===
        if (_chatPhoto != null || _chatWebFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.5),
              border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_file, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _chatPhoto != null ? _chatPhoto!.name : _chatWebFile!.name,
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _chatPhoto = null;
                      _chatWebFile = null;
                    });
                  },
                ),
              ],
            ),
          ),

        // ПОЛЕ ВВОДА СООБЩЕНИЯ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.attach_file, color: colorScheme.primary),
                onPressed: _pickAttachment,
              ),
              if (!kIsWeb)
                IconButton(
                  icon: Icon(Icons.camera_alt, color: colorScheme.primary),
                  onPressed: _takePhoto,
                ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: _editingMessageId != null ? "Редактирование..." : (t?.chatHint ?? "Сообщение..."),
                    hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: Icon(_editingMessageId != null ? Icons.check : Icons.send, color: colorScheme.primary),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
    dynamic msg,
    bool isMe,
    bool isFounder,
    AppLocalizations? t,
    ColorScheme colorScheme,
    ThemeData currentTheme,
  ) {
    final timeStr = msg['created_at'] != null
        ? DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal())
        : '';
    final hasAttachment = msg['attachment_url'] != null && msg['attachment_url'].toString().isNotEmpty;

    return GestureDetector(
      onLongPress: () {
        if (isMe || isFounder) {
          _showActionsMenu(msg['id'], msg['message'], isMe, t);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  msg['user_full_name'] != null && msg['user_full_name'].toString().isNotEmpty
                      ? msg['user_full_name'].toString().substring(0, 1).toUpperCase()
                      : 'U',
                  style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? colorScheme.primary : colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(0),
                    bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMe)
                      Text(
                        msg['user_full_name'] ?? 'User',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 2),

                    if (hasAttachment)
                      GestureDetector(
                        onTap: () => _openPhotoViewer(msg['attachment_url']),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6, top: 4),
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              msg['attachment_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 150,
                                  height: 100,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    if (msg['message'] != null && msg['message'].toString().isNotEmpty)
                      Text(
                        msg['message'],
                        style: TextStyle(
                          color: isMe ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (msg['edited'] == true)
                          Text(
                            "ред. ",
                            style: TextStyle(
                              fontSize: 9,
                              color: (isMe ? colorScheme.onPrimary : colorScheme.onSurfaceVariant).withOpacity(0.6),
                            ),
                          ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 9,
                            color: (isMe ? colorScheme.onPrimary : colorScheme.onSurfaceVariant).withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: PhotoView(
                imageProvider: NetworkImage(url),
                loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      "Не удалось открыть изображение",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionsMenu(int msgId, String currentText, bool isMe, AppLocalizations? t) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(t?.editButton ?? 'Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEditing(msgId, currentText);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(t?.deleteButton ?? 'Delete', style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(msgId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTasksView(AppLocalizations? t, ColorScheme colorScheme, ThemeData currentTheme) {
    return Column(
      children: [
        _buildTaskFilterRow(t, colorScheme),
        Expanded(
          child: _tasksLoading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
                  ? Center(child: Text(t?.noTasks ?? "Нет задач"))
                  : RefreshIndicator(
                      onRefresh: _loadTasks,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _buildTaskGroup(t, colorScheme, currentTheme),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTaskFilterRow(AppLocalizations? t, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterBtn('pending', t?.pendingTasksTab ?? "Активные"),
          _filterBtn('accepted', t?.acceptedTasksTab ?? "В процессе"),
          _filterBtn('completed', t?.completedTasksTab ?? "Готово"),
          _filterBtn('failed', t?.failedTasksTab ?? "Провалено"),
        ],
      ),
    );
  }

  Widget _filterBtn(String slug, String label) {
    bool active = _taskFilter == slug;
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: active ? colorScheme.onPrimary : colorScheme.onSurface)),
      selected: active,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceVariant,
      onSelected: (val) {
        if (val) {
          setState(() {
            _taskFilter = slug;
            _tasksLoading = true;
          });
          _loadTasks();
        }
      },
    );
  }

  Widget _buildTaskGroup(AppLocalizations? t, ColorScheme colorScheme, ThemeData currentTheme) {
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id ?? 0;
    final isFounder = authState.user?.role == 'founder';

    return Column(
      children: _tasks.map((task) {
        bool isCreator = task['creator_id'] == currentUserId;
        bool isAssignee = task['assignee_id'] == currentUserId;
        bool canDelete = isFounder || isCreator;

        final assigneeLabel = t?.assigneeField ?? "Исполнитель";
        final unassignedLabel = t?.unassignedField ?? "Не назначен";
        final deadlineLabel = t?.deadlineField ?? "Дедлайн";

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: ExpansionTile(
            title: Text(
              task['title'] ?? '',
              style: GoogleFonts.ubuntu(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            subtitle: Text(
              "$assigneeLabel: ${task['assignee_full_name'] ?? unassignedLabel}",
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                      Text(task['description'], style: TextStyle(color: colorScheme.onSurface)),
                      const SizedBox(height: 8),
                    ],
                    if (task['deadline'] != null) ...[
                      Text(
                        "$deadlineLabel: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(task['deadline']).toLocal())}",
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (task['status'] == 'pending' && isAssignee)
                          ElevatedButton(
                            onPressed: () => _updateTaskStatus(task['id'], 'accepted'),
                            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                            child: Text(t?.acceptButton ?? "Принять"),
                          ),
                        if (task['status'] == 'accepted' && isAssignee)
                          ElevatedButton(
                            onPressed: () => _updateTaskStatus(task['id'], 'completed'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: Text(t?.completeButton ?? "Завершить"),
                          ),
                        if (task['status'] == 'accepted' && isAssignee)
                          ElevatedButton(
                            onPressed: () => _updateTaskStatus(task['id'], 'failed'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: Text(t?.failButton ?? "Провалить"),
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
    );
  }
}

extension on DateTime {
  String toIsoformatString() => toIso8601String();
}