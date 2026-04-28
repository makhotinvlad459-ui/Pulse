import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/home_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/video_background.dart';
import '../models/company.dart';
import '../screens/create_company_screen.dart';
import '../screens/company_screen.dart';
import '../services/api_client.dart';
import '../providers/theme_provider.dart';

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

  String _getVideoPath(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'assets/videos/for_home.mp4';
      case AppTheme.dark:
        return 'assets/videos/dark1.mp4';
      case AppTheme.blue:
        return 'assets/videos/city_blue.mp4';
      case AppTheme.green:
        return 'assets/videos/city_green.mp4';
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeProvider);
    final currentTheme = ref.watch(themeProvider);
    final videoPath = _getVideoPath(currentTheme);
    final colorScheme = Theme.of(context).colorScheme;

    return VideoBackground(
      key: ValueKey(videoPath),
      videoPath: videoPath,
      fit: BoxFit.cover,
      muted: true,
      loop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: const SettingsDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              // Верхняя панель: заголовок "Пульс" и кнопка "Настройки"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Shimmer.fromColors(
                      baseColor: colorScheme.onSurface.withOpacity(0.3),
                      highlightColor: colorScheme.onSurface,
                      period: const Duration(seconds: 2),
                      child: Text(
                        'Пульс',
                        style: GoogleFonts.caveat(fontSize: 32, color: colorScheme.onSurface),
                      ),
                    ),
                    Builder(
                      builder: (context) => Column(
                        children: [
                          IconButton(
                            icon: Icon(Icons.settings, color: colorScheme.onSurface),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                          Text(
                            'Настройки',
                            style: TextStyle(fontSize: 10, color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Подзаголовок
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Shimmer.fromColors(
                    baseColor: colorScheme.onSurface.withOpacity(0.3),
                    highlightColor: colorScheme.onSurface,
                    period: const Duration(seconds: 2),
                    child: Text(
                      'ваших финансов',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              // Основной список
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
                      final counts = data.counts as Map<String, dynamic>? ?? {};
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              _StatCard(title: 'Суммарно', amount: overview.totalAll),
                              const SizedBox(width: 8),
                              _StatCard(title: 'Наличные', amount: overview.totalCash),
                              const SizedBox(width: 8),
                              _StatCard(title: 'Банк', amount: overview.totalBank),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...companies.map((company) {
                            final unread = counts[company.id.toString()]['unread_messages'] ?? 0;
                            final pending = counts[company.id.toString()]['pending_tasks'] ?? 0;
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
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(
                      child: Text('Ошибка: $error',
                          style: TextStyle(color: colorScheme.error)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCompanyScreen()),
            );
            if (result == true) ref.invalidate(homeProvider);
          },
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ---------- Статистическая карточка ----------
class _StatCard extends StatelessWidget {
  final String title;
  final double amount;
  const _StatCard({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title,
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                '${amount.toStringAsFixed(2)} ₽',
                style: TextStyle(
                    color: colorScheme.onSurface,
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

// ---------- Карточка компании с анимированной рамкой----------
class _CompanyCard extends StatefulWidget {
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
  State<_CompanyCard> createState() => _CompanyCardState();
}

class _CompanyCardState extends State<_CompanyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final borderBase = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final borderLight = isDark ? Colors.grey.shade500 : Colors.grey.shade300;
    final highlight = isDark
        ? Colors.white.withOpacity(0.6)
        : Colors.white.withOpacity(0.8);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final double t = _animationController.value;
        // Блик движется от левого верхнего угла к правому нижнему
        final start = Alignment(-1.0 + t * 2, -1.0 + t);
        final end = Alignment(1.0 - t, 1.0 - t);

        final gradient = LinearGradient(
          begin: start,
          end: end,
          colors: [borderBase, highlight, borderLight],
          stops: const [0.0, 0.5, 1.0],
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _BorderGradient(
            gradient: gradient,
            borderRadius: 8,
            strokeWidth: 1.5,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CompanyScreen(company: widget.company)),
                  );
                  widget.ref.invalidate(homeProvider);
                },
                borderRadius: BorderRadius.circular(8),
                splashColor: colorScheme.primary.withOpacity(0.2),
                highlightColor: colorScheme.primary.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Shimmer.fromColors(
                              baseColor: colorScheme.onSurface.withOpacity(0.3),
                              highlightColor: colorScheme.onSurface,
                              period: const Duration(seconds: 2),
                              child: Text(
                                widget.company.name,
                                style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (widget.unreadMessages > 0 || widget.pendingTasks > 0)
                            Row(
                              children: [
                                if (widget.unreadMessages > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Сообщения: ${widget.unreadMessages}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                if (widget.pendingTasks > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Задачи: ${widget.pendingTasks}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Управляющий: ${widget.company.managerFullName}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      Text('Тел: ${widget.company.managerPhone}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(
                          'Сумма: ${widget.company.totalBalance.toStringAsFixed(2)} ₽',
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Вспомогательный виджет для рисования градиентной обводки
class _BorderGradient extends StatelessWidget {
  final Gradient gradient;
  final double borderRadius;
  final double strokeWidth;
  final Widget child;

  const _BorderGradient({
    required this.gradient,
    required this.borderRadius,
    required this.strokeWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BorderGradientPainter(gradient, borderRadius, strokeWidth),
      child: child,
    );
  }
}

class _BorderGradientPainter extends CustomPainter {
  final Gradient gradient;
  final double borderRadius;
  final double strokeWidth;

  _BorderGradientPainter(this.gradient, this.borderRadius, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderGradientPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ---------- Drawer настроек (адаптирован) ----------
class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final ref = ProviderScope.containerOf(context).read(authProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[800]
                  : const Color.fromARGB(255, 191, 193, 194),
            ),
            child: Text('Настройки',
                style: TextStyle(
                    fontSize: 28, color: isDark ? Colors.white : Colors.white)),
          ),
          ListTile(
            leading: Icon(Icons.people, color: colorScheme.onSurfaceVariant),
            title: Text('Сотрудники',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Список сотрудников в разработке')),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
            child: Text(
              'Выберите тему',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Consumer(
            builder: (context, ref, child) {
              final currentTheme = ref.watch(themeProvider);
              return Column(
                children: AppTheme.values.map((theme) {
                  String themeName;
                  switch (theme) {
                    case AppTheme.light:
                      themeName = 'Светлая';
                      break;
                    case AppTheme.dark:
                      themeName = 'Тёмная';
                      break;
                    case AppTheme.blue:
                      themeName = 'Голубая';
                      break;
                    case AppTheme.green:
                      themeName = 'Зелёная';
                      break;
                  }
                  return RadioListTile<AppTheme>(
                    title: Text(themeName,
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    value: theme,
                    groupValue: currentTheme,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(themeProvider.notifier).setTheme(value);
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          ExpansionTile(
            title: Text('Подписка',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            children: const [ListTile(title: Text('Статус: Активна'))],
          ),
          ExpansionTile(
            title: Text('Поддержка',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            children: const [ListTile(title: Text('Email: support@pulse.ru'))],
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