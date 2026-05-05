import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DynamicsChart extends StatelessWidget {
  final List<FlSpot> incomeSpots;
  final List<FlSpot> expenseSpots;
  final List<String> xLabels;
  final Function(int) onSpotTapped;

  const DynamicsChart({
    super.key,
    required this.incomeSpots,
    required this.expenseSpots,
    required this.xLabels,
    required this.onSpotTapped,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (incomeSpots.isEmpty || incomeSpots.length <= 2) {
      return const Center(child: Text('Нет данных для графика'));
    }
    return Container(
      padding: const EdgeInsets.only(right: 40),
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(NumberFormat.compact().format(value), style: TextStyle(color: colorScheme.onSurface)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 70,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= xLabels.length) return const Text('');
                  return Transform.rotate(
                    angle: -0.5,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(xLabels[index], style: TextStyle(fontSize: 10, color: colorScheme.onSurface)),
                    ),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.green.withOpacity(0.2)),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.red.withOpacity(0.2)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) => LineTooltipItem(
                  '${spot.barIndex == 0 ? 'Доход' : 'Расход'}: ${spot.y.toStringAsFixed(2)} ₽',
                  const TextStyle(color: Colors.white),
                )).toList();
              },
            ),
            handleBuiltInTouches: true,
            touchCallback: (FlTouchEvent event, response) {
              if (event is FlTapUpEvent && response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                onSpotTapped(response.lineBarSpots!.first.x.toInt());
              }
            },
          ),
        ),
      ),
    );
  }
}