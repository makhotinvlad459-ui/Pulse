import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../providers/locale_provider.dart';
import 'package:frontend/l10n/app_localizations.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    final api = ApiClient();
    try {
      await api.post('/auth/reset-password', data: {
        'token': widget.token,
        'new_password': _passwordController.text.trim(),
      });
      setState(() {
        _message = AppLocalizations.of(context)!.passwordChangedSuccess;
        _loading = false;
      });
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    } catch (e) {
      setState(() {
        _message = '${AppLocalizations.of(context)!.error}: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _setLanguage(Locale locale) {
    ref.read(localeProvider.notifier).setLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.resetPasswordTitle),
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
                AppLocalizations.of(context)!.resetPasswordInstruction,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.newPasswordLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.enterPassword;
                  }
                  if (value.length < 8) {
                    return AppLocalizations.of(context)!.passwordTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.confirmPasswordLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return AppLocalizations.of(context)!.passwordsDoNotMatch;
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
                      color: _message!.startsWith(AppLocalizations.of(context)!.error)
                          ? Colors.red
                          : Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _loading ? null : _resetPassword,
                child: Text(AppLocalizations.of(context)!.resetPasswordButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}