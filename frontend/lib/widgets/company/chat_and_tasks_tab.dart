import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'chat_tab.dart';
import 'tasks_tab.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [Tab(text: t.chatTab), Tab(text: t.tasksTab)],
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              ChatTab(
                companyId: widget.companyId,
                onUnreadMessagesChanged: widget.onUnreadMessagesChanged,
              ),
              TasksTab(
                companyId: widget.companyId,
                onPendingTasksChanged: widget.onPendingTasksChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}