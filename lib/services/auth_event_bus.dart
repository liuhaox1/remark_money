import 'dart:async';

/// Global auth events (e.g. token expired / unauthorized).
///
/// Keep this UI-agnostic. The UI layer (e.g. RootShell) decides how to react.
class AuthEventBus {
  AuthEventBus._();

  static final AuthEventBus instance = AuthEventBus._();

  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  final StreamController<void> _authChangedController =
      StreamController<void>.broadcast();

  Stream<void> get onUnauthorized => _unauthorizedController.stream;
  Stream<void> get onAuthChanged => _authChangedController.stream;

  void notifyUnauthorized() {
    if (_unauthorizedController.isClosed) return;
    _unauthorizedController.add(null);
  }

  void notifyAuthChanged() {
    if (_authChangedController.isClosed) return;
    _authChangedController.add(null);
  }
}
