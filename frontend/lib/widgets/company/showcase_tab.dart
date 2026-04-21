import 'package:flutter/material.dart';

class ShowcaseTab extends StatelessWidget {
  final int companyId;
  const ShowcaseTab({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Витрина в разработке',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь будут отображаться популярные товары и быстрые продажи',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}