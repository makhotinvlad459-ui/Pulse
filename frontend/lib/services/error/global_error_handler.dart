// lib/core/error/global_error_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'error_handler.dart';
import '../../main.dart';

class GlobalErrorHandler {
  static void initialize() {
    // В debug-режиме не перехватываем — ошибки видны в консоли
    if (kDebugMode) return;
    
    FlutterError.onError = (FlutterErrorDetails details) {
      final error = details.exception;
      final errorMessage = error.toString();
      
      if (_isIgnorableError(error, errorMessage)) {
        debugPrint('⚠️ Ignored non-critical error (not showing to user): $errorMessage');
        return;
      }
      
      // Показываем только действительно важные ошибки
      FlutterError.presentError(details);
      _handleError(error, details.stack);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorMessage = error.toString();
      
      if (_isIgnorableError(error, errorMessage)) {
        debugPrint('⚠️ Ignored async non-critical error: $errorMessage');
        return true;
      }
      
      _handleError(error, stack);
      return true;
    };
  }
  
  static bool _isIgnorableError(dynamic error, String message) {
    // Если это DioException и тип = cancel — игнорируем
    if (error is DioException) {
      if (error.type == DioExceptionType.cancel) {
        return true;
      }
      // Таймауты и ошибки соединения тоже игнорируем (пользователь увидит только если явно вызвать)
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }
    }
    
    // Основные паттерны ошибок, которые не надо показывать
    final patterns = [
      // WebSocket
      'WebSocket',
      'Socket',
      'WebSocketChannel',
      'WebSocketException',
      'host lookup',
      'Failed host lookup',
      'No address associated with hostname',
      // Жизненный цикл
      'setState() called after dispose',
      'dispose',
      'mounted',
      'Looking up a deactivated widget',
      'No MaterialLocalizations found',
      'No MediaQuery widget found',
      // Отмена запросов
      'cancel',
      'cancelled',
      'Cancel',
      // Контекст
      'context',
      'widget tree',
    ];
    
    final lowerMessage = message.toLowerCase();
    for (final pattern in patterns) {
      if (lowerMessage.contains(pattern.toLowerCase())) {
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
    
    // Проверяем, есть ли контекст и он валидный
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('⚠️ No context, skipping error dialog.');
      return;
    }
    
    // Дополнительная проверка на валидность контекста
    try {
      Localizations.localeOf(context);
    } catch (_) {
      debugPrint('⚠️ Context is invalid, skipping error dialog.');
      return;
    }
    
    // Показываем диалог только если ошибка не игнорируется
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null && currentContext.mounted) {
        ErrorHandler.showErrorDialog(
          currentContext,
          error,
        );
      }
    });
  }
}