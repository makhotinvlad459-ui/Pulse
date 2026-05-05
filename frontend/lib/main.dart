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
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final themeData = getThemeData(appTheme);
    final locale = ref.watch(localeProvider); // подписываемся на текущую локаль

    return MaterialApp(
      title: 'Pulse',
      theme: themeData,
      locale: locale, // указываем текущую локаль
      localizationsDelegates: [
        AppLocalizations.localizationsDelegates.first, // ваш генератор
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')], // без региональных суффиксов (можно оставить ru, en)
      navigatorKey: navigatorKey,
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/forgot-password':
            return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
          case '/reset-password':
            final token = settings.arguments as String?;
            if (token == null) {
              return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
            }
            return MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
            );
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}