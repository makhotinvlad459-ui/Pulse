import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';

class ProductionStockTab extends ConsumerStatefulWidget {
  final int companyId;
  final Set<String> permissions;
  final VoidCallback onRefresh;

  const ProductionStockTab({
    super.key,
    required this.companyId,
    required this.permissions,
    required this.onRefresh,
  });

  @override
  ConsumerState<ProductionStockTab> createState() => _ProductionStockTabState();
}

class _ProductionStockTabState extends ConsumerState<ProductionStockTab> {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        t.productionStock,
        style: TextStyle(color: colorScheme.onSurface),
      ),
    );
  }
}