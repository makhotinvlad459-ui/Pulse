import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../services/error/error_handler.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    final api = ApiClient();
    final t = AppLocalizations.of(context)!;
    try {
      await api.post('/auth/forgot-password',
          data: {'email': _emailController.text.trim()});
      setState(() {
        _message = t.resetLinkSent;
        _loading = false;
      });
    } catch (e) {
      final appError = ErrorHandler.handleError(e, context: context);
      setState(() {
        _message = appError.message;
        _loading = false;
      });
    }
  } // <-- ЭТА СКОБКА ЗАКРЫВАЕТ МЕТОД _sendResetLink

  void _setLanguage(Locale locale) {
    ref.read(localeProvider.notifier).setLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.forgotPasswordTitle),
        actions: [
          Row(
            children: [
              IconButton(
                icon: const Text('🇬🇧', style: TextStyle(fontSize: 28)),
                onPressed: () => _setLanguage(const Locale('en')),
              ),
              IconButton(
                icon: const Text('🇷🇺', style: TextStyle(fontSize: 28)),
                onPressed: () => _setLanguage(const Locale('ru')),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                t.forgotPasswordInstruction,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: t.emailLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t.enterEmail;
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return t.invalidEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _message!.startsWith(t.error) ? Colors.red : Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _loading ? null : _sendResetLink,
                child: Text(t.sendResetLink),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.backToLogin),
              ),
            ],
          ),
        ),
      ),
    );
  } // <-- ЭТА СКОБКА ЗАКРЫВАЕТ МЕТОД build
} 