import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';

class TransactionsByCategoryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final queryParams = {
      'company_id': companyId,
      'type': type,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
    };
    if (categoryId != null) queryParams['category_id'] = categoryId!;
    return Scaffold(
      appBar: AppBar(title: Text('$categoryName (${type == 'income' ? 'Приход' : 'Расход'})')),
      body: FutureBuilder(
        future: ApiClient().get('/transactions', queryParameters: queryParams),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          final transactions = snapshot.data!.data;
          if (transactions.isEmpty) return const Center(child: Text('Нет операций'));
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              return Card(
                child: ListTile(
                  title: Text('${t['amount']} ₽'),
                  subtitle: Text(t['description'] ?? ''),
                  trailing: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(t['date']))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}