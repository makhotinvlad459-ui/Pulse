import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class PeriodSelector extends ConsumerWidget {
  final String periodMode;
  final VoidCallback onDay;
  final VoidCallback onWeek;
  final VoidCallback onMonth;
  final VoidCallback onYear;
  final VoidCallback onCustom;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool showArrows;

  const PeriodSelector({
    super.key,
    required this.periodMode,
    required this.onDay,
    required this.onWeek,
    required this.onMonth,
    required this.onYear,
    required this.onCustom,
    required this.onPrevious,
    required this.onNext,
    this.showArrows = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (showArrows) ...[
          _buildArrowButton(Icons.arrow_back_ios, onPrevious, colorScheme),
          const SizedBox(width: 8),
          _buildArrowButton(Icons.arrow_forward_ios, onNext, colorScheme),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPeriodButton(t.dayLabel, 'day', onDay, colorScheme),
              _buildPeriodButton(t.weekLabel, 'week', onWeek, colorScheme),
              _buildPeriodButton(t.monthLabel, 'month', onMonth, colorScheme),
              _buildPeriodButton(t.yearLabel, 'year', onYear, colorScheme),
              ElevatedButton(
                onPressed: onCustom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  foregroundColor: colorScheme.onSurface,
                ),
                child: Text(t.customButton),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrowButton(IconData icon, VoidCallback onPressed, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.primaryContainer,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 20, color: colorScheme.onPrimaryContainer),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String mode, VoidCallback onPressed, ColorScheme colorScheme) {
    final isSelected = periodMode == mode;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }
}