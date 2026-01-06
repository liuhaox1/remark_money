import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

// ignore_for_file: deprecated_member_use

/// 语音识别服务
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _lastError;

  /// 检查当前平台是否支持语音识别
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    // Windows 平台需要检查 speech_to_text 是否真的支持
    if (Platform.isWindows) {
      // speech_to_text 在 Windows 上的支持可能有限
      // 返回 true 让初始化尝试，如果失败会通过错误处理
      return true;
    }
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  /// 初始化语音识别
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Web 端暂无插件支持
    if (kIsWeb) {
      _lastError = 'Web 平台暂不支持语音识别';
      return false;
    }

    // 检查平台支持
    if (!isPlatformSupported) {
      _lastError = '当前平台不支持语音识别';
      return false;
    }

    // 检查并请求麦克风权限（以及 iOS 的语音识别权限）
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _lastError = '麦克风权限未授予。请在系统设置中允许应用访问麦克风';
        return false;
      }
      if (Platform.isIOS) {
        final speechStatus = await Permission.speech.request();
        if (!speechStatus.isGranted) {
          _lastError = '语音识别权限未授予。请在系统设置中允许应用使用语音识别';
          return false;
        }
      }
    } catch (e) {
      _lastError = '请求麦克风权限失败: $e';
      return false;
    }

    try {
      final available = await _speech.initialize(
        onError: (error) {
          _lastError = '语音识别错误: $error';
        },
        onStatus: (status) {
          // 状态处理
        },
      );

      final hasPermission = await _speech.hasPermission;
      if (!hasPermission) {
        _lastError = '语音识别权限未授予';
        _isInitialized = false;
        return false;
      }

      if (!available) {
        _lastError = '语音识别服务不可用。请检查：\n1. Windows 设置 > 隐私 > 麦克风 > 允许桌面应用访问麦克风\n2. 确保已安装并启用了 Windows 语音识别服务';
      }

      _isInitialized = available;
      return available;
    } catch (e) {
      // 捕获底层 PlatformException，避免崩溃
      _isInitialized = false;
      _lastError = '初始化语音识别失败: $e';
      if (Platform.isWindows) {
        _lastError = 'Windows 平台语音识别初始化失败。请检查：\n1. Windows 设置 > 隐私 > 麦克风 > 允许桌面应用访问麦克风\n2. 确保已安装并启用了 Windows 语音识别服务\n3. 错误详情: $e';
      }
      return false;
    }
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 检查是否正在监听
  bool get isListening => _isListening;

  /// 获取最后的错误信息
  String? get lastError => _lastError;

  /// 开始语音识别
  /// 
  /// [onResult] 回调函数，接收识别结果
  /// [onError] 错误回调
  /// [onDone] 完成回调
  Future<void> startListening({
    required Function(String text) onResult,
    Function(String error)? onError,
    VoidCallback? onDone,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call(_lastError ?? (kIsWeb
            ? '当前平台暂不支持语音识别'
            : '语音识别未初始化，请检查麦克风权限'));
        return;
      }
    }

    if (_isListening) {
      return;
    }

    _isListening = true;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _isListening = false;
            onResult(result.recognizedWords);
            onDone?.call();
          } else {
            // 实时更新识别结果
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30), // 最长30秒
        pauseFor: const Duration(seconds: 3), // 3秒无声音后暂停
        partialResults: true, // 允许部分结果
        localeId: 'zh_CN', // 中文识别
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation, // 确认模式
      );
    } catch (e) {
      _isListening = false;
      _lastError = '开始语音识别失败: $e';
      onError?.call(_lastError!);
    }
  }

  /// 停止语音识别
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    _isListening = false;
  }

  /// 取消语音识别
  Future<void> cancelListening() async {
    if (!_isListening) return;
    await _speech.cancel();
    _isListening = false;
  }

  /// 检查麦克风权限
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 释放资源
  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}
