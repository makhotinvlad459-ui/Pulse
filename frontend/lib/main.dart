import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/websocket_service.dart';
import 'services/push_notifications.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'services/error/global_error_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.initialize();

  // 🔥 Запускаем приложение сразу, не дожидаясь Firebase
  runApp(const ProviderScope(child: MyApp()));

  // 📡 Инициализируем Firebase в фоне (без блокировки UI)
  _initFirebaseInBackground();
}

/// Фоновая инициализация Firebase с таймаутом 10 секунд
void _initFirebaseInBackground() {
  Future.microtask(() async {
    try {
      print('🔥 [FCM] Инициализация Firebase в фоне...');

      // Инициализация Firebase с таймаутом 10 секунд
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyBXoRO7sp49PotOrUEPmTsbRxCpcDpdyZ0",
            authDomain: "pulse-yourmoney.firebaseapp.com",
            projectId: "pulse-yourmoney",
            storageBucket: "pulse-yourmoney.firebasestorage.app",
            messagingSenderId: "267395124760",
            appId: "1:267395124760:web:93231e40b80650ccf9bd6d",
          ),
        ).timeout(const Duration(seconds: 10));
      } else {
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      }

      print('✅ [FCM] Firebase инициализирован');

      // Запрос разрешения + получение токена с таймаутом 10 секунд
      try {
        await FirebaseMessaging.instance
            .requestPermission()
            .timeout(const Duration(seconds: 5));

        final token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 10));

        if (token != null && token.isNotEmpty) {
          print('✅ [FCM] Токен получен: $token');
          // Можно сохранить токен на сервер, если нужно
        } else {
          print('⚠️ [FCM] Токен не получен (пустой)');
        }
      } catch (e) {
        print('⚠️ [FCM] Ошибка при получении токена: $e');
      }

    } catch (e, stack) {
      print('❌ [FCM] Ошибка инициализации Firebase: $e');
      print('Stack: $stack');
    }
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _initNotificationListeners();
  }

  /// Только слушатели уведомлений (без запроса токена)
  void _initNotificationListeners() {
    Future.microtask(() async {
      try {
        await PushNotificationsService.initListeners();
      } catch (e) {
        print('⚠️ [Notifications] Ошибка инициализации слушателей: $e');
      }
    });
  }

  @override
  void dispose() {
    WebSocketService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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