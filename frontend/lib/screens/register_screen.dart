import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/video_background.dart';
import 'package:frontend/l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
  final email = _emailController.text.trim();
  final fullName = _nameController.text.trim();
  final password = _passwordController.text.trim();
  final confirm = _confirmController.text.trim();

  if (!email.contains('@') || !email.contains('.')) {
    _showSnackBar(AppLocalizations.of(context)!.invalidEmail);
    return;
  }
  if (fullName.isEmpty) {
    _showSnackBar(AppLocalizations.of(context)!.enterName);
    return;
  }
  if (password.length < 8) {
    _showSnackBar(AppLocalizations.of(context)!.passwordTooShort);
    return;
  }
  if (password != confirm) {
    _showSnackBar(AppLocalizations.of(context)!.passwordsDoNotMatch);
    return;
  }

  final authNotifier = ref.read(authProvider.notifier);
  final success = await authNotifier.register(email, null, fullName, password);
  print('📝 Register success: $success, mounted: $mounted');
  if (!mounted) return;
  if (success) {
    await Future.delayed(const Duration(milliseconds: 100));
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    final error = ref.read(authProvider).error ?? AppLocalizations.of(context)!.registrationError;
    _showSnackBar(error);
  }
}
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setLanguage(Locale locale) {
    ref.read(localeProvider.notifier).setLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return VideoBackground(
      videoPath: 'assets/videos/city.mp4',
      fit: BoxFit.cover,
      muted: true,
      loop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, double scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Column(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.registrationTitle,
                            style: GoogleFonts.orbitron(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Colors.grey.shade800,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 0),
                                  blurRadius: 6,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.registrationSubtitle,
                            style: GoogleFonts.orbitron(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Card(
                  elevation: 0,
                  color: Colors.white.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.emailRequired,
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.email, color: Colors.grey.shade700),
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.nameRequired,
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.person, color: Colors.grey.shade700),
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.passwordMin8,
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.lock, color: Colors.grey.shade700),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: AppLocalizations.of(context)!.confirmPassword,
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade700),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (authState.isLoading)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade800.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(AppLocalizations.of(context)!.registerButton),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.alreadyHaveAccount,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade900,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.signIn,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.passwordWarning,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}