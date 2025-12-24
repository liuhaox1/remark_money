class SyncV2PushRetry {
  static const int maxAttempts = 3;

  static int getAttempt(Map<String, dynamic> payload) {
    final v = payload['_attempt'] ?? payload['_attempts'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static Map<String, dynamic> bumpAttempt(
    Map<String, dynamic> payload, {
    required String error,
  }) {
    final attempt = getAttempt(payload) + 1;
    return {
      ...payload,
      '_attempt': attempt,
      '_lastError': error,
      '_lastAttemptAtMs': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static bool shouldQuarantine(Map<String, dynamic> payload) {
    return getAttempt(payload) >= maxAttempts;
  }
}

