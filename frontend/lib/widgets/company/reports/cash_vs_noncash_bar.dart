import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class CashVsNoncashBar extends ConsumerWidget {
  final double cash;
  final double noncash;

  const CashVsNoncashBar({super.key, required this.cash, required this.noncash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;
    final total = cash + noncash;
    if (total == 0) return Text(t.noData, style: TextStyle(color: colorScheme.onSurfaceVariant));
    final cashPercent = (cash / total * 100).clamp(0, 100);
    final noncashPercent = (noncash / total * 100).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          child: Row(
            children: [
              Expanded(
                flex: cashPercent.toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)),
                  ),
                  child: Center(child: Text('${cashPercent.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
              Expanded(
                flex: noncashPercent.toInt(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                  ),
                  child: Center(child: Text('${noncashPercent.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Container(width: 12, height: 12, color: Colors.orange), const SizedBox(width: 4), Text('${t.cash}: ${cash.toStringAsFixed(2)}$currency', style: TextStyle(color: colorScheme.onSurfaceVariant))]),
            Row(children: [Container(width: 12, height: 12, color: Colors.blue), const SizedBox(width: 4), Text('${t.nonCash}: ${noncash.toStringAsFixed(2)}$currency', style: TextStyle(color: colorScheme.onSurfaceVariant))]),
          ],
        ),
      ],
    );
  }
}