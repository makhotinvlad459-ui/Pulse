import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/video_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getVideoPath(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return 'assets/videos/city.mp4';
      case AppTheme.dark:
        return 'assets/videos/dark1.mp4';
      case AppTheme.blue:
        return 'assets/videos/city_blue.mp4'; // если нет, используйте city.mp4
      case AppTheme.green:
        return 'assets/videos/city_green.mp4';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentTheme = ref.watch(themeProvider);
    final videoPath = _getVideoPath(currentTheme);

    return VideoBackground(
      key: ValueKey(videoPath),
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
                // Карточка входа (без изменений)
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
                            labelText: 'Логин',
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
                          obscureText: true,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixIcon: Icon(Icons.lock, color: Colors.grey.shade700),
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
                            onPressed: () async {
  try {
    await ref.read(authProvider.notifier).login(
      _loginController.text.trim(),
      _passwordController.text.trim(),
    );
    if (ref.read(authProvider).user != null && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  } catch (e) {
    String message;
    if (e.toString().contains('401') || e.toString().contains('Invalid credentials')) {
      message = 'Неверный логин или пароль';
    } else if (e.toString().contains('403')) {
      message = 'Учётная запись деактивирована';
    } else {
      message = 'Ошибка подключения к серверу';
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
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
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
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