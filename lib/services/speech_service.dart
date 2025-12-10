import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// 语音识别服务
class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  /// 初始化语音识别
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // 检查并请求麦克风权限
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return false;
    }

    final available = await _speech.initialize(
      onError: (error) {
        // 错误处理
      },
      onStatus: (status) {
        // 状态处理
      },
    );

    _isInitialized = available;
    return available;
  }

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 检查是否正在监听
  bool get isListening => _isListening;

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
        onError?.call('语音识别未初始化，请检查麦克风权限');
        return;
      }
    }

    if (_isListening) {
      return;
    }

    _isListening = true;

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

