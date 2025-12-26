import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode ? 'http://115.190.162.10:8080' : 'http://localhost:8080',
  );
}

