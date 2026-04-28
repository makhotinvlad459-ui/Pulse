import 'package:flutter/material.dart';

class AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onDelete;
  final bool isFounder;

  const AccountCard({
    super.key,
    required this.account,
    required this.onDelete,
    required this.isFounder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String icon;
    if (account['type'] == 'cash')
      icon = '💵';
    else if (account['type'] == 'bank')
      icon = '🏦';
    else
      icon = '📁';

    final isArchive = account['name'] == 'Архив';
    final balance = (account['balance'] as num).toDouble();
    final canDelete = isFounder && account['type'] == 'other' && !isArchive;

    return Card(
      margin: const EdgeInsets.only(right: 12),
      color: colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 120,
        height: 90,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      account['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              if (!isArchive || balance != 0)
                Text(
                  '${balance.toStringAsFixed(2)} ₽',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                )
              else
                Text(
                  'Архив',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              Text(
                account['type'] == 'cash'
                    ? 'Наличные'
                    : (account['type'] == 'bank' ? 'Банк' : 'Пользовательский'),
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}