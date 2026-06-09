import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/error/error_handler.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _loading = true;
  Map<String, dynamic> _status = {};

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final api = ApiClient();
    try {
      final res = await api.get('/subscription/status');
      if (mounted) {
        setState(() {
          _status = res.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
    setState(() => _loading = false);
    await ErrorHandler.showErrorDialog(
      context,
      e,
      onRetry: _loadStatus,
      );
    }
  }
}


  Future<void> _buyWithYooKassa(String plan) async {
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;
    try {
      final res = await api.post(
        '/subscription/create-payment',
        data: {'plan': plan},
      );
      final url = res.data['confirmation_url'];
      if (url != null && url is String && url.isNotEmpty) {
        await _openUrl(url);
      } else {
        _showSnackBar(t.errorPaymentUrlNotFound);
      }
    } catch (e) {
      _showSnackBar(t.errorCreatingPayment + ': $e');
    }
  }

  Future<void> _openUrl(String url) async {
    final t = AppLocalizations.of(context)!;
    final Uri uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar(t.errorCannotOpenLink);
      }
    } catch (e) {
      _showSnackBar(t.errorOpeningLink + ': $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeProvider);
    final t = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t.subscription)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasActive = _status['has_active_subscription'] ?? false;
    final remainingTransactions = _status['remaining_transactions'] ?? 0;
    final remainingMessages = _status['remaining_messages'] ?? 0;
    final remainingCompanies = _status['remaining_companies'] ?? 0;
    final transactionsUsed = _status['transactions_used'] ?? 0;
    final messagesUsed = _status['messages_used'] ?? 0;
    final companiesUsed = _status['companies_count'] ?? 0;
    final transactionsLimit = _status['transactions_limit'] ?? 40;
    final messagesLimit = _status['messages_limit'] ?? 40;
    final companiesLimit = _status['companies_limit'] ?? 2;
    final extraCompanies = _status['extra_companies'] ?? 0;
    final nextPayment = _status['next_payment_amount'] ?? 500;
    final expiresAt = _status['subscription_expires_at'];

    final bool isBlocked = !hasActive &&
        (remainingTransactions <= 0 ||
            remainingMessages <= 0 ||
            remainingCompanies <= 0);

    return Scaffold(
      appBar: AppBar(title: Text(t.subscription)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== СТАТУС ПОДПИСКИ ==========
            Card(
              color: hasActive ? Colors.green.shade50 : null,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          hasActive ? Icons.check_circle : Icons.cancel,
                          color: hasActive ? Colors.green : Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          hasActive
                              ? '✅ ${t.activeSubscription}'
                              : '❌ ${t.noActiveSubscription}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (expiresAt != null && expiresAt.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${t.expiresAt}: $expiresAt'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ========== ЛИМИТЫ ==========
            Text(
              t.remainingFreeOperations,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Лимит транзакций
            _buildLimitCard(
              icon: Icons.receipt,
              title: t.transactions,
              used: transactionsUsed,
              limit: transactionsLimit,
              remaining: remainingTransactions,
              color: Colors.blue,
              t: t,
            ),
            const SizedBox(height: 8),

            // Лимит сообщений
            _buildLimitCard(
              icon: Icons.chat,
              title: t.chatMessages,
              used: messagesUsed,
              limit: messagesLimit,
              remaining: remainingMessages,
              color: Colors.orange,
              t: t,
            ),
            const SizedBox(height: 8),

            // Лимит компаний
            _buildLimitCard(
              icon: Icons.business,
              title: t.companies,
              used: companiesUsed,
              limit: companiesLimit,
              remaining: remainingCompanies,
              color: Colors.green,
              t: t,
            ),
            const SizedBox(height: 24),

            // ========== БЛОКИРОВКА ==========
            if (isBlocked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.limitReachedWarning,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // ========== ТАРИФЫ ==========
            Text(
              t.selectPlan,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Базовая подписка
            _buildTariffCard(
              title: t.basicSubscription,
              subtitle: t.basicSubscriptionDescription,
              price: '${nextPayment.toInt()} ${t.currencySymbol}',
              priceNote:
                  extraCompanies > 0
                      ? '${t.extraCompaniesInfo(extraCompanies, extraCompanies * 250)}'
                      : null,
              onPress: () => _buyWithYooKassa('monthly'),
              isRecommended: true,
              t: t,
            ),

            // Дополнительная компания
            _buildTariffCard(
              title: t.extraCompany,
              subtitle: t.extraCompanyDescription,
              price: '250 ${t.currencySymbol}',
              priceNote: t.forever,
              onPress: () => _buyWithYooKassa('extra_company'),
              isRecommended: false,
              t: t,
            ),

            const SizedBox(height: 16),
            Text(
              t.subscriptionInfoText,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitCard({
    required IconData icon,
    required String title,
    required int used,
    required int limit,
    required int remaining,
    required Color color,
    required AppLocalizations t,
  }) {
    final percent = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final isLimitExhausted = remaining <= 0;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  isLimitExhausted
                      ? t.limitExhausted
                      : '${t.remaining}: $remaining',
                  style: TextStyle(
                    color: isLimitExhausted ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade200,
              color: percent >= 0.9 ? Colors.orange : color,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 4),
            Text(
              '${t.used}: $used ${t.outOf} $limit',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTariffCard({
    required String title,
    required String subtitle,
    required String price,
    String? priceNote,
    required VoidCallback onPress,
    required bool isRecommended,
    required AppLocalizations t,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isRecommended
                ? BorderSide(color: Colors.green, width: 2)
                : BorderSide.none,
      ),
      child: ListTile(
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isRecommended)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text(t.recommended, style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.green.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (priceNote != null)
              Text(
                priceNote,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              price,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (priceNote != t.forever)
              Text(
                t.perMonth,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
          ],
        ),
        onTap: onPress,
      ),
    );
  }
}