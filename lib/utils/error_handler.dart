import 'package:flutter/material.dart';

/// 统一的错误处理工具类
/// 提供统一的错误提示、日志记录等功能
class ErrorHandler {
  ErrorHandler._();

  /// 显示错误提示
  /// 
  /// [context] BuildContext
  /// [message] 用户友好的错误消息
  /// [error] 原始错误对象（用于日志）
  /// [onRetry] 可选的重试回调
  static void showError(
    BuildContext context,
    String message, {
    Object? error,
    VoidCallback? onRetry,
  }) {
    if (error != null) {
      debugPrint('[ErrorHandler] $message: $error');
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: '重试',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// 显示成功提示
  /// 
  /// [context] BuildContext
  /// [message] 成功消息
  static void showSuccess(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 显示警告提示
  /// 
  /// [context] BuildContext
  /// [message] 警告消息
  static void showWarning(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 显示信息提示
  /// 
  /// [context] BuildContext
  /// [message] 信息消息
  static void showInfo(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 将技术错误转换为用户友好的消息
  /// 
  /// [error] 原始错误对象
  /// 返回用户友好的错误消息
  static String getUserFriendlyMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('database') || errorStr.contains('sql')) {
      return '数据库操作失败，请稍后重试';
    }

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return '网络连接失败，请检查网络设置';
    }

    if (errorStr.contains('file') || errorStr.contains('permission')) {
      return '文件操作失败，请检查文件权限';
    }

    if (errorStr.contains('format') || errorStr.contains('parse')) {
      return '数据格式错误，请检查输入内容';
    }

    if (errorStr.contains('not found') || errorStr.contains('不存在')) {
      return '未找到相关数据';
    }

    if (errorStr.contains('duplicate') || errorStr.contains('重复')) {
      return '数据已存在，请勿重复添加';
    }

    // 默认消息
    return '操作失败，请稍后重试';
  }

  /// 处理异步操作错误
  /// 
  /// [context] BuildContext
  /// [error] 错误对象
  /// [onRetry] 可选的重试回调
  static void handleAsyncError(
    BuildContext context,
    Object error, {
    VoidCallback? onRetry,
  }) {
    final message = getUserFriendlyMessage(error);
    showError(context, message, error: error, onRetry: onRetry);
  }

  /// 记录错误日志（用于 Provider 层）
  /// 
  /// [tag] 错误标签（通常是类名和方法名）
  /// [error] 错误对象
  /// [stackTrace] 堆栈跟踪（可选）
  static void logError(String tag, Object error, [StackTrace? stackTrace]) {
    debugPrint('[ErrorHandler] $tag: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
  }
}
