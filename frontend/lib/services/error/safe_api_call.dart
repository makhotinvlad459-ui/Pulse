// lib/core/utils/safe_api_call.dart
import 'package:flutter/material.dart';
import 'error_handler.dart';

typedef AsyncApiCall<T> = Future<T> Function();

class SafeApiCall {
  static Future<T?> execute<T>({
    required AsyncApiCall<T> call,
    required BuildContext context,
    VoidCallback? onSuccess,
    VoidCallback? onRetry,
    bool showErrorDialog = true,
    bool showSuccessMessage = false,
    String? successMessage,
  }) async {
    try {
      final result = await call();
      
      if (showSuccessMessage && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      onSuccess?.call();
      return result;
    } catch (e) {
      if (showErrorDialog) {
        await ErrorHandler.showErrorDialog(
          context,
          e,
          onRetry: onRetry,
        );
      } else {
        ErrorHandler.showErrorSnackBar(context, e, onRetry: onRetry);
      }
      return null;
    }
  }
  
  // Версия без возвращаемого значения
  static Future<bool> executeVoid({
    required AsyncApiCall<void> call,
    required BuildContext context,
    VoidCallback? onSuccess,
    VoidCallback? onRetry,
    bool showErrorDialog = true,
    bool showSuccessMessage = false,
    String? successMessage,
  }) async {
    try {
      await call();
      
      if (showSuccessMessage && successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      onSuccess?.call();
      return true;
    } catch (e) {
      if (showErrorDialog) {
        await ErrorHandler.showErrorDialog(
          context,
          e,
          onRetry: onRetry,
        );
      } else {
        ErrorHandler.showErrorSnackBar(context, e, onRetry: onRetry);
      }
      return false;
    }
  }
}