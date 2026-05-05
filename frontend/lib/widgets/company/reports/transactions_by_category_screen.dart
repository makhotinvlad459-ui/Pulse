import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class TransactionsByCategoryScreen extends ConsumerWidget {
  final int companyId;
  final int? categoryId;
  final String categoryName;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  const TransactionsByCategoryScreen({
    required this.companyId,
    this.categoryId,
    required this.categoryName,
    required this.type,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final queryParams = {
      'company_id': companyId,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
    if (categoryId != null) queryParams['category_id'] = categoryId!;
    return Scaffold(
      appBar: AppBar(title: Text('$categoryName (${type == 'income' ? t.incomeTitle : t.expenseTitle})')),
      body: FutureBuilder(
        future: ApiClient().get('/transactions', queryParameters: queryParams),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('${t.error}: ${snapshot.error}'));
          final transactions = snapshot.data!.data;
          if (transactions.isEmpty) return Center(child: Text(t.noTransactions));
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tItem = transactions[index];
              return Card(
                child: ListTile(
                  title: Text('${tItem['amount']} ₽'),
                  subtitle: Text(tItem['description'] ?? ''),
                  trailing: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(tItem['date']))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}