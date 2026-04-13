import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/home_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/graphite_background.dart';
import '../models/company.dart';
import '../screens/create_company_screen.dart';
import '../screens/company_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Пульс',
            style: GoogleFonts.caveat(fontSize: 28, color: Colors.black87)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              // TODO: перейти к отчётам
            },
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: const SettingsDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeProvider);
          await Future.delayed(Duration.zero);
        },
        child: GraphiteBackground(
          child: homeAsync.when(
            data: (data) {
              final companies = data.companies;
              final overview = data.overview;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        _StatCard(
                            title: 'Суммарно на счетах',
                            amount: overview.totalAll),
                        const SizedBox(width: 8),
                        _StatCard(
                            title: 'Наличные', amount: overview.totalCash),
                        const SizedBox(width: 8),
                        _StatCard(title: 'Банк', amount: overview.totalBank),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: companies.length,
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        return _CompanyCard(company: company);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Ошибка: $error',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
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

class _CompanyCard extends ConsumerWidget {
  final Company company;
  const _CompanyCard({required this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        title: Text(company.name,
            style: const TextStyle(
                color: Colors.black87, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(color: Colors.blueGrey),
            child: Text('Настройки',
                style: TextStyle(fontSize: 28, color: Colors.white)),
          ),
          const ExpansionTile(
            title: Text('Сотрудники', style: TextStyle(color: Colors.black87)),
            children: [ListTile(title: Text('Список сотрудников будет здесь'))],
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
