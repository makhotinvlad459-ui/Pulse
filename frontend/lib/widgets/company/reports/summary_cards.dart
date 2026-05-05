import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class SummaryCards extends ConsumerWidget {
  final double income;
  final double expense;
  final double profit;

  const SummaryCards({super.key, required this.income, required this.expense, required this.profit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _SummaryCard(title: t.incomeTitle, amount: income, color: Colors.green, colorScheme: colorScheme),
        const SizedBox(width: 8),
        _SummaryCard(title: t.expenseTitle, amount: expense, color: Colors.red, colorScheme: colorScheme),
        const SizedBox(width: 8),
        _SummaryCard(title: t.profitTitle, amount: profit, color: Colors.blue, colorScheme: colorScheme),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final ColorScheme colorScheme;

  const _SummaryCard({required this.title, required this.amount, required this.color, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${amount.toStringAsFixed(2)} ₽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}