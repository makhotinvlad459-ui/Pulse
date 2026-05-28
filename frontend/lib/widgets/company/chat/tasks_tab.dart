import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_client.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../models/user.dart';
import 'package:frontend/l10n/app_localizations.dart';

class TasksTab extends ConsumerStatefulWidget {
  final int companyId;
  final Function(int pendingTasks)? onPendingTasksChanged;

  const TasksTab({
    super.key,
    required this.companyId,
    this.onPendingTasksChanged,
  });

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loadingTasks = true;
  String _taskFilter = 'pending';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadTasks();
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

  void _updatePendingCount() {
    final pendingCount = _tasks.where((t) => t['status'] == 'pending').length;
    widget.onPendingTasksChanged?.call(pendingCount);
  }

  Future<void> _createTask() async {
    final t = AppLocalizations.of(context)!;
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.loadEmployeesFirst)));
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
            title: Text(t.newTaskTitle, style: TextStyle(color: colorScheme.onSurface)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: t.taskName, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                      style: TextStyle(color: colorScheme.onSurface),
                      validator: (v) => v!.isEmpty ? t.enterTaskName : null),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: descController,
                      decoration: InputDecoration(labelText: t.taskDescription, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                      style: TextStyle(color: colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: t.assignTo, labelStyle: TextStyle(color: colorScheme.onSurfaceVariant)),
                    dropdownColor: colorScheme.surface,
                    style: TextStyle(color: colorScheme.onSurface),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Не назначен')),
                      ..._employees.map((e) => DropdownMenuItem(
                          value: e['user_id'], child: Text(e['full_name']))),
                    ],
                    onChanged: (v) => assigneeId = v,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(t.deadline, style: TextStyle(color: colorScheme.onSurface)),
                    trailing: Text(deadline == null ? t.notSelected : DateFormat('dd.MM.yyyy').format(deadline!),
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
                  child: Text(t.cancel, style: TextStyle(color: colorScheme.onSurfaceVariant))),
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
                        .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: Text(t.create),
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
      await _loadTasks();
    } catch (e) {
      print('Error updating task status: $e');
    }
  }

  Future<void> _deleteTask(int taskId) async {
    final t = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteTaskTitle),
        content: Text(t.deleteTaskContent),
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
    if (confirm != true) return;
    final api = ApiClient();
    try {
      await api.delete('/tasks/$taskId',
          queryParameters: {'company_id': widget.companyId});
      await _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t.error}: $e')));
    }
  }

  String _statusName(String status, AppLocalizations t) {
    switch (status) {
      case 'pending': return t.pendingStatus;
      case 'accepted': return t.acceptedStatus;
      case 'completed': return t.completedStatus;
      case 'failed': return t.failedStatus;
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _pendingTasks =>
      _tasks.where((t) => t['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _acceptedTasks =>
      _tasks.where((t) => t['status'] == 'accepted').toList();
  List<Map<String, dynamic>> get _completedTasks =>
      _tasks.where((t) => t['status'] == 'completed').toList();
  List<Map<String, dynamic>> get _failedTasks =>
      _tasks.where((t) => t['status'] == 'failed').toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final isFounder = currentUser?.role == UserRole.founder;
    final canCreateTask = true;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (canCreateTask)
                ElevatedButton.icon(
                  onPressed: _createTask,
                  icon: const Icon(Icons.add),
                  label: Text(t.newTaskButton),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              _buildFilterChips(t, colorScheme),
            ],
          ),
        ),
        Expanded(
          child: _loadingTasks
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (_pendingTasks.isNotEmpty)
                          _buildTaskSection(t.pendingStatus, _pendingTasks,
                              Colors.orange, currentUser, isFounder, colorScheme, t),
                        if (_acceptedTasks.isNotEmpty)
                          _buildTaskSection(t.acceptedStatus, _acceptedTasks,
                              Colors.blue, currentUser, isFounder, colorScheme, t),
                        if (_completedTasks.isNotEmpty)
                          _buildTaskSection(t.completedStatus, _completedTasks,
                              Colors.green, currentUser, isFounder, colorScheme, t),
                        if (_failedTasks.isNotEmpty)
                          _buildTaskSection(t.failedStatus, _failedTasks,
                              Colors.red, currentUser, isFounder, colorScheme, t),
                        if (_tasks.isEmpty)
                          Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(t.noTasks, style: TextStyle(color: colorScheme.onSurfaceVariant))),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(AppLocalizations t, ColorScheme colorScheme) {
    return Row(
      children: [
        _filterBtn('pending', t.pendingTasksTab, colorScheme),
        const SizedBox(width: 8),
        _filterBtn('accepted', t.acceptedTasksTab, colorScheme),
        const SizedBox(width: 8),
        _filterBtn('completed', t.completedTasksTab, colorScheme),
        const SizedBox(width: 8),
        _filterBtn('failed', t.failedTasksTab, colorScheme),
      ],
    );
  }

  Widget _filterBtn(String slug, String label, ColorScheme colorScheme) {
    bool active = _taskFilter == slug;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: active ? colorScheme.onPrimary : colorScheme.onSurface)),
      selected: active,
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceVariant,
      onSelected: (val) {
        if (val) {
          setState(() {
            _taskFilter = slug;
            _loadingTasks = true;
          });
          _loadTasks();
        }
      },
    );
  }

  Widget _buildTaskSection(String title, List<Map<String, dynamic>> tasks,
      Color color, User? currentUser, bool isFounder, ColorScheme colorScheme, AppLocalizations t) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text('$title (${tasks.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface)),
          ],
        ),
        children: tasks.map((task) {
          final isAssignee = task['assignee_id'] == currentUser?.id;
          final isAuthor = task['author_id'] == currentUser?.id;
          final canDelete = isFounder || isAuthor;
          final originalAuthor = task['author_name'];
          final originalAssignee = task['assignee_name'];
          final authorName = (originalAuthor == 'Основатель') ? t.founderRole : originalAuthor;
          final assigneeName = (originalAssignee == 'Основатель') ? t.founderRole : originalAssignee;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: colorScheme.surfaceContainerHighest,
            child: ExpansionTile(
              title: Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _statusColor(task['status']), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task['title'], style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
                ],
              ),
              subtitle: Text('${t.taskAuthorLabel}: $authorName', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task['description'] != null && task['description'].toString().isNotEmpty)
                        Text('📄 ${task['description']}', style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      if (assigneeName != null)
                        Text('👤 ${t.taskAssigneeLabel}: $assigneeName', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      if (task['deadline'] != null)
                        Text('⏰ ${t.deadlineLabel}: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.parse(task['deadline']).toLocal())}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (task['status'] == 'pending' && isAssignee)
                            ElevatedButton(
                              onPressed: () => _updateTaskStatus(task['id'], 'accepted'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              child: Text(t.acceptButton),
                            ),
                          if (task['status'] == 'accepted' && isAssignee)
                            ElevatedButton(
                              onPressed: () => _updateTaskStatus(task['id'], 'completed'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              child: Text(t.completeButton),
                            ),
                          if (task['status'] == 'accepted' && isAssignee)
                            ElevatedButton(
                              onPressed: () => _updateTaskStatus(task['id'], 'failed'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: Text(t.failButton),
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