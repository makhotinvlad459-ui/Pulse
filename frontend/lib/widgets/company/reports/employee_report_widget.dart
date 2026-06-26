import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../services/api_client.dart';
import '../../../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class EmployeeReportWidget extends ConsumerStatefulWidget {
  final int companyId;
  const EmployeeReportWidget({super.key, required this.companyId});

  @override
  ConsumerState<EmployeeReportWidget> createState() => _EmployeeReportWidgetState();
}

class _EmployeeReportWidgetState extends ConsumerState<EmployeeReportWidget> {
  List<Map<String, dynamic>> _reportData = [];
  bool _loading = false;
  bool _isDisposed = false;
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _loadData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isDisposed) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final transactionsRes = await _api.get('/statistics/employee-transactions', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });

      final journalRes = await _api.get('/statistics/employee-journal', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });

      final productionRes = await _api.get('/statistics/employee-production', queryParameters: {
        'company_id': widget.companyId,
        'start_date': _startDate.toIso8601String(),
        'end_date': _endDate.toIso8601String(),
      });

      if (_isDisposed) return;
      if (!mounted) return;

      final Map<String, Map<String, dynamic>> merged = {};

      final t = AppLocalizations.of(context)!;

      // Транзакции
      final transData = transactionsRes.data as List? ?? [];
      for (var item in transData) {
        String name = item['employee_name'] ?? 'Неизвестный';
        if (name == 'Основатель') {
          name = t.founderRole;
        }
        merged[name] ??= {
          'employee_name': name,
          'transactions_count': 0,
          'transactions_sum': 0.0,
          'journal_count': 0,
          'journal_sum': 0.0,
          'production_shifts': 0,
        };
        merged[name]!['transactions_count'] = (merged[name]!['transactions_count'] ?? 0) + (item['count'] ?? 0);
        merged[name]!['transactions_sum'] = (merged[name]!['transactions_sum'] ?? 0.0) + (item['total'] ?? 0.0);
      }

      // Журнал
      final journalData = journalRes.data as List? ?? [];
      for (var item in journalData) {
        String name = item['employee_name'] ?? 'Неизвестный';
        if (name == 'Основатель') {
          name = t.founderRole;
        }
        merged[name] ??= {
          'employee_name': name,
          'transactions_count': 0,
          'transactions_sum': 0.0,
          'journal_count': 0,
          'journal_sum': 0.0,
          'production_shifts': 0,
        };
        merged[name]!['journal_count'] = (merged[name]!['journal_count'] ?? 0) + (item['count'] ?? 0);
        merged[name]!['journal_sum'] = (merged[name]!['journal_sum'] ?? 0.0) + (item['total'] ?? 0.0);
      }

      // Производство
      final productionData = productionRes.data as List? ?? [];
      for (var item in productionData) {
        String name = item['employee_name'] ?? 'Неизвестный';
        if (name == 'Основатель') {
          name = t.founderRole;
        }
        merged[name] ??= {
          'employee_name': name,
          'transactions_count': 0,
          'transactions_sum': 0.0,
          'journal_count': 0,
          'journal_sum': 0.0,
          'production_shifts': 0,
        };
        merged[name]!['production_shifts'] = (merged[name]!['production_shifts'] ?? 0) + (item['shifts'] ?? 0);
      }

      _reportData = merged.values.toList();
      _reportData.sort((a, b) => (a['employee_name'] ?? '').compareTo(b['employee_name'] ?? ''));

      if (_isDisposed) return;
      if (!mounted) return;

      setState(() => _loading = false);
    } catch (e) {
      if (_isDisposed) return;
      if (!mounted) return;

      setState(() => _loading = false);
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t.error}: $e')),
      );
    }
  }

  Future<void> _selectPeriod() async {
    if (_isDisposed) return;
    if (!mounted) return;

    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: Localizations.localeOf(context),
    );
    if (_isDisposed) return;
    if (!mounted) return;

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadData();
    }
  }

  Future<void> _exportToExcel() async {
    if (_reportData.isEmpty) return;
    final t = AppLocalizations.of(context)!;
    final currency = t.currencySymbol;

    var excelFile = excel.Excel.createExcel();
    var sheet = excelFile.sheets.values.first;
    sheet.rows.clear();

    sheet.appendRow([
      t.employeeName,
      t.transactionsCount,
      t.transactionsSum,
      t.journalEntriesCount,
      t.journalSum,
      t.productionShifts,
    ]);

    for (var item in _reportData) {
      sheet.appendRow([
        item['employee_name'] ?? '',
        item['transactions_count'] ?? 0,
        (item['transactions_sum'] ?? 0.0).toStringAsFixed(2),
        item['journal_count'] ?? 0,
        (item['journal_sum'] ?? 0.0).toStringAsFixed(2),
        item['production_shifts'] ?? 0,
      ]);
    }

    int totalTransactions = 0;
    double totalTransactionsSum = 0.0;
    int totalJournal = 0;
    double totalJournalSum = 0.0;
    int totalShifts = 0;

    for (var item in _reportData) {
      totalTransactions += (item['transactions_count'] ?? 0) as int;
      totalTransactionsSum += (item['transactions_sum'] ?? 0.0) as double;
      totalJournal += (item['journal_count'] ?? 0) as int;
      totalJournalSum += (item['journal_sum'] ?? 0.0) as double;
      totalShifts += (item['production_shifts'] ?? 0) as int;
    }

    sheet.appendRow([]);
    sheet.appendRow([
      '${t.totalLabel}:',
      totalTransactions,
      totalTransactionsSum.toStringAsFixed(2),
      totalJournal,
      totalJournalSum.toStringAsFixed(2),
      totalShifts,
    ]);

    final bytes = excelFile.encode();
    if (bytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'employee_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/employee_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(path)], text: t.exportReport);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = t.currencySymbol;

    int totalTransactions = 0;
    double totalTransactionsSum = 0.0;
    int totalJournal = 0;
    double totalJournalSum = 0.0;
    int totalShifts = 0;

    for (var item in _reportData) {
      totalTransactions += (item['transactions_count'] ?? 0) as int;
      totalTransactionsSum += (item['transactions_sum'] ?? 0.0) as double;
      totalJournal += (item['journal_count'] ?? 0) as int;
      totalJournalSum += (item['journal_sum'] ?? 0.0) as double;
      totalShifts += (item['production_shifts'] ?? 0) as int;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Панель управления
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: _selectPeriod,
              icon: Icon(Icons.calendar_today, size: isSmallScreen ? 16 : 18, color: colorScheme.onSurfaceVariant),
              label: Text(
                '${DateFormat('dd.MM.yy').format(_startDate)} - ${DateFormat('dd.MM.yy').format(_endDate)}',
                style: TextStyle(fontSize: isSmallScreen ? 11 : 13, color: colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _exportToExcel,
              icon: Icon(Icons.download, size: isSmallScreen ? 16 : 18),
              label: Text(t.exportToExcel, style: TextStyle(fontSize: isSmallScreen ? 11 : 13)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: isSmallScreen ? 6 : 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_reportData.isEmpty)
          Center(
            child: Text(
              t.noData,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          Column(
            children: [
              // Карточка с общей статистикой
              Card(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: isSmallScreen ? 8 : 16,
                    runSpacing: 8,
                    children: [
                      _buildStatChip(
                        icon: Icons.receipt,
                        label: t.transactionsCount,
                        value: totalTransactions.toString(),
                        color: Colors.blue,
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatChip(
                        icon: Icons.attach_money,
                        label: t.transactionsSum,
                        value: '${totalTransactionsSum.toStringAsFixed(2)}$currency',
                        color: Colors.green,
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatChip(
                        icon: Icons.calendar_month,
                        label: t.journalEntriesCount,
                        value: totalJournal.toString(),
                        color: Colors.orange,
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatChip(
                        icon: Icons.summarize,
                        label: t.journalSum,
                        value: '${totalJournalSum.toStringAsFixed(2)}$currency',
                        color: Colors.purple,
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatChip(
                        icon: Icons.factory,
                        label: t.productionShifts,
                        value: totalShifts.toString(),
                        color: Colors.teal,
                        isSmallScreen: isSmallScreen,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Таблица с горизонтальным скроллом
              Container(
                constraints: BoxConstraints(
                  minWidth: screenWidth - 32,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: isSmallScreen ? 8 : 14,
                    headingRowColor: WidgetStateProperty.all(colorScheme.primary),
                    headingTextStyle: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 10 : 12,
                    ),
                    dataRowMaxHeight: isSmallScreen ? 40 : 48,
                    columns: [
                      DataColumn(
                        label: SizedBox(
                          width: isSmallScreen ? 100 : 130,
                          child: Text(t.employeeName, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: isSmallScreen ? 110 : 140,
                          child: Text(t.transactionsCount, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: isSmallScreen ? 110 : 140,
                          child: Text(t.transactionsSum, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: isSmallScreen ? 130 : 160,
                          child: Text(t.journalEntriesCount, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: isSmallScreen ? 110 : 140,
                          child: Text(t.journalSum, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: isSmallScreen ? 110 : 140,
                          child: Text(t.productionShifts, style: TextStyle(fontSize: isSmallScreen ? 10 : 12)),
                        ),
                      ),
                    ],
                    rows: _reportData.map((item) {
                      final name = item['employee_name'] ?? 'Неизвестный';
                      final transCount = item['transactions_count'] ?? 0;
                      final transSum = item['transactions_sum'] ?? 0.0;
                      final journalCount = item['journal_count'] ?? 0;
                      final journalSum = item['journal_sum'] ?? 0.0;
                      final shifts = item['production_shifts'] ?? 0;

                      return DataRow(cells: [
                        DataCell(
                          SizedBox(
                            width: isSmallScreen ? 100 : 130,
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                                fontSize: isSmallScreen ? 11 : 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            transCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${transSum.toStringAsFixed(2)}$currency',
                            style: TextStyle(
                              color: transSum > 0 ? Colors.green : colorScheme.onSurface,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            journalCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${journalSum.toStringAsFixed(2)}$currency',
                            style: TextStyle(
                              color: journalSum > 0 ? Colors.orange : colorScheme.onSurface,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            shifts.toString(),
                            style: TextStyle(
                              color: shifts > 0 ? Colors.teal : colorScheme.onSurface,
                              fontWeight: shifts > 0 ? FontWeight.w500 : FontWeight.normal,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              // Итого
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${t.totalLabel}:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        fontSize: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    Text(
                      '${t.transactionsCount}: $totalTransactions',
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colorScheme.onSurface),
                    ),
                    Text(
                      '${t.transactionsSum}: ${totalTransactionsSum.toStringAsFixed(2)}$currency',
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colorScheme.onSurface),
                    ),
                    Text(
                      '${t.journalEntriesCount}: $totalJournal',
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colorScheme.onSurface),
                    ),
                    Text(
                      '${t.journalSum}: ${totalJournalSum.toStringAsFixed(2)}$currency',
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colorScheme.onSurface),
                    ),
                    Text(
                      '${t.productionShifts}: $totalShifts',
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12, color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isSmallScreen,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 12, vertical: isSmallScreen ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmallScreen ? 12 : 14, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 8 : 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}