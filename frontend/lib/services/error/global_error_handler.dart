// lib/core/error/global_error_handler.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'error_handler.dart';
import '../../main.dart';

class GlobalErrorHandler {
  static void initialize() {
    if (kDebugMode) return;
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _handleError(details.exception, details.stack);
    };
    
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(error, stack);
      return true;
    };
  }
  
  static void _handleError(dynamic error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('Global Error: $error');
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