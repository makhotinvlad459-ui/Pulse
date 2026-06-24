// /lib/services/error/error_handler.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class AppError {
  final String title;
  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;

  AppError({
    required this.title,
    required this.message,
    this.canRetry = false,
    this.onRetry,
  });
}

class ErrorHandler {
  static AppError handleError(
    dynamic error, {
    BuildContext? context,
    VoidCallback? onRetry,
  }) {
    // Пытаемся получить контекст из navigatorKey, если не передан
    final effectiveContext = context ?? navigatorKey.currentContext;
    
    String getText(String key, String fallback) {
      if (effectiveContext == null) return fallback;
      try {
        final t = AppLocalizations.of(effectiveContext);
        if (t == null) return fallback;
        
        // Используем рефлексию для получения перевода
        final result = (t as dynamic)[key];
        if (result is String && result.isNotEmpty) return result;
        return fallback;
      } catch (_) {
        return fallback;
      }
    }

    // Проверка на отмену запроса (DioException.cancel)
    if (error is DioException && error.type == DioExceptionType.cancel) {
      return AppError(
        title: getText('error_cancel_title', 'Request Cancelled'),
        message: getText('error_cancel_message', 'The operation was cancelled.'),
        canRetry: false,
      );
    }

    // Обработка ошибок с кодом 402 (подписка)
    if (error is DioException && error.response?.statusCode == 402) {
      return AppError(
        title: getText('error_subscription_title', 'Subscription Required'),
        message: error.response?.data?['detail'] ?? 
                 getText('error_subscription_message', 'You have reached the limit of free operations. Please subscribe to continue.'),
        canRetry: false,
        onRetry: () {
          if (effectiveContext != null) {
            Navigator.of(effectiveContext).pushNamed('/subscription');
          }
        },
      );
    }

    // Обработка кодов ошибок из detail (ERROR_NEED_BASE_SUBSCRIPTION и т.д.)
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map && responseData.containsKey('detail')) {
        final detail = responseData['detail'];
        if (detail is String && detail.startsWith('ERROR_')) {
          switch (detail) {
            case 'ERROR_NEED_BASE_SUBSCRIPTION':
              return AppError(
                title: getText('error_subscription_title', 'Subscription Required'),
                message: getText('need_base_subscription', 'Cannot buy extra company without active base subscription. Please subscribe first.'),
                canRetry: false,
                onRetry: () {
                  if (effectiveContext != null) {
                    Navigator.of(effectiveContext).pushNamed('/subscription');
                  }
                },
              );
            case 'ERROR_INVALID_PLAN':
              return AppError(
                title: getText('error_generic_title', 'Error'),
                message: getText('invalid_plan', 'Invalid subscription plan'),
                canRetry: false,
              );
            default:
              return AppError(
                title: getText('error_generic_title', 'Error'),
                message: detail,
                canRetry: true,
                onRetry: onRetry,
              );
          }
        }
      }
    }

    // Dio ошибки
    if (error is DioException) {
      // 401 - Unauthorized
      if (error.response?.statusCode == 401) {
        return AppError(
          title: getText('error_auth_title', 'Session Expired'),
          message: getText('error_auth_message', 'Your session has expired. Please login again.'),
          canRetry: true,
          onRetry: onRetry ?? () {
            if (navigatorKey.currentContext != null) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
            }
          },
        );
      }

      // 403 - Forbidden
      if (error.response?.statusCode == 403) {
        return AppError(
          title: getText('error_forbidden_title', 'Access Denied'),
          message: getText('error_forbidden_message', 'You don\'t have permission to perform this action.'),
          canRetry: false,
        );
      }

      // 404 - Not Found
      if (error.response?.statusCode == 404) {
        return AppError(
          title: getText('error_not_found_title', 'Not Found'),
          message: getText('error_not_found_message', 'The requested resource was not found.'),
          canRetry: false,
        );
      }

      // 422 - Validation Error
      if (error.response?.statusCode == 422) {
        final data = error.response?.data;
        String validationMessage = '';
        
        if (data is Map) {
          if (data.containsKey('detail')) {
            final detail = data['detail'];
            if (detail is List) {
              validationMessage = detail.map((e) => e['msg'] ?? e.toString()).join('\n');
            } else if (detail is String) {
              validationMessage = detail;
            }
          } else {
            validationMessage = data.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n');
          }
        }
        
        return AppError(
          title: getText('error_validation_title', 'Validation Error'),
          message: validationMessage.isNotEmpty ? validationMessage : 
                   getText('error_validation_message', 'Please check your input and try again.'),
          canRetry: true,
          onRetry: onRetry,
        );
      }

      // 500+ Server errors
      if (error.response?.statusCode != null && error.response!.statusCode! >= 500) {
        return AppError(
          title: getText('error_server_title', 'Server Error'),
          message: getText('error_server_message', 'An error occurred on the server. Please try again later.'),
          canRetry: true,
          onRetry: onRetry,
        );
      }

      // Network errors
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return AppError(
          title: getText('error_network_title', 'Network Error'),
          message: getText('error_network_message', 'Unable to connect to the server. Please check your internet connection.'),
          canRetry: true,
          onRetry: onRetry,
        );
      }
    }

    // Обработка ошибки из response.data (например, {detail: "message"})
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map && data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          return AppError(
            title: getText('error_generic_title', 'Error'),
            message: detail,
            canRetry: true,
            onRetry: onRetry,
          );
        }
      }
    }

    // Generic errors
    if (error is Exception) {
      return AppError(
        title: getText('error_generic_title', 'Error'),
        message: error.toString().replaceAll('Exception: ', ''),
        canRetry: true,
        onRetry: onRetry,
      );
    }

    // Unknown errors
    return AppError(
      title: getText('error_unknown_title', 'Unexpected Error'),
      message: getText('error_unknown_message', 'An unexpected error occurred. Please try again.'),
      canRetry: true,
      onRetry: onRetry,
    );
  }

  static Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) async {
    // Проверяем, что контекст еще валидный
    if (!context.mounted) return;
    
    final appError = handleError(error, context: context, onRetry: onRetry);
    final t = AppLocalizations.of(context);
    
    return showDialog(
      context: context,
      barrierDismissible: !appError.canRetry,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              appError.canRetry ? Icons.error_outline : Icons.warning_amber_rounded,
              color: appError.canRetry ? Colors.red : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(appError.title)),
          ],
        ),
        content: Text(appError.message),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(t?.close ?? 'Close'),
          ),
          if (appError.canRetry && appError.onRetry != null)
            ElevatedButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  appError.onRetry!();
                }
              },
              child: Text(t?.retry ?? 'Retry'),
          ),
          if (!appError.canRetry && appError.onRetry != null)
            ElevatedButton(
              onPressed: () {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  appError.onRetry!();
                }
              },
              child: Text(t?.upgrade ?? 'Upgrade'),
            ),
        ],
      ),
    );
  }

  static void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;
    
    final appError = handleError(error, context: context, onRetry: onRetry);
    final t = AppLocalizations.of(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(appError.message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: appError.canRetry && onRetry != null
            ? SnackBarAction(
                label: t?.retry ?? 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}