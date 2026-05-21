import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'package:frontend/l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final themeData = getThemeData(appTheme);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Pulse',
      theme: themeData,
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.localizationsDelegates.first,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      navigatorKey: navigatorKey,
      initialRoute: '/login',
      onGenerateRoute: (RouteSettings settings) {
        // 1. Проверяем прямые переходы внутри приложения через Navigator.pushNamed
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
        if (settings.name == '/register') {
          return MaterialPageRoute(builder: (_) => const RegisterScreen());
        }
        if (settings.name == '/home') {
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
        if (settings.name == '/forgot-password') {
          return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
        }

        // 2. Проверяем, не является ли это ссылкой сброса пароля (из письма).
        // Проверяем как Uri.base (реальный URL браузера), так и settings.name
        final uriBase = Uri.base;
        
        // Ссылка подходит, если путь в браузере содержит '/reset-password' 
        // или если во Flutter Web роутинг идет через хэш (например, /#/reset-password)
        final isResetPath = uriBase.path == '/reset-password' || 
                            uriBase.fragment.startsWith('/reset-password') ||
                            (settings.name?.contains('reset-password') ?? false);

        if (isResetPath) {
          // Ищем токен везде, где он может быть: в query, в fragment-query или в самом settings.name
          final token = uriBase.queryParameters['token'] ?? 
                        Uri.parse(uriBase.fragment).queryParameters['token'] ??
                        Uri.parse(settings.name ?? '').queryParameters['token'];

          if (token != null && token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
            );
          }
          // Если зашли на страницу сброса, но токена нет — отправляем на восстановление
          return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
        }

        // 3. Дефолтный роут, если ничего не подошло
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      },
    );
  }
}