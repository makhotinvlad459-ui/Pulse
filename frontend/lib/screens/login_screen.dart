import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/video_background.dart';

// Единый экземпляр LocalAuthentication
final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final biometricProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) return false;
  final localAuth = ref.read(localAuthProvider);
  try {
    final canCheck = await localAuth.canCheckBiometrics;
    final isDeviceSupported = await localAuth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  } catch (e) {
    return false;
  }
});

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _rememberMe = false;

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

  Future<void> _authenticateWithBiometrics() async {
    final biometricAvailable = await ref.read(biometricProvider.future);
    if (!biometricAvailable) return;

    final localAuth = ref.read(localAuthProvider);
    try {
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Подтвердите вход с помощью биометрии',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        final savedLogin = await _storage.read(key: 'saved_login');
        final savedPassword = await _storage.read(key: 'saved_password');
        if (savedLogin != null && savedPassword != null) {
          await _performLogin(savedLogin, savedPassword);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Нет сохранённых учётных данных для входа по биометрии')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка биометрической аутентификации')),
        );
      }
    }
  }

  Future<void> _performLogin(String login, String password) async {
    try {
      await ref.read(authProvider.notifier).login(login, password);
      if (ref.read(authProvider).user != null && mounted) {
        if (_rememberMe) {
          await _storage.write(key: 'saved_login', value: login);
          await _storage.write(key: 'saved_password', value: password);
          await _storage.write(key: 'remember_me', value: 'true');
        } else {
          await _storage.delete(key: 'saved_password');
          await _storage.write(key: 'saved_login', value: login);
          await _storage.write(key: 'remember_me', value: 'false');
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      String message;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('401') || errorStr.contains('invalid credentials')) {
        message = 'Неверный логин или пароль';
      } else if (errorStr.contains('403')) {
        message = 'Учётная запись деактивирована';
      } else if (errorStr.contains('socket') || errorStr.contains('network')) {
        message = 'Ошибка подключения к серверу';
      } else {
        message = 'Произошла неизвестная ошибка';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentTheme = ref.watch(themeProvider);
    final videoPath = _getVideoPath(currentTheme);
    final biometricAsync = ref.watch(biometricProvider);

    return VideoBackground(
      key: ValueKey('$videoPath-${currentTheme.name}'),
      videoPath: videoPath,
      fit: BoxFit.cover,
      muted: true,
      loop: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                              'Пульс',
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
                                'ваших финансов',
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
                    side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _loginController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Логин (email или телефон)',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.person, color: Colors.grey.shade700),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
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
                          obscureText: true,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.lock, color: Colors.grey.shade700),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
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
                            const Text('Запомнить меня'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (authState.isLoading)
                          const CircularProgressIndicator()
                        else
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  await _performLogin(
                                    _loginController.text.trim(),
                                    _passwordController.text.trim(),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800.withOpacity(0.8),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Войти'),
                              ),
                              biometricAsync.maybeWhen(
                                data: (isAvailable) => isAvailable
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: OutlinedButton.icon(
                                          onPressed: _authenticateWithBiometrics,
                                          icon: const Icon(Icons.fingerprint),
                                          label: const Text('Войти по отпечатку пальца'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.grey.shade800,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade900,
                          ),
                          child: Text(
                            'Нет аккаунта? Создать аккаунт',
                            style: TextStyle(
                              color: Colors.grey.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade900,
                          ),
                          child: const Text('Забыли пароль?'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Приложение не собирает персональные данные пользователей и не обрабатывает их.\n',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
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