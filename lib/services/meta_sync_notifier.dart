import 'dart:async';

/// Emits low-frequency "meta" changes (accounts/budget/etc) so background sync
/// can react without UI wiring.
class MetaSyncNotifier {
  MetaSyncNotifier._();

  static final MetaSyncNotifier instance = MetaSyncNotifier._();

  final StreamController<String> _accountsChanged =
      StreamController<String>.broadcast();

  Stream<String> get onAccountsChanged => _accountsChanged.stream;

  void notifyAccountsChanged(String bookId) {
    if (_accountsChanged.hasListener) {
      _accountsChanged.add(bookId);
    }
  }
}

