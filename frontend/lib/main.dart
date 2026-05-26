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
import 'services/websocket_service.dart';
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
      
      initialRoute: '/',
      
      onGenerateRoute: (RouteSettings settings) {
        final routeName = settings.name ?? '';

        if (routeName == '/' || routeName.isEmpty || routeName.contains('reset-password')) {
          final uriBase = Uri.base;
          
          if (uriBase.path.contains('reset-password') || 
              uriBase.fragment.contains('reset-password') || 
              routeName.contains('reset-password')) {
            
            final token = uriBase.queryParameters['token'] ?? 
                          Uri.parse(uriBase.fragment).queryParameters['token'] ??
                          Uri.parse(routeName).queryParameters['token'];

            if (token != null && token.isNotEmpty) {
              return MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(token: token),
              );
            }
          }
          
          return MaterialPageRoute(builder: (_) => const LoginScreen());
        }

        switch (routeName) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/forgot-password':
            return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}