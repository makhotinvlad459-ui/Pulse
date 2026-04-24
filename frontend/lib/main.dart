import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/cupertino.dart';  // для GlobalCupertinoLocalizations
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'widgets/adaptive_background.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pulse',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // добавили
      ],
      supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],
      routes: {
        '/login': (context) => const AdaptiveBackground(child: LoginScreen()),
        '/register': (context) => const AdaptiveBackground(child: RegisterScreen()),
        '/home': (context) => const AdaptiveBackground(child: HomeScreen()),
      },
    );
  }
}