import 'package:flutter/material.dart';

class AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onDelete;
  const AccountCard({super.key, required this.account, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    String icon;
    if (account['type'] == 'cash')
      icon = '💵';
    else if (account['type'] == 'bank')
      icon = '🏦';
    else
      icon = '📁';
    return Card(
      margin: const EdgeInsets.only(right: 12),
      color: Colors.white,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (account['type'] != 'cash' && account['type'] != 'bank')
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 14, color: Colors.red),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              Text(
                '${account['balance']} ₽',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                account['type'] == 'cash'
                    ? 'Наличные'
                    : (account['type'] == 'bank' ? 'Банк' : 'Другой'),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
