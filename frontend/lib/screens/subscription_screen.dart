import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
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
      setState(() {
        _status = res.data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки статуса: $e')),
      );
    }
  }

  Future<void> _buyWithYooKassa(String plan) async {
    final api = ApiClient();
    try {
      final res = await api.post('/subscription/create-payment', data: {'plan': plan});
      final url = res.data['confirmation_url'];
      // Открыть URL в браузере (на мобильных устройствах — внешний браузер, на вебе — новая вкладка)
      await _openUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания платежа: $e')),
      );
    }
  }

  Future<void> _openUrl(String url) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    String shortUrl = url.length > 50 ? '${url.substring(0, 50)}...' : url;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть ссылку: $shortUrl')),
    );
  }
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

    return Scaffold(
      appBar: AppBar(title: Text(t.subscription)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Статус
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _status['has_active_subscription']
                          ? '✅ ${t.activeSubscription}'
                          : '❌ ${t.noActiveSubscription}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (_status['subscription_expires_at'] != null)
                      Text('${t.expiresAt}: ${_status['subscription_expires_at']}'),
                    Text('${t.companiesCount}: ${_status['companies_count']} / ${_status['free_companies_limit']}'),
                    Text('${t.remainingFreeCompanies}: ${_status['remaining_free_companies']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(t.chooseTariff, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTariffCard(t.monthly, '480 ₽', () => _buyWithYooKassa('monthly')),
            _buildTariffCard(t.halfYear, '2400 ₽', () => _buyWithYooKassa('half_year')),
            _buildTariffCard(t.yearly, '4000 ₽', () => _buyWithYooKassa('yearly')),
            _buildTariffCard(t.extraCompany, '200 ₽', () => _buyWithYooKassa('extra_company')),
            const SizedBox(height: 16),
            Text(
              t.paymentNote,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTariffCard(String title, String price, VoidCallback onPress) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(price),
        trailing: ElevatedButton(
          onPressed: onPress,
          child: const Text('Купить'),
        ),
      ),
    );
  }
}