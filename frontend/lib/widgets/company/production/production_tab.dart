import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import 'manufactured_products_tab.dart';
import 'production_journal_tab.dart';

class ProductionTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  final VoidCallback onRefresh;

  const ProductionTab({
    super.key,
    required this.companyId,
    required this.permissions,
    required this.onRefresh,
  });

  @override
  ConsumerState<ProductionTab> createState() => _ProductionTabState();
}

class _ProductionTabState extends ConsumerState<ProductionTab> {
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            tabs: [
              Tab(text: t.productionJournal),
              Tab(text: t.manufacturedProducts),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ProductionJournalTab(
                  companyId: widget.companyId,
                  permissions: widget.permissions,
                  onRefresh: widget.onRefresh,
                ),
                ManufacturedProductsTab(
                  companyId: widget.companyId,
                  permissions: widget.permissions,
                  onRefresh: widget.onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}