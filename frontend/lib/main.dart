import 'dart:async';
import 'package:flutter/services.dart';
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
import 'services/fcm_service.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'services/error/global_error_handler.dart';
import 'screens/privacy_policy_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  
  runApp(const ProviderScope(child: MyApp()));
  _initFirebaseInBackground();
}

void _initFirebaseInBackground() {
  Future.microtask(() async {
    try {
      print('🔥 [FCM] Инициализация Firebase в фоне...');

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
        );
      } else {
        await Firebase.initializeApp();
      }

      print('✅ [FCM] Firebase инициализирован');

      // Запрос разрешений
      unawaited(
        FirebaseMessaging.instance.requestPermission().then((_) {
          print('✅ [FCM] Разрешения получены');
        }).catchError((e) {
          print('⚠️ [FCM] Ошибка разрешений: $e');
        })
      );

      // 👇👇👇 ГЛАВНОЕ ИСПРАВЛЕНИЕ 👇👇👇
      // Получаем токен и отправляем на сервер
      final fcmService = FcmService();
      
      // Сначала пробуем отправить токен (если пользователь уже авторизован)
      await fcmService.updateFcmToken();
      
      // Слушаем обновление токена
      fcmService.listenTokenRefresh();

      print('✅ [FCM] Слушатели установлены');

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
          case '/privacy-policy':
            return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());
          case '/forgot-password':
            return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}