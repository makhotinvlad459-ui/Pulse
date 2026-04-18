import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../providers/home_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/matrix_rain.dart';
import '../widgets/ecg_widget.dart';
import '../models/company.dart';
import '../screens/create_company_screen.dart';
import '../screens/company_screen.dart';
import '../services/api_client.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  WebSocketChannel? _userChannel;

  @override
  void initState() {
    super.initState();
    _connectUserWebSocket();
  }

  @override
  void dispose() {
    _userChannel?.sink.close();
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
    print('🟢 Connecting to user WS: $wsUrl');

    _userChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _userChannel!.stream.listen((message) {
      print('🟢 User WS message: $message');
      final data = jsonDecode(message);
      if (data['type'] == 'update_counters') {
        ref.invalidate(homeProvider);
      }
    }, onError: (error) {
      print('🔴 User WS error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeProvider);

    return Scaffold(
      drawer: const SettingsDrawer(),
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
          MatrixRain(color: Colors.black, opacity: 0.4),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: ECGWidget(
                    color: Colors.grey.shade600,
                    width: 200,
                    height: 60,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Пульс',
                        style: GoogleFonts.caveat(
                          fontSize: 32,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.bar_chart,
                                color: Colors.grey.shade700),
                            onPressed: () {},
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              icon: Icon(Icons.settings,
                                  color: Colors.grey.shade700),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(homeProvider);
                      await Future.delayed(Duration.zero);
                    },
                    child: homeAsync.when(
                      data: (data) {
                        final companies = data.companies;
                        final overview = data.overview;
                        final counts =
                            data.counts as Map<String, dynamic>? ?? {};
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                _StatCard(
                                    title: 'Суммарно',
                                    amount: overview.totalAll),
                                const SizedBox(width: 8),
                                _StatCard(
                                    title: 'Наличные',
                                    amount: overview.totalCash),
                                const SizedBox(width: 8),
                                _StatCard(
                                    title: 'Банк', amount: overview.totalBank),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...companies.map((company) {
                              final unread = counts[company.id.toString()]
                                      ?['unread_messages'] ??
                                  0;
                              final pending = counts[company.id.toString()]
                                      ?['pending_tasks'] ??
                                  0;
                              return _CompanyCard(
                                company: company,
                                ref: ref,
                                unreadMessages: unread,
                                pendingTasks: pending,
                              );
                            }),
                          ],
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: Text('Ошибка: $error',
                            style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCompanyScreen()),
          );
          if (result == true) ref.invalidate(homeProvider);
        },
        backgroundColor: Colors.blueGrey.shade300,
        foregroundColor: Colors.black87,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  const _StatCard({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                '${amount.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final Company company;
  final WidgetRef ref;
  final int unreadMessages;
  final int pendingTasks;
  const _CompanyCard({
    required this.company,
    required this.ref,
    required this.unreadMessages,
    required this.pendingTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                company.name,
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
            if (unreadMessages > 0)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadMessages',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            if (pendingTasks > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$pendingTasks',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Управляющий: ${company.managerFullName}',
                style: TextStyle(color: Colors.grey.shade700)),
            Text('Тел: ${company.managerPhone}',
                style: TextStyle(color: Colors.grey.shade700)),
            Text('Сумма: ${company.totalBalance.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                    color: Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CompanyScreen(company: company)),
          );
          ref.invalidate(homeProvider);
        },
      ),
    );
  }
}

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = ProviderScope.containerOf(context).read(authProvider.notifier);
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration:
                BoxDecoration(color: Color.fromARGB(255, 191, 193, 194)),
            child: Text('Настройки',
                style: TextStyle(fontSize: 28, color: Colors.white)),
          ),
          ListTile(
            leading: const Icon(Icons.people, color: Colors.black87),
            title: const Text('Сотрудники'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Список сотрудников в разработке')),
              );
            },
          ),
          const ExpansionTile(
            title: Text('Подписка', style: TextStyle(color: Colors.black87)),
            children: [ListTile(title: Text('Статус: Активна'))],
          ),
          const ExpansionTile(
            title: Text('Поддержка', style: TextStyle(color: Colors.black87)),
            children: [ListTile(title: Text('Email: support@pulse.ru'))],
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              await ref.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
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
