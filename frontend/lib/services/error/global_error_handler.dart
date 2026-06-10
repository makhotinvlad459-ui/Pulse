// lib/core/error/global_error_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'error_handler.dart';
import '../../main.dart';

class GlobalErrorHandler {
  static void initialize() {
    if (kDebugMode) return;
    
    FlutterError.onError = (FlutterErrorDetails details) {
      final errorMessage = details.exception.toString();
      
      // ✅ ТОЛЬКО WebSocket ошибки игнорируем
      // Нет интернета и другие ошибки — показываем!
      if (_isWebSocketError(errorMessage)) {
        print('⚠️ Ignored WebSocket error (not showing to user): $errorMessage');
        return; // Не показываем WebSocket ошибки
      }
      
      // Все остальные ошибки показываем
      FlutterError.presentError(details);
      _handleError(details.exception, details.stack);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorMessage = error.toString();
      
      if (_isWebSocketError(errorMessage)) {
        print('⚠️ Ignored async WebSocket error: $errorMessage');
        return true;
      }
      
      _handleError(error, stack);
      return true;
    };
  }
  
  static bool _isWebSocketError(String errorMessage) {
    final websocketPatterns = [
      'WebSocket',
      'Socket',
      'WebSocketChannel',
      'WebSocketException',
      'web_socket',
      'websocket',
    ];
    
    for (final pattern in websocketPatterns) {
      if (errorMessage.toLowerCase().contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
  
  static void _handleError(dynamic error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('❌ Error: $error');
      debugPrint('Stack: $stack');
    }
    
    // Показываем диалог только если есть контекст
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext != null) {
        ErrorHandler.showErrorDialog(
          navigatorKey.currentContext!,
          error,
        );
      }
    });
  }
}