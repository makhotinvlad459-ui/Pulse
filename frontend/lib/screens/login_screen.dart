import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../services/secure_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/video_background.dart';
import 'package:frontend/l10n/app_localizations.dart';
import '../services/api_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SecureStorage _storage = SecureStorage();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final savedLogin = await _storage.read(key: 'saved_login');
    final savedPassword = await _storage.read(key: 'saved_password');
    final savedRemember = await _storage.read(key: 'remember_me');
    if (mounted) {
      setState(() {
        if (savedLogin != null) _loginController.text = savedLogin;
        if (savedPassword != null) _passwordController.text = savedPassword;
        _rememberMe = savedRemember == 'true';
      });
    }
  }

  Future<void> _performLogin(String login, String password) async {
    final authNotifier = ref.read(authProvider.notifier);
    final currentLocale = ref.read(localeProvider);

    final success = await authNotifier.login(login, password, currentLocale);

    if (!mounted) return;

    if (success) {
      // Сохранение учетных данных
      if (_rememberMe) {
        await _storage.write(key: 'saved_login', value: login);
        await _storage.write(key: 'saved_password', value: password);
        await _storage.write(key: 'remember_me', value: 'true');
      } else {
        await _storage.delete(key: 'saved_password');
        await _storage.write(key: 'saved_login', value: login);
        await _storage.write(key: 'remember_me', value: 'false');
      }

      // Отправка FCM-токена
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await ApiClient().post('/chat/fcm-token', data: {'fcm_token': fcmToken});
        }
      } catch (e) {
        print('Error sending FCM token: $e');
      }

      // Синхронизация языка
      try {
        await authNotifier.syncLanguage(currentLocale.languageCode);
        print('Language synced: ${currentLocale.languageCode}');
      } catch (e) {
        print('Error syncing language: $e');
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      final error = ref.read(authProvider).error ?? 'Неизвестная ошибка';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  String _getVideoPath(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'assets/videos/city.mp4';
      case AppTheme.dark:
        return 'assets/videos/dark1.mp4';
      case AppTheme.blue:
        return 'assets/videos/city_blue.mp4';
      case AppTheme.green:
        return 'assets/videos/city_green.mp4';
    }
  }

  void _setLanguage(Locale locale) async {
    final notifier = ref.read(localeProvider.notifier);
    notifier.setLocale(locale);

    final authState = ref.read(authProvider);
    if (authState.user != null) {
      try {
        await ref.read(authProvider.notifier).syncLanguage(locale.languageCode);
        print('Language synced to server: ${locale.languageCode}');
      } catch (e) {
        print('Error syncing language: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentTheme = ref.watch(themeProvider);
    final videoPath = _getVideoPath(currentTheme);
    final t = AppLocalizations.of(context);

    return VideoBackground(
      key: ValueKey('$videoPath-${currentTheme.name}'),
      videoPath: videoPath,
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
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey.shade400,
                        highlightColor: Colors.grey.shade800,
                        period: const Duration(seconds: 2),
                        child: Column(
                          children: [
                            Text(
                              t?.appTitle ?? 'Pulse',
                              style: GoogleFonts.orbitron(
                                fontSize: 52,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade400,
                              highlightColor: Colors.grey.shade700,
                              period: const Duration(seconds: 2),
                              child: Text(
                                t?.subtitle ?? 'Управляйте своим бизнесом',
                                style: GoogleFonts.orbitron(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    side: BorderSide(
                        color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _loginController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: t?.loginLabel ?? 'Email или телефон',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon:
                                Icon(Icons.person, color: Colors.grey.shade700),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.grey.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: t?.passwordLabel ?? 'Пароль',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon:
                                Icon(Icons.lock, color: Colors.grey.shade700),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Colors.grey.shade700, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? false;
                                });
                              },
                            ),
                            Text(t?.rememberMe ?? 'Запомнить меня'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        authState.isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: () async {
                                  await _performLogin(
                                    _loginController.text.trim(),
                                    _passwordController.text.trim(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.grey.shade800.withOpacity(0.8),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(t?.signIn ?? 'Войти'),
                              ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade900,
                          ),
                          child: Text(
                            t?.noAccount ?? 'Нет аккаунта? Зарегистрируйтесь',
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/forgot-password'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade900,
                          ),
                          child: Text(t?.forgotPassword ?? 'Забыли пароль?'),
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