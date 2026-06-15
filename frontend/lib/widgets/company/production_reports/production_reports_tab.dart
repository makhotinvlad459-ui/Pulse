import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'production_journal_report_widget.dart';
import 'production_sales_report_widget.dart';
import 'sell_through_report_widget.dart';

class ProductionReportsTab extends ConsumerStatefulWidget {
  final int companyId;
  const ProductionReportsTab({super.key, required this.companyId});

  @override
  ConsumerState<ProductionReportsTab> createState() => _ProductionReportsTabState();
}

class _ProductionReportsTabState extends ConsumerState<ProductionReportsTab> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Кнопки переключения вкладок
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              _buildTabButton(0, t.productionJournalReport, Icons.factory, colorScheme),
              _buildTabButton(1, t.productionSalesReport, Icons.sell, colorScheme),
              _buildTabButton(2, t.sellThroughReport, Icons.trending_up, colorScheme),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Контент - просто показываем выбранную вкладку, без Expanded
        _selectedTab == 0
            ? ProductionJournalReportWidget(companyId: widget.companyId)
            : _selectedTab == 1
                ? ProductionSalesReportWidget(companyId: widget.companyId)
                : SellThroughReportWidget(companyId: widget.companyId),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, ColorScheme colorScheme) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}